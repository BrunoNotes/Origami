@echo off

if not exist "..\lib" mkdir ..\lib

cl -nologo -MT -TC -O2 -c stb_image.c stb_image_write.c stb_image_resize.c
lib -nologo stb_image.obj -out:..\lib\stb_image.lib
lib -nologo stb_image_write.obj -out:..\lib\stb_image_write.lib
lib -nologo stb_image_resize.obj -out:..\lib\stb_image_resize.lib

del *.obj
