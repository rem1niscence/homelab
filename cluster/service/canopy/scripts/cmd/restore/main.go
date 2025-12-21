package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/reminiscence/homelab/cluster/canopy/scripts/internal/lifecycle"
	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/storage"
)

const (
	backupPrefix = "backup_"
)

func main() {
	now := time.Now()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	logger.Info("starting canopy restore")

	var err error

	defer func() {
		if err != nil {
			logger.Error("failed to run restore ❌",
				slog.String("error", err.Error()), slog.String("took", time.Since(now).String()))
		}
	}()

	config, downloader, err := Initialize(logger)
	if err != nil {
		logger.Error("failed to initialize", slog.String("error", err.Error()))
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), config.GlobalTimeout)
	defer cancel()

	// add signal handling for graceful shutdown
	ctx = lifecycle.GracefulShutdown(ctx, logger, cancel)

	err = PerformRestore(ctx, config, logger, downloader)
	if err != nil {
		logger.Error("failed to run restore operation", slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("finished restoring canopy snapshot ✅", slog.String("took", time.Since(now).String()))
}

// Initialize initializes the necessary components for the restore process.
func Initialize(logger *slog.Logger) (*RestoreConfig, storage.Downloader, error) {
	config, err := LoadRestoreConfig()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get config: %w", err)
	}

	if err := config.Validate(); err != nil {
		return nil, nil, fmt.Errorf("config validation failed: %w", err)
	}

	s3 := config.S3
	downloader, err := storage.NewCustomS3StorageManager(s3.AccessKey, s3.SecretAccessKey, s3.Region, s3.Endpoint, s3.Bucket)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create downloader: %w", err)
	}

	return config, downloader, nil
}

// ConfigWithNames represents the configuration for the restore process with the full path names of the
// files
type ConfigWithPaths struct {
	RestoreConfig
	DbPath                string
	HeightPath            string
	BackupDbPath          string
	BackupHeightPath      string
	DownloadSnapshotPath  string
	DownloadHeightPath    string
	ExtractedSnapshotPath string
}

func PerformRestore(ctx context.Context, config *RestoreConfig, logger *slog.Logger, downloader storage.Downloader) (err error) {
	configPath := ConfigWithPaths{
		RestoreConfig: *config,

		DbPath:     filepath.Join(config.RootFolder, config.DbFolder),
		HeightPath: filepath.Join(config.RootFolder, config.HeightFile),

		BackupDbPath:     filepath.Join(config.RootFolder, backupPrefix+config.DbFolder),
		BackupHeightPath: filepath.Join(config.RootFolder, backupPrefix+config.HeightFile),

		DownloadSnapshotPath: filepath.Join(config.DownloadFolder, config.SnapshotFile),
		DownloadHeightPath:   filepath.Join(config.DownloadFolder, config.HeightFile),

		ExtractedSnapshotPath: filepath.Join(config.DownloadFolder, config.DbFolder),
	}

	// remove backup files regardless
	defer os.Remove(configPath.BackupDbPath)
	defer os.Remove(configPath.BackupHeightPath)

	// check if files exist
	exists := make([]bool, 2)
	for i, path := range []string{configPath.DbPath, configPath.HeightPath} {
		_, err := os.Stat(path)
		exists[i] = err == nil
	}

	// decide whether to restore
	restore, err := shouldRestore(ctx, exists[0], exists[1], logger, config, downloader)
	if err != nil {
		logger.Error("failed to decide whether to restore", slog.String("error", err.Error()))
	}
	if !restore {
		logger.Info("no restore needed, skipping")
		return nil
	}
	logger.Info("snapshot restore required,	 starting")

	// create download folder
	if err := os.MkdirAll(config.DownloadFolder, 0755); err != nil {
		return fmt.Errorf("failed to create download folder: %w", err)
	}
	defer os.Remove(config.DownloadFolder)

	// download snapshot files
	downloads := map[string]string{
		configPath.DownloadSnapshotPath: config.SnapshotFileURL,
		configPath.DownloadHeightPath:   config.HeightFileURL,
	}
	for path, url := range downloads {
		now := time.Now()
		logger.Info("downloading file", slog.String("path", path))
		if err := downloadFile(ctx, downloader, url, path); err != nil {
			return fmt.Errorf("failed to download file: %s: %w", path, err)
		}
		logger.Info("downloaded file", slog.String("path", path),
			slog.String("took", time.Since(now).String()))
	}

	// create extracted snapshot folder
	if err := os.MkdirAll(configPath.ExtractedSnapshotPath, 0755); err != nil {
		return fmt.Errorf("failed to create extracted snapshot folder: %w", err)
	}
	defer os.Remove(configPath.ExtractedSnapshotPath)

	// extract snapshot, is assumed to be compressed
	now := time.Now()
	logger.Info("extracting snapshot")
	if err := storage.DecompressCMD(ctx, configPath.DownloadSnapshotPath,
		configPath.ExtractedSnapshotPath); err != nil {
		return fmt.Errorf("failed to extract snapshot: %w", err)
	}
	logger.Info("extracted snapshot",
		slog.String("path", configPath.DownloadFolder),
		slog.String("took", time.Since(now).String()))

	// rename current files to backup
	rename := map[string]string{
		configPath.DbPath:     configPath.BackupDbPath,
		configPath.HeightPath: configPath.BackupHeightPath,
	}
	for src, dst := range rename {
		if _, err := os.Stat(src); err == nil {
			logger.Info("renaming existing path", slog.String("source_path", src))
			if err := os.Rename(src, dst); err != nil {
				return fmt.Errorf("failed to rename existing path: %w", err)
			}
			logger.Info("renamed existing path", slog.String("destination_path", dst))
		}
		// restore previous files if an error occurs during the rest of the process
		defer func() {
			if err != nil {
				if _, err := os.Stat(src); err != nil {
					os.Remove(src)
				}
				os.Rename(dst, src)
			}
		}()
	}

	// copy extracted files to final location (avoid cross-device link)
	copyFiles := map[string]string{
		configPath.DownloadHeightPath:    configPath.HeightPath,
		configPath.ExtractedSnapshotPath: configPath.DbPath,
	}
	for src, dst := range copyFiles {
		fileInfo, err := os.Stat(src)
		if err != nil {
			return fmt.Errorf("failed to stat file %s: %w", src, err)
		}
		now := time.Now()
		isDir := fileInfo.IsDir()
		logger.Info("copying path",
			slog.String("source_path", src),
			slog.String("destination_path", dst))
		if isDir {
			if err := os.MkdirAll(dst, 0755); err != nil {
				return fmt.Errorf("failed to create destination directory: %s: %w", dst, err)
			}
			if err := copyDir(src, dst); err != nil {
				return fmt.Errorf("failed to copy directory: %s: %w", src, err)
			}
		} else {
			if err := copyFile(src, dst); err != nil {
				return fmt.Errorf("failed to copy file: %s: %w", src, err)
			}
		}
		logger.Info("copied path",
			slog.String("source_path", src),
			slog.String("destination_path", dst),
			slog.String("took", time.Since(now).String()),
		)
	}

	return nil
}

