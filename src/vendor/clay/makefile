# config ?= debug
config ?= release

CC := clang
CFLAGS := -c
DEBUG_FLAGS := -DDEBUG -g
RELEASE_FLAGS := -DNDEBUG -O3

ifeq ($(config), debug)
	CFLAGS += $(DEBUG_FLAGS)
else
	CFLAGS += $(RELEASE_FLAGS)
endif

all: build

.PHONY: build
build:
	$(CC) clay.c $(CFLAGS)
	ar rcs lib/linux/libClay.a clay.o
	rm clay.o
