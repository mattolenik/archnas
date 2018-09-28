default: test

box:
	packer build -force archnas-box.json

test: box
	vagrant box add dist/archnas.box --name olenik/archnas
	cd test && vagrant up

.PHONY: box test
