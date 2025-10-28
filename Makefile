NAS_CTX=nas
IMAGE_NAME=duplexer:latest

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
