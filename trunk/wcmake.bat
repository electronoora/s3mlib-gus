tasm /m2 /ml s3mlib.asm
wcc386 wctest.c
wlink system pmodew file wctest file s3mlib
:pmwlite /c4 wctest.exe
