# Imperative Containment

A NixOS Flake configuration for managing "imperative" virtual machines (VMs) using declarative Nix definitions via [NixVirt](https://github.com/AshleyYakeley/NixVirt).

## Concept

**Imperative Containment**: Define the container (VM hardware, resources, passthrough) declaratively while accepting that the internal state (OS disk) is imperative and stateful.

## Features

- Declarative VM configuration with NixVirt
- Auto-creation of disk images at boot
- Copy-on-write disk images from nix store to tmpfs
- PCI passthrough support
- TPM support (for Windows)
- CPU pinning
- Nested VM support

## Usage

```bash
# Build the system
nix build .#nixosConfigurations.demo-host.config.system.build.toplevel

# Rebuild the host
sudo nixos-rebuild switch --flake .#demo-host
```

## Configuration

See `configurations.nix` for example VM configurations.

## Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the VM |
| `osType` | enum | `"linux"` | OS type (`linux`, `windows`) |
| `cores` | int | `4` | Number of vCPUs |
| `memoryMiB` | int | `8192` | Memory in MiB |
| `diskPath` | path | null | Path to disk image |
| `isoPath` | path | null | Path to ISO for installation |
| `createDiskIfMissing` | bool | `false` | Auto-create qcow2 disk |
| `diskSize` | str | `"60G"` | Size for auto-created disk |
| `copyDiskFromStore` | bool | `false` | Copy disk from nix store |
| `copyIsoFromStore` | bool | `false` | Copy ISO from nix store |
| `vmsPath` | path | `/var/lib/vms` | Path for VM files |
| `enableTPM` | bool | `false` | Enable TPM 2.0 |
| `pciPassthrough` | list | `[]` | PCI devices to pass through |
| `networkType` | enum | `"bridge"` | Network type (`bridge`, `user`) |
| `arch` | enum | `"x86_64"` | VM architecture |
| `cpuMode` | enum | `"host-passthrough"` | CPU mode |

## Testing

```bash
# Run flake checks
nix flake check
nix flake check ./tests

# Build VM XML
nix build ./tests#windows-vm-xml
```
