Remove-Item '.\src\build' -Recurse
cmake -S .\src -B .\src\build -DSDL_SHARED=OFF -DSDL_STATIC=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build .\src\build --config Release
