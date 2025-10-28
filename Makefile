NAS_CTX=***REMOVED***
IMAGE_NAME=duplexer:latest
DEV_IMAGE_NAME=duplexer:dev

# Production builds and deployment
build-local:
	docker build -t $(IMAGE_NAME) ./docker

build-remote:
	docker --context $(NAS_CTX) build -t $(IMAGE_NAME) ./docker

up:
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
