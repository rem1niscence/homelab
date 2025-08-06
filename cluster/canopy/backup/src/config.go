package main

import (
	"errors"
	"os"
)

// Config represents the configuration for the backup process.
type Config struct {
	CronSchedule string
	Deployment   string
	Namespace    string
	SourcePath   string
	BackupKey    string
	BackupPath   string
	S3           S3Config
}

// Validate checks if the configuration is valid.
func (c Config) Validate() error {
	if c.Deployment == "" {
		return errors.New("DEPLOYMENT is required")
	}
	if c.Namespace == "" {
		return errors.New("NAMESPACE is required")
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

// LoadConfig loads the configuration from environment variables.
func LoadConfig() (*Config, error) {
	return &Config{
		CronSchedule: getenv("CRON_SCHEDULE", "0 */6 * * *"),
		Deployment:   getenv("DEPLOYMENT", ""),
		Namespace:    getenv("NAMESPACE", ""),
		SourcePath:   getenv("SOURCE_PATH", ""),
		BackupKey:    getenv("BACKUP_KEY", ""),
		BackupPath:   getenv("BACKUP_PATH", "/backup"),
		S3: S3Config{
			AccessKey:       getenv("S3_ACCESS_KEY", ""),
			SecretAccessKey: getenv("S3_SECRET_ACCESS_KEY", ""),
			Region:          getenv("S3_REGION", ""),
			Endpoint:        getenv("S3_ENDPOINT", ""),
			Bucket:          getenv("S3_BUCKET", ""),
		},
	}, nil
}

func getenv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
