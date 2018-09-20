export PATH := $(PWD)/bats/bin:$(PATH)

default: test

test:
	./tests.bats
