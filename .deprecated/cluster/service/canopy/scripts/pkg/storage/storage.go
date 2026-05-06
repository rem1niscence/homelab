package storage

import (
	"context"
	"io"
	"time"
)

type Uploader interface {
	Upload(ctx context.Context, reader io.Reader, key string, contentLength int64) error
}

type Downloader interface {
	Download(ctx context.Context, location string) (body io.ReadCloser, size int64, err error)
}

type StorageManager interface {
	Uploader
	Downloader
}

// ProgressReader is a wrapper around an io.Reader that reports the read progress.
type ProgressReader struct {
	reader     io.Reader
	size       int64
	read       int64
	onProgress func(read, total int64)
	interval   time.Duration
	lastUpdate time.Time
}

func NewProgressReader(reader io.Reader, size int64, interval time.Duration, onProgress func(read, total int64)) *ProgressReader {
	return &ProgressReader{
		reader:     reader,
		size:       size,
		read:       0,
		onProgress: onProgress,
		interval:   interval,
		lastUpdate: time.Now(),
	}
}

func (pr *ProgressReader) Read(p []byte) (int, error) {
	n, err := pr.reader.Read(p)
	pr.read += int64(n)
	if pr.onProgress != nil && time.Since(pr.lastUpdate) > pr.interval {
		pr.onProgress(pr.read, pr.size)
		pr.lastUpdate = time.Now()
	}
	return n, err
}

func (pr *ProgressReader) Close() error {
	if closer, ok := pr.reader.(io.Closer); ok {
		return closer.Close()
	}
	return nil
}
