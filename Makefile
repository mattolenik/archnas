default: test

dist/archnas.box: archnas-box.json
	packer build -force archnas-box.json

test: dist/archnas.box
	vagrant box add dist/archnas.box --name olenik/archnas --force
	vagrant up

clean:
	vagrant destroy -f
	rm -rf dist/
	rm -rf output-*/
	rm -rf packer_cache/
	rm -rf .vagrant/

.PHONY: clean test
