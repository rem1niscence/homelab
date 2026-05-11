package main

import (
	"errors"
	"time"

	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/config"
)

// RestoreConfig represents the configuration for the restore process.
type RestoreConfig struct {
	GlobalTimeout   time.Duration
	RootFolder      string
	HeightFile      string
	HeightFileURL   string
	SnapshotFile    string
	SnapshotFileURL string
	DbFolder        string
	DownloadFolder  string
	HeightThreshold int64
	S3              *config.S3Config
}

// Validate checks if the configuration is valid.
func (r RestoreConfig) Validate() error {
	if r.RootFolder == "" {
		return errors.New("ROOT_FOLDER is required")
	}
	if r.HeightFile == "" {
		return errors.New("HEIGHT_FILE is required")
	}
	if r.DbFolder == "" {
		return errors.New("DB_FOLDER is required")
	}
	if r.SnapshotFile == "" {
		return errors.New("SNAPSHOT_FILE is required")
	}
	if r.SnapshotFileURL == "" {
		return errors.New("SNAPSHOT_FILE_URL is required")
	}
	if r.HeightFileURL == "" {
		return errors.New("HEIGHT_FILE_URL is required")
	}
	if r.DownloadFolder == "" {
		return errors.New("DOWNLOAD_FOLDER is required")
	}
	if r.HeightThreshold <= 0 {
		return errors.New("HEIGHT_THRESHOLD must be greater than 0")
	}
	if err := r.S3.Validate(); err != nil {
		return err
	}
	return nil
}

// LoadRestoreConfig loads the configuration from environment variables.
func LoadRestoreConfig() (*RestoreConfig, error) {
	restoreConfig := &RestoreConfig{
		GlobalTimeout:   time.Duration(config.GetInt64("GLOBAL_TIMEOUT", 15)) * time.Minute,
		RootFolder:      config.GetEnvString("ROOT_FOLDER", ""),
		DownloadFolder:  config.GetEnvString("DOWNLOAD_FOLDER", ""),
		DbFolder:        config.GetEnvString("DB_FOLDER", ""),
		HeightThreshold: config.GetInt64("HEIGHT_THRESHOLD", 1000),
		HeightFile:      config.GetEnvString("HEIGHT_FILE", ""),
		HeightFileURL:   config.GetEnvString("HEIGHT_FILE_URL", ""),
		SnapshotFile:    config.GetEnvString("SNAPSHOT_FILE", ""),
		SnapshotFileURL: config.GetEnvString("SNAPSHOT_FILE_URL", ""),
		S3: &config.S3Config{
			AccessKey:       config.GetEnvString("S3_ACCESS_KEY", ""),
			SecretAccessKey: config.GetEnvString("S3_SECRET_ACCESS_KEY", ""),
			Region:          config.GetEnvString("S3_REGION", ""),
			Endpoint:        config.GetEnvString("S3_ENDPOINT", ""),
			Bucket:          config.GetEnvString("S3_BUCKET", ""),
		},
	}

	return restoreConfig, nil
}
