package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"time"
)

type app struct {
	controller *Controller
	backup     *IBackup
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	logger.Info("starting backup controller at", slog.String("time", time.Now().String()))

	controller, backup, err := Initialize(logger)
	if err != nil {
		logger.Error("failed to initialize", slog.String("error", err.Error()))
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	err = ScaleDeployment(ctx, controller, func() error {
		return PerformBackup(ctx, controller.Config, logger, backup)
	})
	if err != nil {
		logger.Error("failed to run scale deployment operation", slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("finish backing up canopy volume ✅")
}

// Initialize initializes the necessary components for the backup process.
func Initialize(logger *slog.Logger) (*Controller, IBackup, error) {
	client, err := GetClientSet()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get client set: %w", err)
	}

	config, err := LoadConfig()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get config: %w", err)
	}

	// logger.Info("config loaded", slog.Any("config", config))

	if err := config.Validate(); err != nil {
		return nil, nil, fmt.Errorf("config validation failed: %w", err)
	}

	controller := NewController(client, logger, config)

	s3 := config.S3
	backup, err := NewBackupS3(s3.AccessKey, s3.SecretAccessKey, s3.Region, s3.Endpoint, s3.Bucket)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create backup: %w", err)
	}

	return controller, backup, nil
}

func ScaleDeployment(ctx context.Context, controller *Controller, fn func() error) error {
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

func PerformBackup(ctx context.Context, config *Config, logger *slog.Logger, backup IBackup) error {
	logger.Info("starting canopy backup")

	fileName := fmt.Sprintf("%s.tar.gz", config.BackupKey)
	backupFile := filepath.Join(config.BackupPath, fileName)

	defer func() {
		if _, err := os.Stat(backupFile); err == nil {
			logger.Info("deleting backup")
			if err := os.Remove(backupFile); err != nil {
				logger.Error("failed to delete existing backup", slog.String("error", err.Error()))
			}
		}
	}()

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

	logger.Info("started compressing backup")
	if err := CompressFolder(config.SourcePath, backupFile); err != nil {
		return fmt.Errorf("compression failed: %w", err)
	}
	logger.Info("finished compressing backup")

	logger.Info("started uploading file to external storage")
	if err := backup.Backup(ctx, backupFile, config.BackupKey); err != nil {
		return fmt.Errorf("upload failed: %w", err)
	}
	logger.Info("finished uploading file to external storage")

	logger.Info("deleting backup successfully")

	return nil
}
