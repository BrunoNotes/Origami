OS=$(shell uname)

ifeq ($(OS), Darwin)
all: darwin
else
all: unix
endif

wasm:
	mkdir -p ../lib
	$(CC) -c -Os --target=wasm32 --sysroot=$(shell odin root)/vendor/libc stb_image.c        -o ../lib/stb_image_wasm.o        -DSTBI_NO_STDIO
	$(CC) -c -Os --target=wasm32 --sysroot=$(shell odin root)/vendor/libc stb_image_write.c  -o ../lib/stb_image_write_wasm.o  -DSTBI_WRITE_NO_STDIO
	$(CC) -c -Os --target=wasm32 --sysroot=$(shell odin root)/vendor/libc stb_image_resize.c -o ../lib/stb_image_resize_wasm.o

unix:
	mkdir -p ../lib
	$(CC) -c -O2 -Os -fPIC stb_image.c stb_image_write.c stb_image_resize.c
	$(AR) rcs ../lib/stb_image.a        stb_image.o
	$(AR) rcs ../lib/stb_image_write.a  stb_image_write.o
	$(AR) rcs ../lib/stb_image_resize.a stb_image_resize.o
	#$(CC) -fPIC -shared -Wl,-soname=stb_image.so         -o ../lib/stb_image.so        stb_image.o
	#$(CC) -fPIC -shared -Wl,-soname=stb_image_write.so   -o ../lib/stb_image_write.so  stb_image_write.o
	#$(CC) -fPIC -shared -Wl,-soname=stb_image_resize.so  -o ../lib/stb_image_resize.so stb_image_resize.o
	rm *.o

darwin:
	mkdir -p ../lib
	$(CC) -arch x86_64 -c -O2 -Os -fPIC stb_image.c -o stb_image-x86_64.o -mmacosx-version-min=10.12
	$(CC) -arch arm64  -c -O2 -Os -fPIC stb_image.c -o stb_image-arm64.o -mmacosx-version-min=10.12
	lipo -create stb_image-x86_64.o stb_image-arm64.o -output ../lib/darwin/stb_image.a
	$(CC) -arch x86_64 -c -O2 -Os -fPIC stb_image_write.c -o stb_image_write-x86_64.o -mmacosx-version-min=10.12
	$(CC) -arch arm64  -c -O2 -Os -fPIC stb_image_write.c -o stb_image_write-arm64.o -mmacosx-version-min=10.12
	lipo -create stb_image_write-x86_64.o stb_image_write-arm64.o -output ../lib/darwin/stb_image_write.a
	$(CC) -arch x86_64 -c -O2 -Os -fPIC stb_image_resize.c -o stb_image_resize-x86_64.o -mmacosx-version-min=10.12
	$(CC) -arch arm64  -c -O2 -Os -fPIC stb_image_resize.c -o stb_image_resize-arm64.o -mmacosx-version-min=10.12
	lipo -create stb_image_resize-x86_64.o stb_image_resize-arm64.o -output ../lib/darwin/stb_image_resize.a
	rm *.o
