NAS_USER         ?= root
NAS_IP           ?= 192.168.1.10
export VM_NAME    = archnas_vagrant
VBOX_MACHINE_DIR := $(shell tools/get-vbox-machine-dir)
SSH_OPTS          = -F .ssh_config

default: build

build:
	mkdir -p dist
	tar czvf dist/archnas.tar.gz src/

deploy: vagrant build
	#cat dist/archnas.tar.gz | ssh -F .ssh_config -t vagrant@127.0.0.1 -p 2222 'tar xzf - -C /home/vagrant' # $D/src/install.sh;'

vagrant:
	vagrant up
	vagrant ssh-config > .ssh_config

test:
	vagrant destroy -f || true && vagrant up

clean:
	rm -rf dist/
	vagrant destroy -f
	rm -rf "$(VBOX_MACHINE_DIR)/$(VM_NAME)"

.PHONY: build clean deploy vagrant test
