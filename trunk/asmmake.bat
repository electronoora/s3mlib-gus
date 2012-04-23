@echo off
c:\devel\tasm\tasm /m2 /ml s3mlib
if not exist music.inc incpro strike.s3m music.inc music
c:\devel\tasm\tasm /m2 /ml asmtest
c:\devel\watcom\binw\wlink system pmodew file { asmtest.obj s3mlib.obj }
:pmwlite /c4 asmtest.exe
