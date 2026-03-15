{
  pkgs,
  NixVirt,
  self,
}:

let
  # Create a dummy ISO for testing so we don't need a real 5GB Windows ISO in the store
  windowsIsoPkg = pkgs.runCommand "windows-iso" { } ''
    mkdir -p $out
    echo "dummy iso content" > $out/SERVER_EVAL_x64FRE_en-us.iso
  '';
in
pkgs.testers.runNixOSTest {
  name = "windows-vm-boot-test";
  node.specialArgs = { inherit NixVirt; };
  nodes = {
    host =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [
          NixVirt.nixosModules.default
          self.nixosModules.default
        ];

        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };
        system.stateVersion = "24.05";

        virtualisation.memorySize = 3072;
        virtualisation.cores = 2;
        virtualisation.libvirt.enable = true;
        virtualisation.libvirtd.enable = true;

        # Add ISO to system packages so it's in the VM's nix store
        environment.systemPackages = [ windowsIsoPkg ];

        services.imperativeContainment = {
          windows-vm = {
            enable = true;
            memoryMiB = 1024;
            cores = 2;
            pinOffset = 0;
            osType = "windows";
            networkType = "user";
            graphics = "none";
            enableTPM = false;
            createDiskIfMissing = true;
            diskSize = "10G";
            isoPath = "${windowsIsoPkg}/SERVER_EVAL_x64FRE_en-us.iso";
            copyIsoFromStore = true;
          };
        };
      };
  };

  testScript = ''
    import time

    start_all()

    host.wait_for_unit("multi-user.target")
    host.wait_for_unit("libvirtd.service")

    # Debug: Check nix store for ISO
    print("Checking nix store for Windows ISO...")
    result = host.succeed("ls -la /nix/store/*SERVER_EVAL* 2>/dev/null || echo 'Not found in store'")
    print(f"Nix store content: {result}")

    # Debug: Check tmpfiles config
    print("Checking tmpfiles rules...")
    result = host.succeed("cat /etc/tmpfiles.d/*imperative* 2>/dev/null || echo 'No tmpfiles'")
    print(f"Tmpfiles: {result}")

    # Check VM state - NixVirt may auto-start it
    result = host.succeed("virsh --connect qemu:///system domstate windows-vm 2>/dev/null || echo 'not defined'")
    print(f"Initial VM state: {result}")

    # If not running, start it
    if "running" not in result and "not defined" not in result:
        host.succeed("virsh --connect qemu:///system start windows-vm")

    # Wait for VM to be running
    result = host.succeed("virsh --connect qemu:///system domstate windows-vm")
    print(f"VM state: {result}")

    # Verify it's running
    assert "running" in result, f"Expected VM to be running, got: {result}"

    # Shutdown the VM gracefully
    host.succeed("virsh --connect qemu:///system shutdown windows-vm")

    # Wait for it to stop
    time.sleep(5)
    result = host.succeed("virsh --connect qemu:///system domstate windows-vm || true")
    print(f"VM state after shutdown: {result}")

    print("Windows VM boot test passed!")
  '';
}
