.DEFAULT_GOAL := build

INSTALL_DIR ?= /Applications

.PHONY: build install restart test

build:
	./scripts/build.sh

install: build
	mkdir -p "$(INSTALL_DIR)"
	ditto "build/Keypress.app" "$(INSTALL_DIR)/Keypress.app"
	codesign --verify --deep --strict "$(INSTALL_DIR)/Keypress.app"
	@printf 'Installed %s/Keypress.app\n' "$(INSTALL_DIR)"

test:
	./scripts/swift.sh test

# Explicitly requested restarts clear the in-memory session; install never restarts it.
restart:
	test -d "$(INSTALL_DIR)/Keypress.app"
	/usr/bin/osascript -e 'if application id "local.keypress.app" is running then tell application id "local.keypress.app" to quit'
	/usr/bin/open "$(INSTALL_DIR)/Keypress.app"
