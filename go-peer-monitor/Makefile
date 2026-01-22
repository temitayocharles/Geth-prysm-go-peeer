.PHONY: build run test docker clean

build:
	go build -o bin/peer-monitor .

run:
	go run main.go

test:
	go test ./...

docker:
	docker build -t peer-monitor:latest .

docker-load-minikube: docker
	minikube image load peer-monitor:latest

docker-load-kind: docker
	kind load docker-image peer-monitor:latest

clean:
	rm -rf bin/
