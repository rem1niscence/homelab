package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/reminiscence/homelab/cluster/canopy/scripts/pkg/config"
)

// BackupItem represents a single backup item configuration.
type BackupItem struct {
	BackupKey  string `json:"key"`
	SourcePath string `json:"path"`
	Compress   bool   `json:"compress"`
}

// BackupConfig represents the configuration for the backup process.
type BackupConfig struct {
	GlobalTimeout time.Duration
	BackupPath    string
	BackupItems   []BackupItem
	Controller    *config.ControllerConfig
	S3            *config.S3Config
}

// Validate checks if the configuration is valid.
func (b BackupConfig) Validate() error {
	if b.BackupPath == "" {
		return errors.New("BACKUP_PATH is required")
	}
	if len(b.BackupItems) == 0 {
		return errors.New("at least one backup item is required")
	}
	for i, item := range b.BackupItems {
		if item.BackupKey == "" {
			return fmt.Errorf("backup item %d: BackupKey is required", i)
		}
		if item.SourcePath == "" {
			return fmt.Errorf("backup item %d: SourcePath is required", i)
		}
	}
	if err := b.Controller.Validate(); err != nil {
		return err
	}
	if err := b.S3.Validate(); err != nil {
		return err
	}
	return nil
}

// LoadBackupConfig loads the configuration from environment variables.
func LoadBackupConfig() (*BackupConfig, error) {
	backupConfig := &BackupConfig{
		GlobalTimeout: time.Duration(config.GetInt64("GLOBAL_TIMEOUT", 15)) * time.Minute,
		BackupPath:    config.GetEnvString("BACKUP_PATH", ""),
		Controller: &config.ControllerConfig{
			Deployment:   config.GetEnvString("DEPLOYMENT", ""),
			Namespace:    config.GetEnvString("NAMESPACE", ""),
			PollTimeout:  time.Duration(config.GetInt64("POLL_TIMEOUT", 2)) * time.Minute,
			PollInterval: time.Duration(config.GetInt64("POLL_INTERVAL", 5)) * time.Second,
		},
		S3: &config.S3Config{
			AccessKey:       config.GetEnvString("S3_ACCESS_KEY", ""),
			SecretAccessKey: config.GetEnvString("S3_SECRET_ACCESS_KEY", ""),
			Region:          config.GetEnvString("S3_REGION", ""),
			Endpoint:        config.GetEnvString("S3_ENDPOINT", ""),
			Bucket:          config.GetEnvString("S3_BUCKET", ""),
		},
	}

	// parse backup items from JSON
	backupItemsJSON := config.GetEnvString("BACKUP_ITEMS", "")
	var items []BackupItem
	if err := json.Unmarshal([]byte(backupItemsJSON), &items); err != nil {
		return nil, fmt.Errorf("failed to parse BACKUP_ITEMS JSON: %w", err)
	}
	backupConfig.BackupItems = items

	return backupConfig, nil
}
