APP_NAME := OpenIn
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' OpenIn/Info.plist)
ARCH := $(shell uname -m)
SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
TARGET := $(ARCH)-apple-macosx12.0
MODULE_CACHE := /private/tmp/OpenInModuleCache

BUILD_DIR := build/manual
APP := $(BUILD_DIR)/Release/$(APP_NAME).app
EXTENSION := $(APP)/Contents/PlugIns/FinderSyncExtension.appex
PACKAGE := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).app.zip
INSTALL_DIR ?= /Applications
INSTALL_APP := $(INSTALL_DIR)/$(APP_NAME).app

SWIFTC_FLAGS := -module-cache-path "$(MODULE_CACHE)" -sdk "$(SDK_PATH)" -target "$(TARGET)"

.PHONY: build sign check package install clean

build:
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources" "$(EXTENSION)/Contents/MacOS" "$(EXTENSION)/Contents/Resources"
	swiftc $(SWIFTC_FLAGS) -framework Cocoa Shared/MenuItemConfig.swift OpenIn/main.swift OpenIn/SettingsView.swift -o "$(APP)/Contents/MacOS/OpenIn"
	swiftc $(SWIFTC_FLAGS) -application-extension -parse-as-library -module-name FinderSyncExtension FinderSyncExtension/FinderSync.swift Shared/MenuItemConfig.swift -framework Cocoa -framework FinderSync -emit-executable -Xlinker -e -Xlinker _NSExtensionMain -o "$(EXTENSION)/Contents/MacOS/FinderSyncExtension"
	cp OpenIn/Info.plist "$(APP)/Contents/Info.plist"
	cp FinderSyncExtension/Info.plist "$(EXTENSION)/Contents/Info.plist"
	cp OpenIn/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png "$(APP)/Contents/Resources/icon_1024x1024.png"
	cp OpenIn/Assets.xcassets/AppIcon.appiconset/icon_512x512.png "$(APP)/Contents/Resources/icon_512x512.png"
	cp FinderSyncExtension/Assets.xcassets/ToolbarIcon.imageset/toolbar_icon_16.png "$(EXTENSION)/Contents/Resources/toolbar_icon_16.png"
	cp FinderSyncExtension/Assets.xcassets/ToolbarIcon.imageset/toolbar_icon_32.png "$(EXTENSION)/Contents/Resources/ToolbarIcon.png"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable OpenIn' "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.local.OpenIn' "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleName OpenIn' "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundlePackageType APPL' "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 12.0' "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable FinderSyncExtension' "$(EXTENSION)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.local.OpenIn.FinderSync' "$(EXTENSION)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleName FinderSyncExtension' "$(EXTENSION)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :NSExtension:NSExtensionPrincipalClass FinderSyncExtension.FinderSync' "$(EXTENSION)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :NSExtension:NSExtensionPointIdentifier com.apple.FinderSync' "$(EXTENSION)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :NSExtension:NSExtensionFilesystemDocumentGroups:0 /' "$(EXTENSION)/Contents/Info.plist"

sign: build
	codesign --force --sign - --entitlements FinderSyncExtension/FinderSyncExtension.entitlements "$(EXTENSION)"
	codesign --force --sign - --entitlements OpenIn/OpenIn.entitlements "$(APP)"
	codesign --verify --deep --strict --verbose=1 "$(APP)"

check: sign
	git diff --check

package: sign
	rm -f "$(PACKAGE)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(PACKAGE)"
	unzip -tq "$(PACKAGE)"
	@echo "Created $(PACKAGE)"

install: sign
	ditto "$(APP)" "$(INSTALL_APP)"
	codesign --force --sign - --entitlements "$(CURDIR)/FinderSyncExtension/FinderSyncExtension.entitlements" "$(INSTALL_APP)/Contents/PlugIns/FinderSyncExtension.appex"
	codesign --force --sign - --entitlements "$(CURDIR)/OpenIn/OpenIn.entitlements" "$(INSTALL_APP)"
	/usr/bin/pluginkit -a "$(INSTALL_APP)/Contents/PlugIns/FinderSyncExtension.appex"
	/usr/bin/pluginkit -e use -i com.local.OpenIn.FinderSync
	killall Finder || true
	killall OpenIn || true
	open -n "$(INSTALL_APP)"

clean:
	rm -rf "$(BUILD_DIR)"
