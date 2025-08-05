package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
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

	logger.Info("scaling down deployment", slog.String("deployment", config.Deployment))
	err = controller.ScaleDeployment(ctx, 0)
	if err != nil {
		logger.Error("failed to scale down deployment", slog.String("error", err.Error()))
		os.Exit(1)
	}

	if err := controller.WaitForScaling(ctx, 0); err != nil {
		logger.Error("failed to scale down deployment", slog.String("deployment", config.Deployment),
			slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("scaling up deployment", slog.String("deployment", config.Deployment))
	err = controller.ScaleDeployment(ctx, 1)
	if err != nil {
		logger.Error("failed to scale up deployment", slog.String("error", err.Error()))
		os.Exit(1)
	}

	if err := controller.WaitForScaling(ctx, 1); err != nil {
		logger.Error("failed to scale up deployment", slog.String("deployment", config.Deployment),
			slog.String("error", err.Error()))
		os.Exit(1)
	}

	logger.Info("finish backing up canopy volume ✅")
}

func GetClientSet() (*kubernetes.Clientset, error) {
	config, err := rest.InClusterConfig()
	if err != nil {
		return nil, err
	}
	clientConfig, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, err
	}
	return clientConfig, nil
}
