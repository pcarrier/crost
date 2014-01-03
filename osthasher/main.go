package main

import (
	"fmt"
	"github.com/pcarrier/crost/hashing"
	"log"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: osthasher filename [...]")
	}
	for _, filename := range os.Args[1:] {
		file, err := os.Open(filename)
		if err != nil {
			log.Fatal(err)
		}
		hash, err := hashing.Hash(file)
		if err != nil {
			log.Fatalf("%s: %v", filename, err)
		}
		fmt.Printf("%016x\t%s\n", hash, filename)
	}
}
