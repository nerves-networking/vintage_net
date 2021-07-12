# Makefile for building port binaries
#
# Makefile targets:
#
# all/install   build and install the port binary
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries
#
ifeq ($(MIX_APP_PATH),)
calling_from_make:
	mix compile
endif

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS = -L$(ERL_EI_LIBDIR) -lei_st

CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning vintage_net only works on Linux, but crosscompilation)
        $(warning is supported by defining $$CROSSCOMPILE, $$ERL_EI_INCLUDE_DIR,)
        $(warning and $$ERL_EI_LIBDIR. See Makefile for details. If using Nerves,)
        $(warning this should be done automatically.)
        $(warning .)
        $(warning Skipping some C compilation unless targets explicitly passed to make.)
        DEFAULT_TARGETS ?= $(PREFIX)
    endif
endif
DEFAULT_TARGETS ?= $(PREFIX) \
		   $(PREFIX)/if_monitor

# Enable for debug messages
# CFLAGS += -DDEBUG

# Unfortunately, depending on the system we're on, we need
# to specify -std=c99 or -std=gnu99. The later is more correct,
# but it fails to build on many setups.
# NOTE: Need to call sh here since file permissions are not preserved
#       in hex packages.
ifeq ($(shell CC=$(CC) sh src/test-c99.sh),yes)
CFLAGS += -std=c99 -D_XOPEN_SOURCE=600
else
CFLAGS += -std=gnu99
endif

all: install

install: $(BUILD) $(PREFIX) $(DEFAULT_TARGETS)

$(BUILD)/%.o: src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(PREFIX)/if_monitor: $(BUILD)/if_monitor.o
	@echo " LD $(notdir $@)"
	$(CC) $^ $(ERL_LDFLAGS) $(LDFLAGS) -lmnl -o $@

$(PREFIX) $(BUILD):
	mkdir -p $@

mix_clean:
	$(RM) $(PREFIX)/if_monitor \
	    $(BUILD)/*.o
clean:
	mix clean

format:
	astyle \
	    --style=kr \
	    --indent=spaces=4 \
	    --align-pointer=name \
	    --align-reference=name \
	    --convert-tabs \
	    --attach-namespaces \
	    --max-code-length=100 \
	    --max-instatement-indent=120 \
	    --pad-header \
	    --pad-oper \
	    src/*.c

.PHONY: all clean mix_clean calling_from_make install format

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
