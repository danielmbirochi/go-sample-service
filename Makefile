SHELL := /bin/bash

export CLUSTER_NAME = go-sample-service

# ==============================================================================
# Testing the running system 
#
# curl --user "admin@example.com:gophers" http://localhost:3000/v1/users/token/32bc1165-24t2-61a7-af3e-9da4agf2h1p1
# export TOKEN="YOUR_TOKEN_HERE"
# curl -H "Authorization: Bearer ${TOKEN}" http://localhost:3000/v1/users/1/2
#
# hey -m GET -c 100 -n 10000 -H "Authorization: Bearer ${TOKEN}" http://localhost:3000/v1/users/1/2
# zipkin: http://localhost:9411
# expvarmon -ports 4000 -vars build,requests,goroutines,errors,mem:memstats.Alloc
#

# ==============================================================================
# CLI Help

admin-help:
	go run app/sales-admin/main.go -h

run-help:
	go run app/sales-api/main.go -h

# ==============================================================================
# Building containers

all: sales-api

sales-api:
	docker build \
		-f ops/docker/dockerfile.sales-api \
		-t sales-api-amd64:v1.0.0 \
		--build-arg PACKAGE_NAME=sales-api \
		--build-arg VCS_REF=`git rev-parse HEAD` \
		--build-arg BUILD_DATE=`date -u +”%Y-%m-%dT%H:%M:%SZ”` \
		.

# ==============================================================================
# Running from within k8s/dev

kind-up:
	kind create cluster --image kindest/node:v1.22.1 --name ${CLUSTER_NAME} --config ops/k8s/dev/kind-config.yaml
# Runs the command below to set a default namespace
# kubectl config set-context --current --namespace=sales-system

kind-down:
	kind delete cluster --name ${CLUSTER_NAME}

kind-load:
	kind load docker-image sales-api-amd64:v1.0.0 --name ${CLUSTER_NAME}

kind-apply:
	kustomize build ops/k8s/dev | kubectl apply -f -

kind-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide

kind-status-full:
	kubectl describe pod -lapp=sales-api --namespace=sales-system

kind-status-service:
	kubectl get pods -o wide --namespace=sales-system

kind-logs:
	kubectl logs -lapp=sales-api --all-containers=true -f --tail=10000 --namespace=sales-system

kind-restart:
	kubectl rollout restart deployment sales-api --namespace=sales-system

kind-sales-api-update: sales-api # kind-load kind-restart   
	kind load docker-image sales-api-amd64:v1.0.0 --name ${CLUSTER_NAME}
	kubectl delete pods -lapp=sales-api


# ==============================================================================
# Running locally

run:
	go run app/sales-api/main.go

run-admin:
	go run app/sales-admin/main.go 

build:
	go build -o app/sales-api/sales-api app/sales-api/main.go

# ==============================================================================
# Administration

generate-keys:
	go run app/sales-admin/main.go keygen

generate-token:
	go run app/sales-admin/main.go tokengen ${EMAIL}

db-migrations:
	go run app/sales-admin/main.go migrate

seed-db:
	go run app/sales-admin/main.go seed

# ==============================================================================
# Running local tests

test:
	go test -v ./... -count=1
	staticcheck ./...

test-coverage:
	go test -coverprofile cover.out -v ./... -count=1

test-coverage-detail:
	go tool cover -html cover.out

test-crud:
	cd app/sales-api/tests && go test -run TestUsers/crud -v 

# ==============================================================================
# Modules support

tidy:
	go mod tidy
	go mod vendor