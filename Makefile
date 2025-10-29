# Load environment variables from .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values if not set in .env
NAS_CTX ?= $(DOCKER_CONTEXT)
IMAGE_NAME ?= duplexer:latest
DEV_IMAGE_NAME ?= duplexer:dev
CONTAINER_NAME ?= duplexer

# Production builds and deployment
build-local:
	docker build -t $(IMAGE_NAME) ./docker

build-remote: check-prereqs
	docker --context $(NAS_CTX) build -t $(IMAGE_NAME) ./docker

up: check-prereqs
	docker --context $(NAS_CTX) compose -f ./deploy/docker-compose.yml up -d

down:
	docker --context $(NAS_CTX) compose -f ./deploy/docker-compose.yml down

logs:
	docker --context $(NAS_CTX) logs -f duplexer

restart:
	docker --context $(NAS_CTX) compose -f ./deploy/docker-compose.yml restart

# Development commands
dev-setup:
	./setup-dev.sh

dev-build:
	docker build -t $(DEV_IMAGE_NAME) ./docker

dev-up:
	docker-compose -f docker-compose.dev.yml up -d

dev-down:
	docker-compose -f docker-compose.dev.yml down

dev-logs:
	docker logs -f duplexer-dev

dev-shell:
	docker exec -it duplexer-dev bash

# Prerequisites and validation
check-prereqs:
	./scripts/check-prerequisites.sh

validate-env:
	./scripts/validate-env.sh

# Testing
test:
	./test/run_e2e_test.sh

test-pdfs:
	./test/create_test_pdfs.sh

# Testing and validation
test:
	@echo "Running shellcheck on scripts..."
	find docker/scripts -name "*.sh" -exec shellcheck {} +
	@echo "Testing script syntax..."
	bash -n docker/scripts/watch.sh
	bash -n docker/scripts/merge_once.sh
	bash -n docker/scripts/health_check.sh
	bash -n docker/scripts/logrotate.sh

clean:
	docker system prune -f
	docker volume prune -f

# Utility commands
health:
	docker --context $(NAS_CTX) exec duplexer /app/health_check.sh

backup-logs:
	docker --context $(NAS_CTX) exec duplexer /app/logrotate.sh

status:
	docker --context $(NAS_CTX) ps | grep duplexer
	docker --context $(NAS_CTX) exec duplexer /app/health_check.sh

.PHONY: build-local build-remote up down logs restart dev-setup dev-build dev-up dev-down dev-logs dev-shell test clean health backup-logs status
