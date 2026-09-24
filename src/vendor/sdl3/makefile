all: build

build: clean_build
	cmake -S ./src -B ./src/build -DSDL_SHARED=OFF -DSDL_STATIC=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON
	cmake --build ./src/build --config Release

build_windows: clean_build
	mingw64-cmake -S ./src -B ./src/build -DSDL_SHARED=OFF -DSDL_STATIC=ON -DCMAKE_BUILD_TYPE=Release
	cd src/build && mingw64-make

clean_build:
	@-rm -rf ./src/build
	@-mkdir -p ./src/build
