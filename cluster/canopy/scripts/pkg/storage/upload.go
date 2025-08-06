package storage

import (
	"context"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var _ Uploader = UploadS3{}

type Uploader interface {
	UploadFS(ctx context.Context, filePath string, key string) error
}

type UploadS3 struct {
	s3Client *s3.Client
	Bucket   string
	Key      string
}

// NewCustomS3Uploader creates a new S3 client with the given parameters for a custom S3-compatible storage.
func NewCustomS3Uploader(accessKey, secretKey, region, endpoint, bucket string) (*UploadS3, error) {
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

	return &UploadS3{
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

func (b UploadS3) UploadFS(ctx context.Context, filePath, key string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = b.s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(b.Bucket),
		Key:    aws.String(key),
		Body:   file,
	})

	return err
}
