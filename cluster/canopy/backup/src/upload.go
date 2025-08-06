package main

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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

// CompressFolder compresses a folder into a tar.gz file using gzip + tar compression
func CompressFolder(sourceDir, targetFile string) error {
	file, err := os.Create(targetFile)
	if err != nil {
		return fmt.Errorf("failed to create target file: %w", err)
	}
	defer file.Close()

	gzWriter := gzip.NewWriter(file)
	defer gzWriter.Close()
	tarWriter := tar.NewWriter(gzWriter)
	defer tarWriter.Close()

	baseName := filepath.Base(sourceDir)
	return filepath.Walk(sourceDir, func(filePath string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		header, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return fmt.Errorf("failed to create tar header: %w", err)
		}

		relPath, err := filepath.Rel(sourceDir, filePath)
		if err != nil {
			return fmt.Errorf("failed to get relative path: %w", err)
		}

		header.Name = filepath.Join(baseName, strings.ReplaceAll(relPath, "\\", "/"))
		if err := tarWriter.WriteHeader(header); err != nil {
			return fmt.Errorf("failed to write tar header: %w", err)
		}

		if info.Mode().IsRegular() {
			file, err := os.Open(filePath)
			if err != nil {
				return fmt.Errorf("failed to open file %s: %w", filePath, err)
			}
			defer file.Close()
			_, err = io.Copy(tarWriter, file)
			if err != nil {
				return fmt.Errorf("failed to write file content: %w", err)
			}
		}
		return nil
	})
}

// CompressFolderCMD compresses a folder into a tar.gz file using tar + pigz
// requires pigz to be installed on the system
func CompressFolderCMD(sourceDir, targetFile string) error {
	// get absolute paths
	absSource, err := filepath.Abs(sourceDir)
	if err != nil {
		return fmt.Errorf("failed to get absolute source path: %w", err)
	}
	absTarget, err := filepath.Abs(targetFile)
	if err != nil {
		return fmt.Errorf("failed to get absolute target path: %w", err)
	}
	parentDir := filepath.Dir(absSource)
	folderName := filepath.Base(absSource)

	// construct the commands
	cmd := exec.Command("tar", "-cv", folderName)
	cmd.Dir = parentDir

	pigzCmd := exec.Command("pigz")

	// create the pipeline
	pipe, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create pipe: %w", err)
	}

	pigzCmd.Stdin = pipe
	outputFile, err := os.Create(absTarget)
	if err != nil {
		return fmt.Errorf("failed to create output file: %w", err)
	}
	defer outputFile.Close()

	pigzCmd.Stdout = outputFile
	pigzCmd.Stderr = os.Stderr

	// start both commands
	if err := pigzCmd.Start(); err != nil {
		return fmt.Errorf("failed to start pigz: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start tar: %w", err)
	}

	// wait for completion
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("tar command failed: %w", err)
	}

	pipe.Close()

	if err := pigzCmd.Wait(); err != nil {
		return fmt.Errorf("pigz command failed: %w", err)
	}

	return nil
}
