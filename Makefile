export TARGET = iphone:clang:16.5:14.0
export SDK_PATH = $(THEOS)/sdks/iPhoneOS16.5.sdk/
export SYSROOT = $(SDK_PATH)
export ARCHS = arm64

ifneq ($(JAILBROKEN),1)
export DEBUGFLAG = -ggdb -Wno-unused-command-line-argument -L$(THEOS_OBJ_DIR) -F$(_THEOS_LOCAL_DATA_DIR)/$(THEOS_OBJ_DIR_NAME)/install/Library/Frameworks
# MODULES = jailed
endif

INSTALL_TARGET_PROCESSES = FGame
TWEAK_NAME = FFXIVM-en-patch

# 🔽 Define the bundle details
BUNDLE_NAME = FFXIVMBundle
$(TWEAK_NAME)_BUNDLE = $(BUNDLE_NAME)

# For jailbroken devices, install to system path
ifeq ($(JAILBROKEN),1)
$(BUNDLE_NAME)_INSTALL_PATH = /Library/Application Support/FFXIVM-en-patch
else
# For sideloaded apps, include bundle in the main app bundle
$(TWEAK_NAME)_BUNDLES = $(BUNDLE_NAME)
endif

$(BUNDLE_NAME)_RESOURCE_FILES = Resources/*

$(TWEAK_NAME)_FILES := $(wildcard src/*.xm)
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-module-import-in-extern-c
$(TWEAK_NAME)_FRAMEWORKS = UIKit

include $(THEOS)/makefiles/common.mk

ifneq ($(JAILBROKEN),1)
include $(THEOS_MAKE_PATH)/aggregate.mk
endif
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk