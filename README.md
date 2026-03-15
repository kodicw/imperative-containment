# Imperative Containment

A NixOS Flake configuration for managing "imperative" virtual machines (VMs) using declarative Nix definitions via [NixVirt](https://github.com/AshleyYakeley/NixVirt).

This project fills the gap between "pure declarative" microVMs (which can't easily run Windows games) and "pure imperative" manual setups (virt-manager). It gives you **Declarative Hardware** (RAM, CPU, PCI Passthrough, TPM) with **Imperative State** (the disk image).

## Features

- **Batteries Included:** Automatically handles Libvirt, QEMU, and NixVirt dependencies. No complex `specialArgs` wiring required.
- **Interactive ISO Downloader:** Built-in tool to easily fetch Windows/Linux ISOs (`nix run .#fetch-iso`).
- **Production Ready:** Handles systemd credential issues, race conditions, and automatic restart on crash (BSOD/Kernel Panic).
- **Windows Optimized:** Pre-configured Hyper-V enlightenments, TPM 2.0 support, and virtio drivers.
- **Hardware Passthrough:** Easy PCI passthrough and CPU pinning configuration.

## Quick Start

### 1. Get Installation Media
Don't have a Windows ISO? We've got you covered.

```bash
# Search, download, and clean up ISOs interactively
nix run github:kodicw/imperative-containment#fetch-iso
```
*Follow the prompts to download your desired OS (e.g., "windows 11", "ubuntu 22.04").*

### 2. Add to Your Flake
Add `imperative-containment` to your `flake.nix`. You **do not** need to manually import `NixVirt`; we handle that for you.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    imperative-containment.url = "github:kodicw/imperative-containment";
  };

  outputs = { self, nixpkgs, imperative-containment, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the module directly
        imperative-containment.nixosModules.default
        
        # Your host configuration
        ./configuration.nix
      ];
    };
  };
}
```

### 3. Configure Your VM
In your `configuration.nix`:

```nix
{ pkgs, ... }: {
  services.imperativeContainment = {
    # Windows Gaming VM
    "gaming-vm" = {
      enable = true;
      osType = "windows";
      
      # Resources
      cores = 6;
      memoryMiB = 16384;
      
      # Storage
      createDiskIfMissing = true;
      diskSize = "100G";
      # Point this to the ISO you downloaded in Step 1
      isoPath = "/var/lib/vms/windows-11.iso";
      
      # Graphics
      graphics = "spice"; # or "none" for GPU passthrough
      
      # TPM 2.0 (Required for Windows 11)
      enableTPM = true;
    };
  };
}
```

## Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the VM |
| `osType` | enum | `"linux"` | OS type (`linux`, `windows`) |
| `cores` | int | `4` | Number of vCPUs |
| `memoryMiB` | int | `8192` | Memory in MiB |
| `diskPath` | path | null | Path to disk image (imperative state) |
| `isoPath` | path | null | Path to ISO for installation |
| `createDiskIfMissing` | bool | `false` | Auto-create qcow2 disk if missing |
| `diskSize` | str | `"60G"` | Size for auto-created disk |
| `restartOnCrash` | bool | `true` | Auto-restart VM on crash/BSOD |
| `enableTPM` | bool | `false` | Enable vTPM 2.0 (needed for Win11) |
| `pciPassthrough` | list | `[]` | List of PCI addresses (e.g. `["01:00.0"]`) |
| `graphics` | enum | `"console"` | Display: `spice`, `vnc`, `console`, `none` |
| `networkType` | enum | `"bridge"` | `bridge` (LAN IP) or `user` (NAT) |

## Testing

Run the integration test suite (boots VMs in a nested QEMU environment):

```bash
nix flake check
```
