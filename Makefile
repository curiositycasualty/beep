TREE ?=
BIRD ?=

PHONY: download-build-cache test

download-build-cache:
	

test:
	figlet '$(BIRD)'
	echo 'a $(BIRD) sitting in a $(TREE)'
