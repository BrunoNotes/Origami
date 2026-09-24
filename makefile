run:
	odin run src -debug

.PHONY: build
build:
	-@mkdir build
	odin build src -debug -out:build/origami.bin

clean:
	rm -rf build

shader:
	odin run src/shaders/compile.odin -file -- src/shaders build slang

build_vendor:
	$(MAKE) -C src/vendor/sdl3
