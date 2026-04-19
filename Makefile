.PHONY: build run test clean dev

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS := -ldflags "-X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME)"

# Go build
build:
	go build $(LDFLAGS) -o bin/grokpi ./cmd/grokpi

run: build
	./bin/grokpi

dev:
	go run $(LDFLAGS) ./cmd/grokpi

test:
	go test -race -v ./...

clean:
	rm -rf bin/ data/
