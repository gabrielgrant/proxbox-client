build-image:
	docker build -t gabrielgrant/proxbox-client:0.1.2 .
publish-image: build-image
	docker push gabrielgrant/proxbox-client:0.1.2
