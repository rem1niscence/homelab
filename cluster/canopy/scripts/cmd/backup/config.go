package main

import (
	"encoding/json"
	"errors"
	"fmt"

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
	BackupPath  string
	BackupItems []BackupItem
	Controller  *config.ControllerConfig
	S3          *config.S3Config
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
		Controller: &config.ControllerConfig{
			Deployment: config.Getenv("DEPLOYMENT", ""),
			Namespace:  config.Getenv("NAMESPACE", ""),
		},
		BackupPath: config.Getenv("BACKUP_PATH", ""),
		S3: &config.S3Config{
			AccessKey:       config.Getenv("S3_ACCESS_KEY", ""),
			SecretAccessKey: config.Getenv("S3_SECRET_ACCESS_KEY", ""),
			Region:          config.Getenv("S3_REGION", ""),
			Endpoint:        config.Getenv("S3_ENDPOINT", ""),
			Bucket:          config.Getenv("S3_BUCKET", ""),
		},
	}

	// parse backup items from JSON
	backupItemsJSON := config.Getenv("BACKUP_ITEMS", "")
	var items []BackupItem
	if err := json.Unmarshal([]byte(backupItemsJSON), &items); err != nil {
		return nil, fmt.Errorf("failed to parse BACKUP_ITEMS JSON: %w", err)
	}
	backupConfig.BackupItems = items

	return backupConfig, nil
}
