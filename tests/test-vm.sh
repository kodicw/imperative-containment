#!/usr/bin/env bash
set -e

# Setup test environment
echo "Setting up test environment..."

# 1. Download Alpine ISO using quickget
if [ ! -f "alpine-3.18.conf" ]; then
    echo "Downloading Alpine 3.18 ISO..."
    quickget alpine 3.18
fi

# 2. Create qcow2 disk
if [ ! -f "test-vm.qcow2" ]; then
    echo "Creating test-vm.qcow2..."
    qemu-img create -f qcow2 test-vm.qcow2 1G
fi

# 2.5 Copy modules into tests/ directory for flake context
if [ ! -d "modules" ]; then
    echo "Copying modules into test directory..."
    cp -r ../modules .
    # Ensure we clean up later
    trap "rm -rf modules result" EXIT
fi

# 3. Verify VM configuration using Nix
echo "Verifying VM configuration..."

# Build the XML definition exposed as a package in flake.nix
nix build --impure .#test-vm-xml

if [ ! -L result ]; then
    echo "Error: nix build failed to produce 'result' symlink."
    exit 1
fi

XML=$(cat result)

if [ -z "$XML" ]; then
    echo "Error: Empty XML content."
    exit 1
fi

echo "Generated XML snippet:"
echo "${XML:0:200}..." 

# 4. Assertions
echo "Running assertions..."

# Check memory
if grep -q "<memory unit='MiB'>1024</memory>" result; then
    echo "PASS: Memory is 1024 MiB"
else
    echo "FAIL: Memory is not 1024 MiB. Found:"
    grep "memory" result || echo "No memory tag found"
    exit 1
fi

# Check vcpu
if grep -q "<vcpu placement='static'>2</vcpu>" result; then
    echo "PASS: vcpu is 2"
else
    echo "FAIL: vcpu is not 2. Found:"
    grep "vcpu" result || echo "No vcpu tag found"
    exit 1
fi

# Check disk path (it should match what we set in flake.nix, which was /tmp/test-vm.qcow2)
if grep -q "source file='/tmp/test-vm.qcow2'" result; then
    echo "PASS: Disk path is correct"
else
    echo "FAIL: Disk path is incorrect. Found:"
    grep "source file=" result || echo "No source file tag found"
    exit 1
fi

echo "All tests passed!"
