run:
	odin run src -debug

.PHONY: build
build:
	-@mkdir build
	odin build src -debug -out:build/origami.bin

clean:
	rm -rf build

