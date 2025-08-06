package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/config"
	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/kubernetes"
	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/storage"
)

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

	controller, uploader, err := Initialize(logger)
	if err != nil {
		logger.Error("failed to initialize", slog.String("error", err.Error()))
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	err = ScaleDeployment(ctx, controller, func() error {
		return PerformBackup(ctx, controller.Config, logger, uploader)
	})
	if err != nil {
		logger.Error("failed to run scale deployment operation", slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("finish backing up canopy volume ✅", slog.String("took", time.Since(now).String()))
}

// Initialize initializes the necessary components for the backup process.
func Initialize(logger *slog.Logger) (*kubernetes.Controller, storage.Uploader, error) {
	client, err := kubernetes.GetClientSet()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get client set: %w", err)
	}

	config, err := config.LoadConfig()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get config: %w", err)
	}

	// logger.Info("config loaded", slog.Any("config", config))

	if err := config.Validate(); err != nil {
		return nil, nil, fmt.Errorf("config validation failed: %w", err)
	}

	controller := kubernetes.NewController(client, logger, config)

	s3 := config.S3
	uploader, err := storage.NewCustomS3Uploader(s3.AccessKey, s3.SecretAccessKey, s3.Region, s3.Endpoint, s3.Bucket)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create uploader: %w", err)
	}

	return controller, uploader, nil
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

func PerformBackup(ctx context.Context, config *config.Config, logger *slog.Logger, uploader storage.Uploader) error {
	logger.Info("starting canopy backup")

	// get backup file path
	fileName := fmt.Sprintf("%s.tar.gz", config.BackupKey)
	backupFile := filepath.Join(config.BackupPath, fileName)

	// check if source path exists
	if _, err := os.Stat(config.SourcePath); os.IsNotExist(err) {
		return fmt.Errorf("backup path does not exist: %w", err)
	}

	// create backup directory if it doesn't exist
	if _, err := os.Stat(config.BackupPath); os.IsNotExist(err) {
		if err := os.MkdirAll(config.BackupPath, 0755); err != nil {
			return fmt.Errorf("failed to create backup directory: %w", err)
		}
	}

	now := time.Now()
	logger.Info("started compressing backup")
	// compress backup
	if err := storage.CompressFolderCMD(config.SourcePath, backupFile); err != nil {
		return fmt.Errorf("compression failed: %w", err)
	}
	// get backup file size for logging
	fileInfo, err := os.Stat(backupFile)
	if err != nil {
		return fmt.Errorf("failed to get backup file info: %w", err)
	}
	logger.Info("finished compressing backup",
		slog.String("took", time.Since(now).String()), slog.Int64("size", fileInfo.Size()))

	// upload backup file
	logger.Info("started uploading file to external storage")
	now = time.Now()
	if err := uploader.UploadFS(ctx, backupFile, config.BackupKey); err != nil {
		return fmt.Errorf("upload failed: %w", err)
	}
	logger.Info("finished uploading file to external storage", slog.String("took", time.Since(now).String()))

	return nil
}
