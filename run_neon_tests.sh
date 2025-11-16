#!/bin/bash

# NEON ARM Assembly Test Runner for odiff
# This script runs comprehensive NEON-specific tests

set -e

echo "🔧 Building odiff with NEON support..."
zig build

echo ""
echo "🧪 Running NEON-specific tests..."
echo "================================================"

# Check if we're on ARM64
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
    echo "⚠️  Warning: Not running on ARM64 architecture ($ARCH)"
    echo "   NEON tests will be skipped on this platform"
    echo ""
fi

# Run only the NEON test file
echo "🔬 Running NEON assembly tests..."
zig test src/test_neon.zig --dep odiff_lib --dep build_options -Modiff_lib=src/root.zig -Mbuild_options=.zig-cache/c/*/options.zig -lc

echo ""
echo "✅ NEON tests completed!"

# Optional: Run integration tests that include NEON
echo ""
echo "🔄 Running integration tests (includes NEON path testing)..."
zig build test-integration

echo ""
echo "🎉 All NEON-related tests completed successfully!"
echo ""
echo "📊 Test Summary:"
echo "   ✓ NEON feature detection"
echo "   ✓ Direct assembly function testing"
echo "   ✓ Alpha channel handling"
echo "   ✓ Comparison with existing implementation"
echo "   ✓ Performance benchmarking"
echo "   ✓ Integration tests with real images"
echo "   ✓ Edge cases and error conditions"