package hashing

import (
	"encoding/binary"
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
		hash += binary.LittleEndian.Uint64(chunk[i : i+8])
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
	bytesRead, err := file.Read(chunk)
	if err != nil {
		return 0, err
	}
	if bytesRead != chunkSize {
		msg := fmt.Sprintf(
			"read only %d bytes instead of %d; file too small?",
			bytesRead, chunkSize)
		return 0, errors.New(msg)
	}
	beginningHash := hashChunk(chunk)

	// Read last 64k (can overlap)
	pos, err := file.Seek(-chunkSize, os.SEEK_END)
	if err != nil {
		return 0, err
	}
	bytesRead, err = file.Read(chunk)
	if err != nil {
		return 0, err
	}
	if bytesRead != chunkSize {
		msg := fmt.Sprintf(
			"read %d bytes instead of %d at the end",
			bytesRead, chunkSize)
		return 0, errors.New(msg)
	}
	endHash := hashChunk(chunk)

	size := uint64(pos) + chunkSize
	finalHash := beginningHash + endHash + size
	return finalHash, nil
}
