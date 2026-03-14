{
  config,
  lib,
  pkgs,
  NixVirt,
  ...
}:

let
  cfg = config.services.imperativeContainment;

  # Helper: Hex String to Int
  hexToInt =
    str:
    let
      chars = lib.stringToCharacters (lib.toLower str);
      hexMap = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
      step = acc: c: acc * 16 + hexMap.${c};
    in
    lib.foldl' step 0 chars;

  # Helper: Parse MM:SS.F string to PCI struct (integers)
  parsePci = pciStr: {
    bus = hexToInt (builtins.substring 0 2 pciStr);
    slot = hexToInt (builtins.substring 3 2 pciStr);
    function = hexToInt (builtins.substring 6 1 pciStr);
  };

  # Helper: Generate CPU pinning map
  generateCpuPin =
    cores: offset:
    lib.genList (i: {
      vcpu = i;
      cpuset = builtins.toString (i + offset);
    }) cores;

  # Helpers: Generate deterministic UUID and MAC from VM Name to prevent collisions
  nameHash = name: builtins.hashString "md5" name;
  genMac =
    name:
    let
      h = nameHash name;
    in
    "52:54:00:${builtins.substring 0 2 h}:${builtins.substring 2 2 h}:${builtins.substring 4 2 h}";
  genUuid =
    name:
    let
      h = nameHash name;
    in
    "${builtins.substring 0 8 h}-${builtins.substring 8 4 h}-${builtins.substring 12 4 h}-${builtins.substring 16 4 h}-${builtins.substring 20 12 h}";

  # The VM Definition Submodule
  vmSubmodule =
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "Enable Contained Impurity: ${name}";
        osType = lib.mkOption {
          type = lib.types.enum [
            "windows"
            "linux"
          ];
          default = "linux";
        };
        cores = lib.mkOption {
          type = lib.types.int;
          default = 4;
        };
        pinOffset = lib.mkOption {
          type = lib.types.int;
          default = 2;
        };
        memoryMiB = lib.mkOption {
          type = lib.types.int;
          default = 8192;
        };
        pciPassthrough = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        enableTPM = lib.mkEnableOption "vTPM 2.0";
        vmsPath = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/vms";
          description = "Path for VM files (disks, ISOs)";
        };
        diskPath = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
          default = null;
          description = "Path to disk image";
        };
        diskDev = lib.mkOption {
          type = lib.types.str;
          default = "vda";
          description = "Device name for main disk (e.g., vda, sda)";
        };
        diskBus = lib.mkOption {
          type = lib.types.enum [ "virtio" "scsi" "sata" "ide" ];
          default = "virtio";
          description = "Bus type for main disk";
        };
        cdromDev = lib.mkOption {
          type = lib.types.str;
          default = "sdb";
          description = "Device name for CDROM";
        };
        hostBridge = lib.mkOption {
          type = lib.types.str;
          default = "br0";
        };
        networkType = lib.mkOption {
          type = lib.types.enum [ "bridge" "user" ];
          default = "bridge";
          description = "Network type: bridge (requires host bridge) or user (NAT)";
        };
        copyDiskFromStore = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Copy disk image from nix store to tmpfs at boot";
        };
        copyIsoFromStore = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Copy ISO image from nix store to tmpfs at boot";
        };
        isoPath = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to ISO image for installation";
        };
        createDiskIfMissing = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Create qcow2 disk if it doesn't exist";
        };
        diskSize = lib.mkOption {
          type = lib.types.str;
          default = "60G";
          description = "Size for auto-created disk";
        };
        arch = lib.mkOption {
          type = lib.types.enum [ "x86_64" "aarch64" ];
          default = "x86_64";
          description = "VM architecture";
        };
        cpuMode = lib.mkOption {
          type = lib.types.enum [ "host-passthrough" "host-model" "max" ];
          default = "host-passthrough";
          description = "CPU emulation mode";
        };
      };
    };
