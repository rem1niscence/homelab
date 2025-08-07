package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
)

// BackupItem represents a single backup item configuration.
type BackupItem struct {
	BackupKey  string `json:"key"`
	SourcePath string `json:"path"`
	Compress   bool   `json:"compress"`
}

// BackupConfig represents the configuration for the backup process.
type BackupConfig struct {
	Deployment  string
	Namespace   string
	BackupPath  string
	BackupItems []BackupItem
	S3          S3Config
}

// Validate checks if the configuration is valid.
func (c BackupConfig) Validate() error {
	if c.Deployment == "" {
		return errors.New("DEPLOYMENT is required")
	}
	if c.Namespace == "" {
		return errors.New("NAMESPACE is required")
	}
	if c.BackupPath == "" {
		return errors.New("BACKUP_PATH is required")
	}
	if len(c.BackupItems) == 0 {
		return errors.New("at least one backup item is required")
	}
	for i, item := range c.BackupItems {
		if item.BackupKey == "" {
			return fmt.Errorf("backup item %d: BackupKey is required", i)
		}
		if item.SourcePath == "" {
			return fmt.Errorf("backup item %d: SourcePath is required", i)
		}
	}
	if err := c.S3.Validate(); err != nil {
		return err
	}
	return nil
}

// S3Config represents the configuration for the S3 backup process.
type S3Config struct {
	AccessKey       string
	SecretAccessKey string
	Region          string
	Endpoint        string
	Bucket          string
}

// Validate checks if the S3 configuration is valid.
func (s S3Config) Validate() error {
	if s.AccessKey == "" {
		return errors.New("S3_ACCESS_KEY is required")
	}
	if s.SecretAccessKey == "" {
		return errors.New("S3_SECRET_ACCESS_KEY is required")
	}
	if s.Region == "" {
		return errors.New("S3_REGION is required")
	}
	if s.Endpoint == "" {
		return errors.New("S3_ENDPOINT is required")
	}
	if s.Bucket == "" {
		return errors.New("S3_BUCKET is required")
	}
	return nil
}

// LoadBackupConfig loads the configuration from environment variables.
func LoadBackupConfig() (*BackupConfig, error) {
	config := &BackupConfig{
		Deployment: getenv("DEPLOYMENT", ""),
		Namespace:  getenv("NAMESPACE", ""),
		BackupPath: getenv("BACKUP_PATH", ""),
		S3: S3Config{
			AccessKey:       getenv("S3_ACCESS_KEY", ""),
			SecretAccessKey: getenv("S3_SECRET_ACCESS_KEY", ""),
			Region:          getenv("S3_REGION", ""),
			Endpoint:        getenv("S3_ENDPOINT", ""),
			Bucket:          getenv("S3_BUCKET", ""),
		},
	}

	// parse backup items from JSON
	backupItemsJSON := getenv("BACKUP_ITEMS", "")
	var items []BackupItem
	if err := json.Unmarshal([]byte(backupItemsJSON), &items); err != nil {
		return nil, fmt.Errorf("failed to parse BACKUP_ITEMS JSON: %w", err)
	}
	config.BackupItems = items

	return config, nil
}

func getenv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
