package main

import (
	"errors"
	"os"
)

type Config struct {
	CronSchedule string
	CanopyPath   string
	S3Path       string
	DBFolderName string
	Deployment   string
	Namespace    string
}

func (c Config) Validate() error {
	if c.S3Path == "" {
		return errors.New("S3_STORAGE_PATH is required")
	}
	return nil
}

func LoadConfig() (*Config, error) {
	return &Config{
		CronSchedule: getenv("CRON_SCHEDULE", "0 */6 * * *"),
		CanopyPath:   getenv("CANOPY_PATH", "/root/.canopy"),
		DBFolderName: getenv("DB_FOLDER_NAME", "canopy"),
		S3Path:       getenv("S3_STORAGE_PATH", ""),
		Deployment:   getenv("DEPLOYMENT", ""),
		Namespace:    getenv("NAMESPACE", ""),
	}, nil
}

func getenv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