func shouldRestore(ctx context.Context, heightExists bool, dbExists bool,
	logger *slog.Logger, config *RestoreConfig, downloader storage.Downloader) (bool, error) {
	// no files exist, restore
	if !heightExists && !dbExists {
		return true, nil
	}
	// both files exist, check heights
	if heightExists && dbExists {
		return compareHeights(ctx, config, logger, downloader)
	}
	// only one file exists, restore
	return true, nil
}

// compareHeights compares local and remote heights, checking whether local
// height is higher than remote height threshold
func compareHeights(ctx context.Context, config *RestoreConfig,
	logger *slog.Logger, downloader storage.Downloader) (bool, error) {
	// get local height
	rawLocalHeight, err := os.ReadFile(filepath.Join(config.RootFolder, config.HeightFile))
	if err != nil {
		return true, fmt.Errorf("failed to read local height file: %w", err)
	}
	var localHeightData struct {
		Height int64 `json:"height"`
	}
	if err := json.Unmarshal(rawLocalHeight, &localHeightData); err != nil {
		return true, fmt.Errorf("failed to parse local height JSON: %w", err)
	}
	localHeight := localHeightData.Height

	// get remote height
	rawRemoteHeight, err := downloadBytes(ctx, config.HeightFileURL, downloader)
	if err != nil {
		return true, fmt.Errorf("failed to download remote height: %w", err)
	}
	remoteHeight, err := strconv.ParseInt(strings.TrimSpace(string(rawRemoteHeight)), 10, 64)
	if err != nil {
		return true, fmt.Errorf("failed to parse remote height: %w", err)
	}

	logger.Info("height comparison",
		slog.Int64("local_height", localHeight),
		slog.Int64("remote_height", remoteHeight),
		slog.Int64("threshold", config.HeightThreshold))

	// check if remote height is higher than the threshold
	return remoteHeight >= localHeight+config.HeightThreshold, nil
}

// downloadBytes downloads a file and returns its content as bytes
func downloadBytes(ctx context.Context, url string, downloader storage.Downloader) ([]byte, error) {
	// download remote height file
	reader, err := downloader.Download(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("failed to download %s: %w", url, err)
	}
	defer reader.Close()
	// read content
	content, err := io.ReadAll(reader)
	if err != nil {
		return nil, fmt.Errorf("failed to read contents of %s: %w", url, err)
	}
	return content, nil
}

// downloadFile downloads a file from storage to local path
func downloadFile(ctx context.Context, downloader storage.Downloader, key, localPath string) error {
	reader, err := downloader.Download(ctx, key)
	if err != nil {
		return err
	}
	defer reader.Close()

	file, err := os.Create(localPath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, reader)
	return err
}

// copyFile copies a single file from source to destination
func copyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	if err != nil {
		return fmt.Errorf("failed to copy file content: %w", err)
	}

	return nil
}

// copyDir recursively copies a directory from source to destination
func copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// calculate destination path
		relPath, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		destPath := filepath.Join(dst, relPath)

		if info.IsDir() {
			// create directory
			return os.MkdirAll(destPath, info.Mode())
		} else {
			// copy file
			return copyFile(path, destPath)
		}
	})
}
