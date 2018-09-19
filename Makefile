NAS_IP ?= 192.168.1.10

default: build

build:
	mkdir -p dist
	tar czvf dist/archnas.tar install.sh vars.sh src

deploy: build
	cat dist/archnas.tar | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$(NAS_IP) 'tar xzvf -'
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t root@$(NAS_IP) ./install.sh

clean:
	rm -rf dist/

.PHONY: build clean deploy
