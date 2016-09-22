default: present
build-image:
	docker build -t protochron/automacon-2016 .

present-dev: build-image
	docker run --rm -it --net=host -v $(shell pwd)/contents.md:/reveal/contents.md -v $(shell pwd)/assets:/reveal/assets -v $(shell pwd)/index.html:/reveal/index.html protochron/automacon-2016

present: build-image
	docker run --rm -it --net=host protochron/automacon-2016
