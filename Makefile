API ?= 35
PROJECT ?= iQOO-13
OUTDIR ?= build/$(PROJECT)/bin
EMBEDDIR ?= build/embed

TARGET_DIR := .
TARGET_HEADER := target.h

ifeq ($(wildcard $(TARGET_HEADER)),)
$(error unknown PROJECT=$(PROJECT), missing $(TARGET_HEADER))
endif

define pick_src
$(1)
endef

EMBED_SU := $(EMBEDDIR)/su_daemon_aarch64_pie
PRELOAD := $(OUTDIR)/preload.so

CORE_SRCS := \
  $(call pick_src,main.c) \
  $(call pick_src,util.c) \
  $(call pick_src,slide.c) \
  $(call pick_src,fops.c) \
  $(call pick_src,pipe.c) \
  $(call pick_src,root.c)
PRELOAD_SRCS := $(CORE_SRCS) preload.c su_blob.S

.DEFAULT_GOAL := preload

DEFAULT_NDK_ROOT := $(HOME)/android-ndk-cache/android-ndk-r29
NDK_ROOT ?= $(or $(ANDROID_NDK_HOME),$(ANDROID_NDK_ROOT),$(wildcard $(DEFAULT_NDK_ROOT)))
NDK_TOOLCHAIN ?= $(if $(NDK_ROOT),$(NDK_ROOT)/toolchains/llvm/prebuilt/linux-x86_64)
NDK_CC := $(NDK_TOOLCHAIN)/bin/aarch64-linux-android$(API)-clang
HOST_CLANG ?= clang
SYSROOT ?= $(if $(NDK_TOOLCHAIN),$(NDK_TOOLCHAIN)/sysroot)
RESOURCE_DIR ?= $(if $(NDK_TOOLCHAIN),$(NDK_TOOLCHAIN)/lib/clang/21)

HOST_TARGET_FLAGS := \
  --target=aarch64-linux-android$(API) \
  --sysroot=$(SYSROOT) \
  -resource-dir $(RESOURCE_DIR) \
  --rtlib=compiler-rt \
  --unwindlib=none
HOST_COMMON_LDFLAGS := \
  -fuse-ld=lld \
  -Wl,-rpath-link,$(SYSROOT)/usr/lib/aarch64-linux-android/$(API) \
  -L$(SYSROOT)/usr/lib/aarch64-linux-android/$(API) \
  -L$(SYSROOT)/usr/lib/aarch64-linux-android
HOST_PIE_LDFLAGS := \
  $(HOST_COMMON_LDFLAGS) \
  -Wl,-dynamic-linker,/system/bin/linker64

ifneq ($(origin CC),default)
  TARGET_CC := $(CC)
  TARGET_FLAGS :=
  TARGET_COMMON_LDFLAGS :=
  TARGET_PIE_LDFLAGS :=
else ifneq ($(wildcard $(NDK_CC)),)
  NDK_CC_WORKS := $(shell $(NDK_CC) --version >/dev/null 2>&1 && echo yes)
  ifeq ($(NDK_CC_WORKS),yes)
    TARGET_CC := $(NDK_CC)
    TARGET_FLAGS :=
    TARGET_COMMON_LDFLAGS :=
    TARGET_PIE_LDFLAGS :=
  else
    TARGET_CC := $(HOST_CLANG)
    TARGET_FLAGS := $(HOST_TARGET_FLAGS)
    TARGET_COMMON_LDFLAGS := $(HOST_COMMON_LDFLAGS)
    TARGET_PIE_LDFLAGS := $(HOST_PIE_LDFLAGS)
  endif
else
  TARGET_CC := $(HOST_CLANG)
  TARGET_FLAGS := $(HOST_TARGET_FLAGS)
  TARGET_COMMON_LDFLAGS := $(HOST_COMMON_LDFLAGS)
  TARGET_PIE_LDFLAGS := $(HOST_PIE_LDFLAGS)
endif

COMMON_CFLAGS := -O2 -g0 -Wall -Wextra -I.
PIE_CFLAGS := -fPIE -pie $(COMMON_CFLAGS)
SO_CFLAGS := -fPIC $(COMMON_CFLAGS)
WARN_CFLAGS := -Wno-unused-parameter -Wno-sign-compare -Wno-unused-function
TARGET_CFLAGS := -DTARGET_CONFIG_H=\"target.h\"

.PHONY: all preload clean info list-projects

all: preload

preload: $(PRELOAD)

$(OUTDIR):
	mkdir -p $@

$(EMBEDDIR):
	mkdir -p $@

$(EMBED_SU): su_daemon.c | $(EMBEDDIR)
	$(TARGET_CC) $(TARGET_FLAGS) $(PIE_CFLAGS) $(TARGET_CFLAGS) \
	  $< $(TARGET_PIE_LDFLAGS) -o $@

$(PRELOAD): $(PRELOAD_SRCS) $(EMBED_SU) $(TARGET_HEADER) offset.h common.h kernelsnitch/*.h | $(OUTDIR)
	$(TARGET_CC) $(TARGET_FLAGS) $(SO_CFLAGS) $(WARN_CFLAGS) $(TARGET_CFLAGS) \
	  $(PRELOAD_SRCS) $(TARGET_COMMON_LDFLAGS) \
	  -shared -o $@ -pthread
	sha256sum $@

info:
	@echo "PROJECT=$(PROJECT)"
	@echo "TARGET_DIR=$(TARGET_DIR)"
	@echo "TARGET_CC=$(TARGET_CC)"
	@echo "TARGET_FLAGS=$(TARGET_FLAGS)"
	@echo "TARGET_COMMON_LDFLAGS=$(TARGET_COMMON_LDFLAGS)"
	@echo "TARGET_PIE_LDFLAGS=$(TARGET_PIE_LDFLAGS)"
	@echo "PRELOAD=$(PRELOAD)"
	@echo "EMBED_SU=$(EMBED_SU)"
	@echo "CORE_SRCS=$(CORE_SRCS)"

list-projects:
	@echo "iQOO-13"

clean:
	rm -rf build
