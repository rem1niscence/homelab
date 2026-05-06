package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/dustin/go-humanize"
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
	defer os.RemoveAll(configPath.BackupDbPath)
	defer os.RemoveAll(configPath.BackupHeightPath)

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
	defer os.RemoveAll(config.DownloadFolder)

	// download snapshot files
	downloads := map[string]string{
		configPath.DownloadSnapshotPath: config.SnapshotFileURL,
		configPath.DownloadHeightPath:   config.HeightFileURL,
	}
	for path, url := range downloads {
		now := time.Now()
		logger.Info("downloading file", slog.String("path", path))
		reader, size, err := downloader.Download(ctx, url)
		if err != nil {
			return fmt.Errorf("failed to download file: %s: %w", path, err)
		}
		defer reader.Close()
		progressReader := trackDownloadProgress(logger, reader, url, size)
		if err := copyToFile(progressReader, path); err != nil {
			return fmt.Errorf("failed to download file: %s: %w", path, err)
		}
		logger.Info("downloaded file", slog.String("path", path),
			slog.String("took", time.Since(now).String()))
	}

	// create extracted snapshot folder
	if err := os.MkdirAll(configPath.ExtractedSnapshotPath, 0755); err != nil {
		return fmt.Errorf("failed to create extracted snapshot folder: %w", err)
	}
	defer os.RemoveAll(configPath.ExtractedSnapshotPath)

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
			if err := copyLocalFile(src, dst); err != nil {
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
	rawRemoteHeight, _, err := downloader.Download(ctx, config.HeightFileURL)
	if err != nil {
		return true, fmt.Errorf("failed to download remote height: %w", err)
	}
	type HeightResp struct {
		Height int64 `json:"height"`
	}
	var remoteHeight HeightResp
	if err := json.NewDecoder(rawRemoteHeight).Decode(&remoteHeight); err != nil {
		return true, fmt.Errorf("failed to parse remote height: %w", err)
	}

	logger.Info("height comparison",
		slog.Int64("local_height", localHeight),
		slog.Int64("remote_height", remoteHeight.Height),
		slog.Int64("threshold", config.HeightThreshold))

	// check if remote height is higher than the threshold
	return remoteHeight.Height >= localHeight+config.HeightThreshold, nil
}

// copyToFile copies a single file from source to destination
func copyToFile(reader io.Reader, localPath string) error {
	file, err := os.Create(localPath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, reader)
	return err
}

// trackDownloadProgress tracks the progress of a download and logs it
func trackDownloadProgress(logger *slog.Logger, reader io.Reader, name string, size int64) io.Reader {
	return storage.NewProgressReader(reader, size, 5*time.Second, func(read, total int64) {
		percentage := float64(read) / float64(total) * 100
		logger.Info("downloading", slog.String("name",
			name),
			slog.String("percentage", fmt.Sprintf("%.2f%%", percentage)),
			slog.String("downloaded", humanize.Bytes(uint64(read))),
			slog.String("total", humanize.Bytes(uint64(total))))
	})
}

// copyLocalFile copies a single local file from source to destination
func copyLocalFile(src, dst string) error {
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
			return copyLocalFile(path, destPath)
		}
	})
}
