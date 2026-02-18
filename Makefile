SHELL := /bin/bash

APP_NAME := MouseCraft

BUNDLE_ID := com.jinhyuk9714.MouseCraft
APP_PATH := .build/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP_PATH := .build/Build/Products/Release/$(APP_NAME).app
ARCHIVE_PATH := .build/$(APP_NAME).xcarchive
DMG_PATH := .build/$(APP_NAME).dmg

.PHONY: gen build test clean run release archive dmg notarize

gen:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	xcodegen generate

SIGN_FLAGS ?= CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

# Override for release signing (set RELEASE_SIGN_FLAGS to use a Developer ID cert)
RELEASE_SIGN_FLAGS ?= $(SIGN_FLAGS)

build:
	@xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath .build $(SIGN_FLAGS) build

test:
	@xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath .build $(SIGN_FLAGS) test

run: build
	@tccutil reset Accessibility $(BUNDLE_ID) 2>/dev/null || true
	@tccutil reset ListenEvent $(BUNDLE_ID) 2>/dev/null || true
	@echo "Launching $(APP_NAME)…"
	@open $(APP_PATH)

release:
	@echo "Building Release with hardened runtime…"
	@xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release -derivedDataPath .build $(RELEASE_SIGN_FLAGS) build
	@echo "Release build at: $(RELEASE_APP_PATH)"

archive:
	@echo "Creating xcarchive…"
	@xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release -archivePath $(ARCHIVE_PATH) $(RELEASE_SIGN_FLAGS) archive
	@echo "Archive at: $(ARCHIVE_PATH)"

dmg: release
	@echo "Creating DMG…"
	@rm -f $(DMG_PATH)
	@hdiutil create -volname "$(APP_NAME)" -srcfolder $(RELEASE_APP_PATH) \
		-ov -format UDZO $(DMG_PATH)
	@echo "DMG at: $(DMG_PATH)"

# Usage: make notarize TEAM_ID=XXXX NOTARIZE_KEYCHAIN_PROFILE=my-profile
TEAM_ID ?= UNSET
NOTARIZE_KEYCHAIN_PROFILE ?= UNSET
notarize: dmg
	@if [ "$(TEAM_ID)" = "UNSET" ] || [ "$(NOTARIZE_KEYCHAIN_PROFILE)" = "UNSET" ]; then \
		echo "Error: Set TEAM_ID and NOTARIZE_KEYCHAIN_PROFILE"; \
		echo "  make notarize TEAM_ID=XXXXX NOTARIZE_KEYCHAIN_PROFILE=my-profile"; \
		exit 1; \
	fi
	@echo "Submitting DMG to Apple notary service…"
	@xcrun notarytool submit $(DMG_PATH) \
		--keychain-profile "$(NOTARIZE_KEYCHAIN_PROFILE)" \
		--team-id "$(TEAM_ID)" \
		--wait
	@echo "Stapling notarization ticket to DMG…"
	@xcrun stapler staple $(DMG_PATH)
	@echo "Notarization complete. Distribute: $(DMG_PATH)"

clean:
	rm -rf .build $(APP_NAME).xcodeproj
