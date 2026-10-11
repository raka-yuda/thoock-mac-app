DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
PROJECT := thoock-mac-app.xcodeproj
SCHEME := thoock-mac-app
DERIVED_DATA := /tmp/thoock-derived
APP := $(DERIVED_DATA)/Build/Products/Debug/thoock-mac-app.app
SWIFT_CACHE := /tmp/thoock-swift-module-cache

.PHONY: build smoke verify run

build:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild -quiet \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-sdk macosx \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO build

smoke:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun swiftc \
		-module-cache-path "$(SWIFT_CACHE)" \
		thoock-mac-app/DomainModels.swift \
		thoock-mac-app/Persistence.swift \
		thoock-mac-app/ProviderLogs.swift \
		thoock-mac-app/DemoData.swift \
		thoock-mac-app/AssetPipeline.swift \
		Tests/SmokeTest/main.swift \
		-o /tmp/thoock-smoke-test
	/tmp/thoock-smoke-test

verify: build smoke

run: build
	open "$(APP)"
