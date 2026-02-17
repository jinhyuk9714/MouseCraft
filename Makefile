SHELL := /bin/bash

APP_NAME := MouseCraft

BUNDLE_ID := com.yourname.MouseCraft
APP_PATH := .build/Build/Products/Debug/$(APP_NAME).app

.PHONY: gen build test clean run

gen:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	xcodegen generate

SIGN_FLAGS := CODE_SIGN_IDENTITY=A1130C672CB7B0B91393C9708579908452CE221E CODE_SIGN_STYLE=Manual

build:
	@xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath .build $(SIGN_FLAGS) build

test:
	@xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath .build $(SIGN_FLAGS) test

run: build
	@echo "Resetting Accessibility permission for $(BUNDLE_ID)…"
	@tccutil reset Accessibility $(BUNDLE_ID) 2>/dev/null || true
	@echo "Launching $(APP_NAME)…"
	@open $(APP_PATH)

clean:
	rm -rf .build $(APP_NAME).xcodeproj
