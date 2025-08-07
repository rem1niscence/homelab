package storage

import (
	"context"
	"io"
)

type Uploader interface {
	Upload(ctx context.Context, reader io.Reader, key string) error
}

type Downloader interface {
	Download(ctx context.Context, location string) (io.ReadCloser, error)
}

type StorageManager interface {
	Uploader
	Downloader
}