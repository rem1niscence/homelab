package lifecycle

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
)

func GracefulShutdown(ctx context.Context, logger *slog.Logger,
	cancel context.CancelFunc, fn ...func() error) context.Context {
	sigCtx, sigCancel := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigCtx.Done()
		if errors.Is(sigCtx.Err(), context.Canceled) {
			logger.Warn("received shutdown signal, initiating graceful shutdown...")

			if fn != nil {
				if err := fn[0](); err != nil {
					logger.Error("graceful shutdown failed", slog.String("error", err.Error()))
				}
			}
			cancel() // Cancel the main context
		}
		sigCancel()
	}()

	return sigCtx
}
