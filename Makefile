NAS_IP           ?= 192.168.1.10
export VM_NAME    = archnas_vagrant
VBOX_MACHINE_DIR := $(shell tools/get-vbox-machine-dir)

default: build

build:
	mkdir -p dist
	tar czvf dist/archnas.tar install.sh vars.sh src

deploy: build
	cat dist/archnas.tar | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$(NAS_IP) 'tar xzvf -'
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t root@$(NAS_IP) ./install.sh

test:
	vagrant destroy -f || true && vagrant up

clean:
	rm -rf dist/
	vagrant destroy -f
	rm -rf "$(VBOX_MACHINE_DIR)/$(VM_NAME)"

.PHONY: build clean deploy
