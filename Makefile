default: test

dist/archnas.box: archnas-box.json
	packer build -force archnas-box.json

start: dist/archnas.box
	vagrant box add dist/archnas.box --name archnas/archnas --force
	vagrant up

test: start
	vagrant ssh -c './tests.bats'
	vagrant down
	vagrant destroy -f

clean:
	vagrant destroy -f
	rm -rf dist/
	rm -rf output-*/

scrub: clean
	rm -rf packer_cache/
	rm -rf .vagrant/

.PHONY: clean scrub start test
