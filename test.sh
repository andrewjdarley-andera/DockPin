#!/bin/bash
# Runs the geometry checks in Tests/main.swift.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc Sources/Geometry.swift Tests/main.swift -o build/tests
build/tests
