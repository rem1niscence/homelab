package storage

import (
	"context"
	"io"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var _ StorageManager = (*S3StorageManager)(nil)

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

type S3StorageManager struct {
	s3Client *s3.Client
	Bucket   string
	Key      string
}

// NewCustomS3StorageManager creates a new S3 client with the given parameters for a custom S3-compatible storage.
func NewCustomS3StorageManager(accessKey, secretKey, region, endpoint, bucket string) (*S3StorageManager, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			accessKey,
			secretKey,
			"",
		)),
	)
	if err != nil {
		return nil, err
	}

	return &S3StorageManager{
		s3Client: s3.NewFromConfig(cfg, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(endpoint)
			o.UsePathStyle = true
			o.APIOptions = append(o.APIOptions,
				v4.SwapComputePayloadSHA256ForUnsignedPayloadMiddleware,
			)
		}),
		Bucket: bucket,
	}, nil
}

func (s *S3StorageManager) Upload(ctx context.Context, reader io.Reader, key string) error {
	_, err := s.s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(s.Bucket),
		Key:    aws.String(key),
		Body:   reader,
	})

	return err
}

func (s *S3StorageManager) Download(ctx context.Context, location string) (io.ReadCloser, error) {
	result, err := s.s3Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.Bucket),
		Key:    aws.String(location),
	})
	if err != nil {
		return nil, err
	}

	return result.Body, nil
}
