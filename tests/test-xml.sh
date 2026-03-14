#!/usr/bin/env bash
set -e

echo "=== Imperative Containment XML Test Suite ==="
echo ""

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TEST_DIR"

echo "1. Building Linux VM XML..."
nix build .#linux-vm-xml --impure -L
LINUX_XML=$(cat result)
echo "   PASS: Linux VM XML generated"
rm -f result

echo "2. Building Windows VM XML..."
nix build .#windows-vm-xml --impure -L
WINDOWS_XML=$(cat result)
echo "   PASS: Windows VM XML generated"
rm -f result

echo "3. Building PCI VM XML..."
nix build .#pci-vm-xml --impure -L
PCI_XML=$(cat result)
echo "   PASS: PCI VM XML generated"
rm -f result

echo ""
echo "=== Running Assertions ==="

echo "4. Checking Linux VM memory (2048 MiB)..."
if echo "$LINUX_XML" | grep -q "<memory unit='MiB'>2048</memory>"; then
    echo "   PASS: Linux VM memory is 2048 MiB"
else
    echo "   FAIL: Linux VM memory mismatch"
    exit 1
fi

echo "5. Checking Linux VM vCPUs (2)..."
if echo "$LINUX_XML" | grep -q "<vcpu placement='static'>2</vcpu>"; then
    echo "   PASS: Linux VM vCPUs is 2"
else
    echo "   FAIL: Linux VM vCPUs mismatch"
    exit 1
fi

echo "6. Checking Linux VM CPU pinning..."
if echo "$LINUX_XML" | grep -q "<vcpupin vcpu='0' cpuset='0'/>" && \
   echo "$LINUX_XML" | grep -q "<vcpupin vcpu='1' cpuset='1'/>"; then
    echo "   PASS: Linux VM CPU pinning correct"
else
    echo "   FAIL: Linux VM CPU pinning mismatch"
    exit 1
fi

echo "7. Checking Windows VM memory (4096 MiB)..."
if echo "$WINDOWS_XML" | grep -q "<memory unit='MiB'>4096</memory>"; then
    echo "   PASS: Windows VM memory is 4096 MiB"
else
    echo "   FAIL: Windows VM memory mismatch"
    exit 1
fi

echo "8. Checking Windows VM Hyper-V features..."
if echo "$WINDOWS_XML" | grep -q "<hyperv>" && \
   echo "$WINDOWS_XML" | grep -q "<relaxed state='on'/>"; then
    echo "   PASS: Windows VM Hyper-V features present"
else
    echo "   FAIL: Windows VM Hyper-V features missing"
    exit 1
fi

echo "9. Checking Windows VM TPM..."
if echo "$WINDOWS_XML" | grep -q "<tpm model='tpm-crb'>"; then
    echo "   PASS: Windows VM TPM present"
else
    echo "   FAIL: Windows VM TPM missing"
    exit 1
fi

echo "10. Checking Windows VM VirtIO ISO..."
if echo "$WINDOWS_XML" | grep -q "virtio-win.iso"; then
    echo "   PASS: Windows VM VirtIO ISO present"
else
    echo "   FAIL: Windows VM VirtIO ISO missing"
    exit 1
fi

echo "11. Checking PCI VM memory (8192 MiB)..."
if echo "$PCI_XML" | grep -q "<memory unit='MiB'>8192</memory>"; then
    echo "   PASS: PCI VM memory is 8192 MiB"
else
    echo "   FAIL: PCI VM memory mismatch"
    exit 1
fi

echo "12. Checking PCI VM hostdev devices..."
if echo "$PCI_XML" | grep -q "<hostdev mode='subsystem' type='pci' managed='yes'>"; then
    echo "   PASS: PCI VM hostdev present"
else
    echo "   FAIL: PCI VM hostdev missing"
    exit 1
fi

echo "13. Checking PCI VM PCI addresses (bus=1, slot=0, function=0/1)..."
if echo "$PCI_XML" | grep -q "bus='1' slot='0' function='0'" && \
   echo "$PCI_XML" | grep -q "bus='1' slot='0' function='1'"; then
    echo "   PASS: PCI VM PCI addresses correct"
else
    echo "   FAIL: PCI VM PCI addresses mismatch"
    exit 1
fi

echo "14. Checking PCI VM CPU pinning (offset=8)..."
if echo "$PCI_XML" | grep -q "<vcpupin vcpu='0' cpuset='8'/>" && \
   echo "$PCI_XML" | grep -q "<vcpupin vcpu='3' cpuset='11'/>"; then
    echo "   PASS: PCI VM CPU pinning correct (offset 8)"
else
    echo "   FAIL: PCI VM CPU pinning mismatch"
    exit 1
fi

echo ""
echo "=== All Tests Passed! ==="
