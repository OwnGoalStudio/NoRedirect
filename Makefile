export PACKAGE_VERSION := 2.1

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TARGET := simulator:clang:latest:14.0
ARCHS := arm64 x86_64
IPHONE_SIMULATOR_ROOT := $(shell devkit/sim-root.sh)
else
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := SpringBoard SafariViewService
ARCHS := arm64 arm64e
endif

GO_EASY_ON_ME := 1

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += NoRedirectPrefs

include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME := NoRedirect

NoRedirect_USE_MODULES := 0

NoRedirect_FILES += NoRedirect.xm
NoRedirect_FILES += NoRedirectRecord.m

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
NoRedirect_FILES += libroot/dyn.c
else
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirect_FILES += libroot/dyn.c
endif
endif

NoRedirect_CFLAGS += -fobjc-arc
NoRedirect_CFLAGS += -IHeaders

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirect_LDFLAGS += -LLibraries/_roothide
else
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
NoRedirect_LDFLAGS += -LLibraries/_rootless
else
NoRedirect_LDFLAGS += -LLibraries
endif
endif

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
NoRedirect_CFLAGS += -DIPHONE_SIMULATOR_ROOT=\"$(IPHONE_SIMULATOR_ROOT)\"
NoRedirect_CFLAGS += -FFrameworks/_simulator
NoRedirect_LDFLAGS += -FFrameworks/_simulator
NoRedirect_LDFLAGS += -rpath /opt/simject
else
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
NoRedirect_CFLAGS += -FFrameworks/_rootless
NoRedirect_LDFLAGS += -FFrameworks/_rootless
else
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirect_CFLAGS += -FFrameworks/_roothide
NoRedirect_LDFLAGS += -FFrameworks/_roothide
NoRedirect_LIBRARIES += roothide
else
NoRedirect_CFLAGS += -FFrameworks
NoRedirect_LDFLAGS += -FFrameworks
endif
endif
endif

ifeq ($(THEOS_DEVICE_SIMULATOR),)
NoRedirect_LIBRARIES += sandy
endif

NoRedirect_LIBRARIES += sqlite3
NoRedirect_FRAMEWORKS += CoreServices
NoRedirect_FRAMEWORKS += QuartzCore
NoRedirect_PRIVATE_FRAMEWORKS += AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

TOOL_NAME := NoRedirectUI

NoRedirectUI_USE_MODULES := 0

NoRedirectUI_FILES += NoRedirectUI.mm

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
NoRedirectUI_FILES += libroot/dyn.c
else
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirectUI_FILES += libroot/dyn.c
endif
endif

NoRedirectUI_CFLAGS += -fobjc-arc
NoRedirectUI_CFLAGS += -IHeaders

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
NoRedirectUI_CFLAGS += -DIPHONE_SIMULATOR_ROOT=\"$(IPHONE_SIMULATOR_ROOT)\"
NoRedirectUI_CFLAGS += -FFrameworks/_simulator
NoRedirectUI_LDFLAGS += -FFrameworks/_simulator
NoRedirectUI_LDFLAGS += -rpath /opt/simject
else
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
NoRedirectUI_CFLAGS += -FFrameworks/_rootless
NoRedirectUI_LDFLAGS += -FFrameworks/_rootless
else
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirectUI_CFLAGS += -FFrameworks/_roothide
NoRedirectUI_LDFLAGS += -FFrameworks/_roothide
NoRedirectUI_LIBRARIES += roothide
else
NoRedirectUI_CFLAGS += -FFrameworks
NoRedirectUI_LDFLAGS += -FFrameworks
endif
endif
endif

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
NoRedirectUI_CODESIGN_FLAGS += -f -s - --entitlements Empty.xml
else
NoRedirectUI_CODESIGN_FLAGS += -SNoRedirectUI.xml
endif
NoRedirectUI_INSTALL_PATH := /usr/libexec
NoRedirectUI_FRAMEWORKS += UIKit
NoRedirectUI_PRIVATE_FRAMEWORKS += AppSupport

include $(THEOS_MAKE_PATH)/tool.mk

export THEOS_PACKAGE_SCHEME
export THEOS_STAGING_DIR
before-package::
	@devkit/before-package.sh

export THEOS_OBJ_DIR
after-all::
	@devkit/sim-install.sh
