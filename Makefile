PRODUCTS    := build/Build/Products/Release
APP         := $(PRODUCTS)/MDVisualizer.app
MACOS       := $(APP)/Contents/MacOS
RES         := $(APP)/Contents/Resources
INSTALL_DIR := /Applications

.PHONY: app install clean

app:
	xcodebuild \
	  -scheme MDVisualizer \
	  -configuration Release \
	  -derivedDataPath build \
	  -destination "platform=macOS,arch=arm64" \
	  CODE_SIGN_IDENTITY="" \
	  CODE_SIGNING_REQUIRED=NO \
	  CODE_SIGNING_ALLOWED=NO \
	  build
	# Assemble .app bundle
	mkdir -p $(MACOS) $(RES)
	cp $(PRODUCTS)/MDVisualizer $(MACOS)/MDVisualizer
	cp Sources/MDVisualizer/Info.plist $(APP)/Contents/Info.plist
	cp -R $(PRODUCTS)/MDVisualizer_MDVisualizer.bundle $(RES)/
	codesign --deep --force --sign - $(APP)
	@echo "App at $(APP)"

install: app
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/MDVisualizer.app
	cp -R $(APP) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/MDVisualizer.app"

clean:
	rm -rf build .build
