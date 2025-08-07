package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/kubernetes"
	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/storage"
)

// BackupResult holds the result of backup preparation
type BackupResult struct {
	FilePath string
	Size     int64
	Skipped  bool
}

func main() {
	now := time.Now()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	logger.Info("starting backup controller")

	var err error

	defer func() {
		if err != nil {
			logger.Error("failed to run backup ❌",
				slog.String("error", err.Error()), slog.String("took", time.Since(now).String()))
		}
	}()

	config, controller, uploader, err := Initialize(logger)
	if err != nil {
		logger.Error("failed to initialize", slog.String("error", err.Error()))
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	err = ScaleDeployment(ctx, controller, func() error {
		return PerformBackup(ctx, config, logger, uploader)
	})
	if err != nil {
		logger.Error("failed to run scale deployment operation", slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("finish backing up canopy volume ✅", slog.String("took", time.Since(now).String()))
}

// Initialize initializes the necessary components for the backup process.
func Initialize(logger *slog.Logger) (*BackupConfig, *kubernetes.Controller, storage.Uploader, error) {
	client, err := kubernetes.GetClientSet()
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to get client set: %w", err)
	}

	config, err := LoadBackupConfig()
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to get config: %w", err)
	}

	// logger.Info("config loaded", slog.Any("config", config))

	if err := config.Validate(); err != nil {
		return nil, nil, nil, fmt.Errorf("config validation failed: %w", err)
	}

	controller := kubernetes.NewController(client, logger, config.Controller)

	s3 := config.S3
	uploader, err := storage.NewCustomS3StorageManager(s3.AccessKey, s3.SecretAccessKey, s3.Region, s3.Endpoint, s3.Bucket)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to create uploader: %w", err)
	}

	return config, controller, uploader, nil
}

func ScaleDeployment(ctx context.Context, controller *kubernetes.Controller, fn func() error) error {
	logger := controller.Logger
	config := controller.Config

	logger.Info("scaling down deployment", slog.String("deployment", config.Deployment))
	if err := controller.ScaleDeployment(ctx, 0); err != nil {
		return fmt.Errorf("failed to scale down deployment: %w", err)
	}
	if err := controller.WaitForScaling(ctx, 0); err != nil {
		return fmt.Errorf("failed to wait for scaling down deployment: %w", err)
	}

	var err error
	if err = fn(); err != nil {
		err = fmt.Errorf("failed to run operation: %w", err)
	}

	logger.Info("scaling up deployment", slog.String("deployment", config.Deployment))
	if scaleErr := controller.ScaleDeployment(ctx, 1); scaleErr != nil {
		return errors.Join(err, fmt.Errorf("failed to scale up deployment: %w", scaleErr))
	}
	if scaleErr := controller.WaitForScaling(ctx, 1); scaleErr != nil {
		return errors.Join(err, fmt.Errorf("failed to wait for scaling up deployment: %w", scaleErr))
	}

	return err
}

func PerformBackup(ctx context.Context, config *BackupConfig, logger *slog.Logger, uploader storage.Uploader) error {
	logger.Info("starting canopy backup")

	// create backup directory if it doesn't exist
	if _, err := os.Stat(config.BackupPath); os.IsNotExist(err) {
		if err := os.MkdirAll(config.BackupPath, 0755); err != nil {
			return fmt.Errorf("failed to create backup directory: %s: %w", config.BackupPath, err)
		}
	}

	// process each backup item
	for i, item := range config.BackupItems {
		logger.Info("processing backup item", slog.Int("item", i+1), slog.String("key", item.BackupKey))

		// prepare backup (compress or use source file directly)
		result, err := prepareBackup(ctx, item, item.SourcePath, config.BackupPath, logger)
		if err != nil {
			return fmt.Errorf("failed to prepare backup for item %d: %w", i+1, err)
		}

		// skip if preparation indicated to skip this item
		if result.Skipped {
			continue
		}

		// upload the prepared backup
		if err := uploadBackup(ctx, result, item.BackupKey, uploader, logger); err != nil {
			return fmt.Errorf("failed to upload backup for item %d: %w", i+1, err)
		}
	}

	return nil
}

// prepareBackup handles the compression or file preparation logic for a backup item
func prepareBackup(ctx context.Context, item BackupItem,
	sourcePath string, backupDir string, logger *slog.Logger) (*BackupResult, error) {
	if item.Compress {
		logger.Info("started compressing backup",
			slog.String("key", item.BackupKey),
			slog.String("path", sourcePath))
		fileName := fmt.Sprintf("%s.tar.gz", item.BackupKey)
		backupFile := filepath.Join(backupDir, fileName)

		now := time.Now()
		if err := storage.CompressFolderCMD(ctx, sourcePath, backupFile); err != nil {
			return nil, fmt.Errorf("compression failed: %w", err)
		}

		// get backup file size for logging
		fileInfo, err := os.Stat(backupFile)
		if err != nil {
			return nil, fmt.Errorf("failed to get backup file info: %w", err)
		}

		logger.Info("finished creating backup",
			slog.String("key", item.BackupKey),
			slog.String("took", time.Since(now).String()),
			slog.Int64("size", fileInfo.Size()))

		return &BackupResult{
			FilePath: backupFile,
			Size:     fileInfo.Size(),
			Skipped:  false,
		}, nil
	} else {
		// for uncompressed backups, check if source is a single file
		sourceInfo, err := os.Stat(sourcePath)
		if err != nil {
			return nil, fmt.Errorf("failed to stat source path: %w", err)
		}

		if sourceInfo.IsDir() {
			logger.Error("compression is disabled but source is a directory, skipping item",
				slog.String("key", item.BackupKey))
			return &BackupResult{Skipped: true}, nil
		}

		logger.Info("using source file directly for uncompressed backup",
			slog.String("key", item.BackupKey),
			slog.String("path", sourcePath),
			slog.Int64("size", sourceInfo.Size()))

		return &BackupResult{
			FilePath: sourcePath,
			Size:     sourceInfo.Size(),
			Skipped:  false,
		}, nil
	}
}

// uploadBackup handles the upload logic for a prepared backup file
func uploadBackup(ctx context.Context, result *BackupResult, backupKey string,
	uploader storage.Uploader, logger *slog.Logger) error {
	if result.Skipped {
		return nil
	}

	logger.Info("started uploading file to external storage", slog.String("key", backupKey))
	uploadStart := time.Now()

	// open backup file
	file, err := os.Open(result.FilePath)
	if err != nil {
		return fmt.Errorf("failed to open backup file for upload: %w", err)
	}
	defer file.Close()

	// upload backup file
	if err := uploader.Upload(ctx, file, backupKey); err != nil {
		return fmt.Errorf("upload failed: %w", err)
	}

	logger.Info("finished uploading file to external storage",
		slog.String("key", backupKey),
		slog.String("took", time.Since(uploadStart).String()))

	return nil
}
