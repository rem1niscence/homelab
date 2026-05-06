package config

import (
	"errors"
	"time"
)

// ControllerConfig represents the configuration for the controller process.
type ControllerConfig struct {
	Deployment   string
	Namespace    string
	PollTimeout  time.Duration
	PollInterval time.Duration
}

// Validate checks if the controller configuration is valid.
func (c ControllerConfig) Validate() error {
	// Add validation logic here
	if c.Deployment == "" {
		return errors.New("DEPLOYMENT is required")
	}
	if c.Namespace == "" {
		return errors.New("NAMESPACE is required")
	}
	return nil
}
