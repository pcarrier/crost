package hashing

import (
	"errors"
	"fmt"
	"os"
)

const (
	chunkSize = 64 * 1024
)

func hashChunk(chunk []byte) uint64 {
	hash := uint64(0)
	for i := 0; i < chunkSize; i += 8 {
		hash += uint64(chunk[i+0]) << (0 * 8)
		hash += uint64(chunk[i+1]) << (1 * 8)
		hash += uint64(chunk[i+2]) << (2 * 8)
		hash += uint64(chunk[i+3]) << (3 * 8)
		hash += uint64(chunk[i+4]) << (4 * 8)
		hash += uint64(chunk[i+5]) << (5 * 8)
		hash += uint64(chunk[i+6]) << (6 * 8)
		hash += uint64(chunk[i+7]) << (7 * 8)
	}
	return hash
}

func Hash(file *os.File) (uint64, error) {
	chunk := make([]byte, chunkSize, chunkSize)

	// Hash first 64k
	_, err := file.Seek(0, os.SEEK_SET)
	if err != nil {
		return 0, err
	}
	read, err := file.Read(chunk)
	if err != nil {
		return 0, err
	}
	if read != chunkSize {
		msg := fmt.Sprintf(
			"read only %d bytes instead of %d; file too small?",
			read, chunkSize)
		return 0, errors.New(msg)
	}
	beginningHash := hashChunk(chunk)

	// Read last 64k (can overlap)
	pos, err := file.Seek(-chunkSize, os.SEEK_END)
	if err != nil {
		return 0, err
	}
	read, err = file.Read(chunk)
	if err != nil {
		return 0, err
	}
	if read != chunkSize {
		msg := fmt.Sprintf(
			"read %d bytes instead of %d at the end",
			read, chunkSize)
		return 0, errors.New(msg)
	}
	endHash := hashChunk(chunk)

	size := uint64(pos) + chunkSize
	finalHash := beginningHash + endHash + size
	return finalHash, nil
}
