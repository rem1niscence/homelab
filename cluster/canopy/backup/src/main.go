package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"time"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	logger.Info("starting backup controller at", slog.String("time", time.Now().String()))
	client, err := GetClientSet()
	if err != nil {
		logger.Error("failed to get clientset", slog.String("error", err.Error()))
		os.Exit(1)
	}

	config, err := LoadConfig()
	if err != nil {
		logger.Error("failed to get config", slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("config loaded", slog.Any("config", config))

	if err := config.Validate(); err != nil {
		logger.Error("config validation failed", slog.String("error", err.Error()))
		os.Exit(1)
	}

	controller := NewController(client, logger, config)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	err = ScaleDeployment(ctx, controller, func() error {
		return nil
	})
	if err != nil {
		logger.Error("failed to run scale deployment operation", slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("finish backing up canopy volume ✅")
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

	return nil
}
