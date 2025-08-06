package main

import (
	"errors"
	"os"
)

type Config struct {
	CronSchedule string
	SourcePath   string
	BackupKey    string
	BackupPath   string
	Deployment   string
	Namespace    string
	S3           S3Config
}

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

type S3Config struct {
	AccessKey       string
	SecretAccessKey string
	Region          string
	Endpoint        string
	Bucket          string
}

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

func LoadConfig() (*Config, error) {
	return &Config{
		CronSchedule: getenv("CRON_SCHEDULE", "0 */6 * * *"),
		SourcePath:   getenv("SOURCE_PATH", "/root/.canopy/canopy"),
		BackupKey:    getenv("BACKUP_KEY", "canopy_backup.tar.gz"),
		BackupPath:   getenv("BACKUP_PATH", "/backup"),
		Deployment:   getenv("DEPLOYMENT", ""),
		Namespace:    getenv("NAMESPACE", ""),
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
