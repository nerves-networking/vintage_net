# Makefile for building port binaries
#
# Makefile targets:
#
# all/install   build and install the NIF
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_COMPILE_PATH path to the build's ebin directory
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries

ifeq ($(MIX_COMPILE_PATH),)
call_from_make:
	mix compile
endif

PREFIX = $(MIX_COMPILE_PATH)/../priv
BUILD  = $(MIX_COMPILE_PATH)/../obj

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning vintage_net only works on Linux, but crosscompilation)
        $(warning is supported by defining $$CROSSCOMPILE, $$ERL_EI_INCLUDE_DIR,)
        $(warning and $$ERL_EI_LIBDIR. See Makefile for details. If using Nerves,)
        $(warning this should be done automatically.)
        $(warning .)
        $(warning Skipping C compilation unless targets explicitly passed to make.)
	#DEFAULT_TARGETS = $(PREFIX)
    endif
endif
DEFAULT_TARGETS ?= $(PREFIX) $(PREFIX)/to_elixir $(PREFIX)/udhcpc_handler

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS = -L$(ERL_EI_LIBDIR) -lei_st

CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic
CC ?= $(CROSSCOMPILE)-gcc

# Enable for debug messages
# CFLAGS += -DDEBUG

CFLAGS += -std=gnu99

all: install

install: $(BUILD) $(PREFIX) $(DEFAULT_TARGETS)

$(BUILD)/%.o: src/%.c
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(PREFIX)/to_elixir: $(BUILD)/to_elixir.o
	$(CC) $^ $(ERL_LDFLAGS) $(LDFLAGS) -o $@

$(PREFIX)/udhcpc_handler: $(BUILD)/udhcpc_handler.o
	$(CC) $^ $(ERL_LDFLAGS) $(LDFLAGS) -o $@

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) $(PREFIX)/to_elixir $(PREFIX)/udhcpc_handler $(BUILD)/*.o

.PHONY: all clean calling_from_make install
