ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TARGET := simulator:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Preferences
ARCHS := arm64 x86_64
else
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Preferences
ARCHS := arm64 arm64e
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := NoRedirectPrefs

NoRedirectPrefs_FILES += NoRedirectRootListController.m
NoRedirectPrefs_FILES += NoRedirectAppListController.m
NoRedirectPrefs_FILES += NoRedirectAppSpecificViewController.m
NoRedirectPrefs_FILES += NoRedirectAppSelectionViewController.m
NoRedirectPrefs_FILES += NoRedirectHistoryViewController.m
NoRedirectPrefs_FILES += LSApplicationProxy+NoRedirect.m
NoRedirectPrefs_FILES += ../NoRedirectRecord.m

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirectPrefs_FILES += ../libroot/dyn.c
endif

NoRedirectPrefs_CFLAGS += -fobjc-arc
NoRedirectPrefs_CFLAGS += -I..

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
NoRedirectPrefs_CFLAGS += -FFrameworks/_simulator
NoRedirectPrefs_LDFLAGS += -FFrameworks/_simulator
NoRedirectPrefs_LDFLAGS += -rpath /opt/simject
else
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
NoRedirectPrefs_CFLAGS += -FFrameworks/_rootless
NoRedirectPrefs_LDFLAGS += -FFrameworks/_rootless
else
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
NoRedirectPrefs_CFLAGS += -FFrameworks/_roothide
NoRedirectPrefs_LDFLAGS += -FFrameworks/_roothide
else
NoRedirectPrefs_CFLAGS += -FFrameworks
NoRedirectPrefs_LDFLAGS += -FFrameworks
endif
endif
endif

NoRedirectPrefs_FRAMEWORKS += UIKit
NoRedirectPrefs_EXTRA_FRAMEWORKS += AltList
NoRedirectPrefs_PRIVATE_FRAMEWORKS += CoreServices
NoRedirectPrefs_PRIVATE_FRAMEWORKS += Preferences
NoRedirectPrefs_INSTALL_PATH += /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk