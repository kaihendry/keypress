#!/bin/bash
# Use the selected Swift toolchain. Isolate a workaround for mixed-version CLT remnants.
set -euo pipefail
cd "$(dirname "$0")/.."
swift_binary="$(xcrun --find swift)"
manifest_api="$(dirname "$swift_binary")/../lib/swift/pm/ManifestAPI"
module_path="$manifest_api/PackageDescription.swiftmodule"
architecture="$(uname -m)"
public_interface="$module_path/$architecture-apple-macos.swiftinterface"
private_interface="$module_path/$architecture-apple-macos.private.swiftinterface"
if [[ -z "${SWIFTPM_CUSTOM_LIBS_DIR:-}" && -f "$public_interface" && -f "$private_interface" ]]; then
    public_version="$(sed -n '2p' "$public_interface")"
    private_version="$(sed -n '2p' "$private_interface")"
    if [[ "$public_version" != "$private_version" ]]; then
        local_libs="$PWD/.build/swiftpm-libs"
        mkdir -p "$local_libs/ManifestAPI/PackageDescription.swiftmodule"
        cp "$manifest_api/libPackageDescription.dylib" "$local_libs/ManifestAPI/"
        cp "$public_interface" "$local_libs/ManifestAPI/PackageDescription.swiftmodule/"
        export SWIFTPM_CUSTOM_LIBS_DIR="$local_libs"
    fi
fi
# Standalone CLT ships the Testing macros outside the default plugin search path.
case "${1:-}" in
    test)
        testing_plugins="$(dirname "$swift_binary")/../lib/swift/host/plugins/testing"
        if [[ -d "$testing_plugins" ]]; then
            exec "$swift_binary" "$@" --disable-xctest -Xswiftc -plugin-path -Xswiftc "$testing_plugins"
        fi
        exec "$swift_binary" "$@" --disable-xctest ;;
    *) exec "$swift_binary" "$@" ;;
esac
