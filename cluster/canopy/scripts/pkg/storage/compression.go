package storage

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
)

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
func CompressFolderCMD(ctx context.Context, sourceDir, targetFile string) error {
	// get absolute paths
	absSource, err := filepath.Abs(sourceDir)
	if err != nil {
		return fmt.Errorf("failed to get absolute source path: %w", err)
	}
	absTarget, err := filepath.Abs(targetFile)
	if err != nil {
		return fmt.Errorf("failed to get absolute target path: %w", err)
	}

	// construct the command to tar the contents of sourceDir
	// tar -C <sourceDir> -cvf - . | pigz > targetFile
	cmd := exec.CommandContext(ctx, "tar", "-C", absSource, "-cvf", "-", ".")

	pigzCmd := exec.CommandContext(ctx, "pigz")

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
	defer func() {
		outputFile.Close()
		if err != nil {
			// clean up on failure
			_ = os.Remove(absTarget)
		}
	}()

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

	_ = pipe.Close()

	if err := pigzCmd.Wait(); err != nil {
		return fmt.Errorf("pigz command failed: %w", err)
	}

	return nil
}

// DecompressCMD decompresses a tar.gz file using pigz + tar
func DecompressCMD(ctx context.Context, sourceFile, targetDir string) error {
	// get absolute paths
	absSource, err := filepath.Abs(sourceFile)
	if err != nil {
		return fmt.Errorf("failed to get absolute source path: %w", err)
	}
	absTarget, err := filepath.Abs(targetDir)
	if err != nil {
		return fmt.Errorf("failed to get absolute target path: %w", err)
	}

	// ensure target directory exists
	if err := os.MkdirAll(absTarget, 0755); err != nil {
		return fmt.Errorf("failed to create target directory: %w", err)
	}

	// construct the commands: pigz -dc source | tar -C target -xv
	pigzCmd := exec.CommandContext(ctx, "pigz", "-dc", absSource)
	tarCmd := exec.CommandContext(ctx, "tar", "-C", absTarget, "-xv")

	// create the pipeline
	pipe, err := pigzCmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create pipe: %w", err)
	}

	tarCmd.Stdin = pipe
	pigzCmd.Stderr = os.Stderr
	tarCmd.Stderr = os.Stderr

	// start both commands
	if err := tarCmd.Start(); err != nil {
		return fmt.Errorf("failed to start tar: %w", err)
	}

	if err := pigzCmd.Start(); err != nil {
		return fmt.Errorf("failed to start pigz: %w", err)
	}

	// wait for completion
	if err := pigzCmd.Wait(); err != nil {
		return fmt.Errorf("pigz command failed: %w", err)
	}

	pipe.Close()

	if err := tarCmd.Wait(); err != nil {
		return fmt.Errorf("tar command failed: %w", err)
	}

	return nil
}

// BadgerFlatten runs `badger flatten --dir {directory}` to rewrite value log files
// and reclaim space. Requires the `badger` CLI to be installed and on PATH.
func FlattenBadgerDB(ctx context.Context, dir string) error {
	absDir, err := filepath.Abs(dir)
	if err != nil {
		return fmt.Errorf("failed to get absolute directory path: %w", err)
	}

	info, err := os.Stat(absDir)
	if err != nil {
		return fmt.Errorf("failed to stat directory: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("path %s is not a directory", absDir)
	}

	cmd := exec.CommandContext(ctx, "badger", "flatten", "--dir", absDir)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start badger flatten: %w", err)
	}
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("badger flatten failed: %w", err)
	}
	return nil
}
