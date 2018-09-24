NAS_USER             ?= root
NAS_IP               ?= 192.168.1.10
export VM_NAME        = archnas_vagrant
export TEST_VM_NAME   = archnas_test
VBOX_MACHINE_DIR     := $(shell tools/get-vbox-machine-dir)
SSH_OPTS              = -F .ssh_config

default: build

build:
	mkdir -p dist
	tar czvf dist/archnas.tar.gz src/

#deploy: vagrant build
	#cat dist/archnas.tar.gz | ssh -F .ssh_config -t vagrant@127.0.0.1 -p 2222 'tar xzf - -C /home/vagrant'

vagrant:
	mkdir -p dist/
	vagrant up
	vagrant halt

test: vagrant
	cd test && vagrant up

clean:
	vagrant destroy -f
	cd test && vagrant destroy -f
	rm -rf dist/
	rm -rf "$(VBOX_MACHINE_DIR)/$(VM_NAME)"
	rm -rf "$(VBOX_MACHINE_DIR)/$(TEST_VM_NAME)"

.PHONY: build clean deploy vagrant test
