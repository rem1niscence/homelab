package main

import (
	"context"
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

	logger.Info("finish restoring canopy snapshot ✅", slog.String("took", time.Since(now).String()))
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

func PerformRestore(ctx context.Context, config *RestoreConfig, logger *slog.Logger, downloader storage.Downloader) error {
	logger.Info("starting canopy restore")

	// check if files exist
	heightExists, dbExists, err := checkExistingFiles(config, logger)
	if err != nil {
		return fmt.Errorf("failed to check existing files: %w", err)
	}

	// decide whether to restore
	shouldRestore := false
	if !heightExists && !dbExists {
		logger.Info("no existing files found, proceeding with restore")
		shouldRestore = true
	} else if heightExists && dbExists {
		logger.Info("existing files found, checking height difference")
		restore, err := shouldRestoreBasedOnHeight(ctx, config, logger, downloader)
		if err != nil {
			shouldRestore = true
			logger.Error("failed to check height", "error", err)
		} else {
			shouldRestore = restore
		}
	} else {
		logger.Info("only some files exist, proceeding with restore")
		shouldRestore = true
	}

	if !shouldRestore {
		logger.Info("restore not needed, exiting")
		return nil
	}

	// perform restore
	return downloadAndRestore(ctx, config, logger, downloader)
}

// checkExistingFiles checks if HeightFile and DbFolder exist in RootFolder
func checkExistingFiles(config *RestoreConfig, logger *slog.Logger) (heightExists, dbExists bool, err error) {
	heightPath := filepath.Join(config.RootFolder, config.HeightFile)
	dbPath := filepath.Join(config.RootFolder, config.DbFolder)

	logger.Info("checking for files", "heightPath", heightPath, "dbPath", dbPath)

	if _, err := os.Stat(heightPath); err == nil {
		heightExists = true
		logger.Info("height file exists", slog.String("path", heightPath))
	}

	if _, err := os.Stat(dbPath); err == nil {
		dbExists = true
		logger.Info("database folder exists", slog.String("path", dbPath))
	}

	return heightExists, dbExists, nil
}

// parseHeightFile reads a height file and parses the single number to int64
func parseHeightFile(filePath string) (int64, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("failed to read height file: %w", err)
	}
	return parseHeightContent(content)
}

// parseHeightContent parses height content (bytes) to int64
func parseHeightContent(content []byte) (int64, error) {
	heightStr := strings.TrimSpace(string(content))
	height, err := strconv.ParseInt(heightStr, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse height '%s': %w", heightStr, err)
	}
	return height, nil
}

// downloadAndParseRemoteHeight downloads the remote height file and parses it
func downloadAndParseRemoteHeight(ctx context.Context, config *RestoreConfig, downloader storage.Downloader) (int64, error) {
	// create download folder if needed
	if err := os.MkdirAll(config.DownloadFolder, 0755); err != nil {
		return 0, fmt.Errorf("failed to create download folder: %w", err)
	}

	// download remote height file
	reader, err := downloader.Download(ctx, config.HeightFileURL)
	if err != nil {
		return 0, fmt.Errorf("failed to download remote height file: %w", err)
	}
	defer reader.Close()

	// read content
	content, err := io.ReadAll(reader)
	if err != nil {
		return 0, fmt.Errorf("failed to read remote height file content: %w", err)
	}

	height, err := parseHeightContent(content)
	if err != nil {
		return 0, fmt.Errorf("failed to parse remote height: %w", err)
	}
	return height, nil
}

// shouldRestoreBasedOnHeight compares local and remote heights
func shouldRestoreBasedOnHeight(ctx context.Context, config *RestoreConfig, logger *slog.Logger, downloader storage.Downloader) (bool, error) {
	// get local height
	localHeightPath := filepath.Join(config.RootFolder, config.HeightFile)
	localHeight, err := parseHeightFile(localHeightPath)
	if err != nil {
		return false, fmt.Errorf("failed to parse local height: %w", err)
	}

	// get remote height
	remoteHeight, err := downloadAndParseRemoteHeight(ctx, config, downloader)
	if err != nil {
		return false, fmt.Errorf("failed to get remote height: %w", err)
	}

	logger.Info("height comparison",
		slog.Int64("local_height", localHeight),
		slog.Int64("remote_height", remoteHeight),
		slog.Int64("threshold", config.HeightThreshold))

	// check if remote height is significantly higher (by threshold amount)
	shouldRestore := remoteHeight >= localHeight+config.HeightThreshold

	if shouldRestore {
		logger.Info("remote height is significantly higher, proceeding with restore")
	} else {
		logger.Info("remote height is not significantly higher, skipping restore")
	}
	return shouldRestore, nil
}

