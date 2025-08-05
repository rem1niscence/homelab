package main

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	autoscalingv1 "k8s.io/api/autoscaling/v1"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
)

type Controller struct {
	Client       *kubernetes.Clientset
	Logger       *slog.Logger
	Config       *Config
	PollTimeout  time.Duration
	PollInterval time.Duration
}

func NewController(client *kubernetes.Clientset, logger *slog.Logger, config *Config) *Controller {
	return &Controller{
		Client:       client,
		Logger:       logger,
		Config:       config,
		PollTimeout:  1 * time.Minute,
		PollInterval: 5 * time.Second,
	}
}

func (c *Controller) ScaleDeployment(ctx context.Context, scale int) error {
	scaleConfig := &autoscalingv1.Scale{
		ObjectMeta: v1.ObjectMeta{
			Namespace: c.Config.Namespace,
			Name:      c.Config.Deployment,
		},
		Spec: autoscalingv1.ScaleSpec{
			Replicas: int32(scale),
		},
	}
	_, err := c.Client.AppsV1().Deployments(c.Config.Namespace).UpdateScale(ctx,
		c.Config.Deployment, scaleConfig, v1.UpdateOptions{})
	if err != nil {
		return fmt.Errorf("cannot scale deployment: %w", err)
	}
	return nil
}

func (c *Controller) GetDeployment(ctx context.Context) (*appsv1.Deployment, error) {
	return c.Client.AppsV1().Deployments(c.Config.Namespace).Get(ctx, c.Config.Deployment, v1.GetOptions{})
}

func (c *Controller) WaitForScaling(ctx context.Context, wanted int) error {
	return wait.PollUntilContextTimeout(ctx, c.PollInterval, c.PollTimeout, false,
		func(ctx context.Context) (done bool, err error) {
			deployment, err := c.GetDeployment(ctx)
			if err != nil {
				return false, err
			}
			if deployment.Spec.Replicas == nil {
				return false, nil
			}
			c.Logger.Info("waiting for scale...",
				slog.Int("current_replicas", int(*deployment.Spec.Replicas)),
				slog.Int("available_replicas", int(deployment.Status.AvailableReplicas)),
			)
			return int(*deployment.Spec.Replicas) == wanted, nil
		})
}
