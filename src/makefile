##
## tinflib  -  tiny inflate library (inflate, gzip, zlib)
##
## GCC makefile (Linux, FreeBSD, BeOS and QNX)
##
## Copyright (c) 2003 by Joergen Ibsen / Jibz
## All Rights Reserved
##
## http://www.ibsensoftware.com/
##

target  = ../lib/libtinf.a
objects = tinflate.o tinfgzip.o tinfzlib.o adler32.o crc32.o \
    defl_static.o genlz77.o

CC = avr-gcc
COPT    = -Os
CFLAGS  = -Wall -Wshift-count-overflow $(COPT) -fomit-frame-pointer
LDFLAGS = $(CFLAGS) -s

.PHONY: all clean

all: $(target)

$(target): $(objects)
	$(RM) $@

%.o : %.c %.S
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	$(RM) $(objects) $(target)