in
{
  options.services.imperativeContainment = lib.mkOption {
    description = "Attribute set of mutable legacy systems contained via NixVirt.";
    type = lib.types.attrsOf (lib.types.submodule vmSubmodule);
    default = { };
  };

  config = lib.mkIf (cfg != { }) {
    boot.kernelParams =
      (let
        cpuVendor = pkgs.stdenv.hostPlatform.cpu.vendor or "unknown";
      in
        if cpuVendor == "intel" then [ "intel_iommu=on" "iommu=pt" ]
        else if cpuVendor == "amd" then [ "amd_iommu=on" "iommu=pt" ]
        else [ ])
      ++ [ "kvm.ignore_msrs=1" ];
    boot.kernelModules = [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
    ];
    virtualisation.libvirt.enable = true;
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;

    assertions = lib.mapAttrsToList (vmName: vmCfg: {
      assertion = !(vmCfg.diskPath != null && (vmCfg.createDiskIfMissing || vmCfg.copyDiskFromStore));
      message = "diskPath cannot be set when createDiskIfMissing or copyDiskFromStore is true for VM '${vmName}'. The path is auto-computed to \${vmCfg.vmsPath}/\${vmName}.qcow2";
    }) cfg;

    # Generate tmpfiles.d rules for copying disks/ISOs from nix store to tmpfs
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (vmName: vmCfg:
      let
        effectiveDiskPath = if vmCfg.diskPath != null then vmCfg.diskPath else "${vmCfg.vmsPath}/${vmName}.qcow2";
      in
      [ ]
      ++ lib.optionals vmCfg.copyDiskFromStore [
        "d ${vmCfg.vmsPath} 0755 root root -"
        "C+ ${vmCfg.vmsPath}/${vmName}.qcow2 - root root - ${effectiveDiskPath}"
      ]
      ++ lib.optionals (vmCfg.isoPath != null && vmCfg.copyIsoFromStore) [
        "C+ ${vmCfg.vmsPath}/${vmName}.iso - root root - ${vmCfg.isoPath}"
      ]
    ) cfg);

    # Generate systemd services to create disks if missing
    systemd.services = lib.foldl' (acc: vmPair:
      let
        vmName = vmPair.name;
        vmCfg = vmPair.value;
        effectiveDiskPath = if vmCfg.diskPath != null then vmCfg.diskPath else "${vmCfg.vmsPath}/${vmName}.qcow2";
      in
      acc // lib.optionalAttrs vmCfg.createDiskIfMissing {
        "imperative-containment-create-disk-${vmName}" = {
          serviceConfig.Type = "oneshot";
          serviceConfig.RemainAfterExit = true;
          path = [ pkgs.qemu_kvm ];
          script = ''
            if [ ! -f "${effectiveDiskPath}" ]; then
              mkdir -p "$(dirname ${effectiveDiskPath})"
              qemu-img create -f qcow2 "${effectiveDiskPath}" ${vmCfg.diskSize}
            fi
          '';
          wantedBy = [ "multi-user.target" ];
        };
      }
    ) { } (lib.mapAttrsToList (n: v: { name = n; value = v; }) cfg);

    virtualisation.libvirt.connections."qemu:///system".domains = lib.mapAttrsToList (vmName: vmCfg: {
      active = vmCfg.enable;
      definition = NixVirt.lib.domain.writeXML {
        type = "kvm";
        name = vmName;
        uuid = genUuid vmName;
        memory = {
          count = vmCfg.memoryMiB;
          unit = "MiB";
        };
        vcpu = {
          placement = "static";
          count = vmCfg.cores;
        };
        os = {
          type = "hvm";
          arch = vmCfg.arch;
          boot = {
            dev = if vmCfg.isoPath != null then "cdrom" else "hd";
          };
        };
        cpu = {
          mode = vmCfg.cpuMode;
          topology = {
            sockets = 1;
            dies = 1;
            cores = vmCfg.cores;
            threads = 1;
          };
        };
        cputune = {
          vcpupin = generateCpuPin vmCfg.cores vmCfg.pinOffset;
        };

        # Apply Hyper-V only for Windows
        features = {
          acpi = { };
          apic = { };
        }
        // lib.optionalAttrs (vmCfg.osType == "windows") {
          hyperv = {
            relaxed = {
              state = true;
            };
            vapic = {
              state = true;
            };
            spinlocks = {
              state = true;
              retries = 8191;
            };
          };
        };

        devices = {
          emulator = "${pkgs.qemu_kvm}/bin/qemu-system-${vmCfg.arch}";

          tpm = lib.optional vmCfg.enableTPM {
            model = "tpm-crb";
            backend = {
              type = "emulator";
              version = "2.0";
            };
          };

          disk = let
            effectiveDiskPath = if vmCfg.diskPath != null then vmCfg.diskPath else "${vmCfg.vmsPath}/${vmName}.qcow2";
          in [
            {
              type = "file";
              device = "disk";
              driver = {
                name = "qemu";
                type = "qcow2";
              };
              source.file = effectiveDiskPath;
              target = {
                dev = vmCfg.diskDev;
                bus = vmCfg.diskBus;
              };
            }
          ]
          ++ lib.optional (vmCfg.isoPath != null) {
            type = "file";
            device = "cdrom";
            source.file = if vmCfg.copyIsoFromStore 
                         then "${vmCfg.vmsPath}/${vmName}.iso" 
                         else vmCfg.isoPath;
            target = {
              dev = vmCfg.cdromDev;
              bus = "sata";
            };
            readonly = true;
          }
          ++ lib.optional (vmCfg.osType == "windows" && vmCfg.isoPath == null) {
            type = "file";
            device = "cdrom";
            source.file = "${pkgs.virtio-win}/share/virtio-win.iso";
            target = {
              dev = vmCfg.cdromDev;
              bus = "sata";
            };
            readonly = true;
          };

          interface = let
            baseInterface = {
              mac.address = genMac vmName;
            };
          in
            if vmCfg.networkType == "bridge" then [
              (baseInterface // {
                type = "bridge";
                source.bridge = vmCfg.hostBridge;
                model.type = "virtio";
              })
            ] else [
              (baseInterface // {
                type = "user";
              })
            ];

          hostdev = map (
            pciStr:
            let
              pci = parsePci pciStr;
            in
            {
              mode = "subsystem";
              type = "pci";
              managed = true;
              source.address = {
                domain = 0;
                inherit (pci) bus slot function;
              };
            }
          ) vmCfg.pciPassthrough;
        };
      };
    }) cfg;
  };
}
