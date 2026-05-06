package config

import "errors"

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