// downloadAndRestore downloads and restores the snapshot
func downloadAndRestore(ctx context.Context, config *RestoreConfig, logger *slog.Logger, downloader storage.Downloader) error {
	logger.Info("starting download and restore process")

	// create download folder
	if err := os.MkdirAll(config.DownloadFolder, 0755); err != nil {
		return fmt.Errorf("failed to create download folder: %w", err)
	}
	defer cleanup(config.DownloadFolder, logger)

	// download snapshot
	logger.Info("downloading snapshot", slog.String("url", config.SnapshotURL))
	snapshotPath := filepath.Join(config.DownloadFolder, "snapshot.tar.gz")
	if err := downloadFile(ctx, downloader, config.SnapshotURL, snapshotPath); err != nil {
		return fmt.Errorf("failed to download snapshot: %w", err)
	}

	// download height file
	logger.Info("downloading height file", slog.String("url", config.HeightFileURL))
	heightPath := filepath.Join(config.DownloadFolder, config.HeightFile)
	if err := downloadFile(ctx, downloader, config.HeightFileURL, heightPath); err != nil {
		return fmt.Errorf("failed to download height file: %w", err)
	}

	// extract snapshot, is assumed to be compressed
	logger.Info("extracting snapshot")
	extractedPath := filepath.Join(config.DownloadFolder, "extracted")
	if err := storage.DecompressCMD(ctx, snapshotPath, extractedPath); err != nil {
		return fmt.Errorf("failed to extract snapshot: %w", err)
	}

	// replace files atomically
	logger.Info("replacing files")
	if err := replaceFiles(config, extractedPath, heightPath, logger); err != nil {
		return fmt.Errorf("failed to replace files: %w", err)
	}

	logger.Info("restore completed successfully")
	return nil
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

// replaceFiles atomically replaces the database folder and height file
func replaceFiles(config *RestoreConfig, extractedPath, newHeightPath string, logger *slog.Logger) error {
	dbPath := filepath.Join(config.RootFolder, config.DbFolder)
	heightPath := filepath.Join(config.RootFolder, config.HeightFile)
	backupDbPath := dbPath + "_backup"
	backupHeightPath := heightPath + "_backup"

	// backup existing database folder by renaming with _backup suffix
	if _, err := os.Stat(dbPath); err == nil {
		logger.Info("backing up existing database folder", slog.String("backup_path", backupDbPath))
		if err := os.Rename(dbPath, backupDbPath); err != nil {
			return fmt.Errorf("failed to backup database folder: %w", err)
		}
		defer func() {
			if err := os.RemoveAll(backupDbPath); err != nil {
				logger.Warn("failed to cleanup backup database folder", slog.String("error", err.Error()))
			}
		}()
	}

	// backup existing height file by renaming with _backup suffix
	if _, err := os.Stat(heightPath); err == nil {
		logger.Info("backing up existing height file", slog.String("backup_path", backupHeightPath))
		if err := os.Rename(heightPath, backupHeightPath); err != nil {
			return fmt.Errorf("failed to backup height file: %w", err)
		}
		defer func() {
			if err := os.Remove(backupHeightPath); err != nil {
				logger.Warn("failed to cleanup backup height file", slog.String("error", err.Error()))
			}
		}()
	}

	// copy extracted database folder to final location (avoid cross-device link)
	extractedDbPath := filepath.Join(extractedPath, config.DbFolder)
	if err := copyDir(extractedDbPath, dbPath); err != nil {
		return fmt.Errorf("failed to copy extracted database folder: %w", err)
	}

	// copy new height file to final location (avoid cross-device link)
	if err := copyFile(newHeightPath, heightPath); err != nil {
		return fmt.Errorf("failed to copy new height file: %w", err)
	}

	logger.Info("files replaced successfully")
	return nil
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

// cleanup removes the download folder
func cleanup(downloadFolder string, logger *slog.Logger) {
	if err := os.RemoveAll(downloadFolder); err != nil {
		logger.Warn("failed to cleanup download folder", slog.String("error", err.Error()))
	} else {
		logger.Info("cleaned up download folder")
	}
}
