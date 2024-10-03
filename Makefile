export PACKAGE_VERSION := 1.5

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TARGET := simulator:clang:latest:14.0
INSTALL_TARGET_PROCESSES := SpringBoard SafariViewService
ARCHS := arm64 x86_64
else
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := SpringBoard SafariViewService
ARCHS := arm64 arm64e
endif

GO_EASY_ON_ME := 1

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += NoRedirectPrefs

include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME := NoRedirect

NoRedirect_FILES += NoRedirect.xm
NoRedirect_FILES += NoRedirectRecord.m
NoRedirect_CFLAGS += -fobjc-arc
NoRedirect_CFLAGS += -IHeaders
NoRedirect_LDFLAGS += -LLibraries

ifeq ($(THEOS_DEVICE_SIMULATOR),)
NoRedirect_LIBRARIES += sandy
endif

include $(THEOS_MAKE_PATH)/tweak.mk

export THEOS_OBJ_DIR
after-all::
	@devkit/sim-install.sh
