{ pkgs, NixVirt, self }:

pkgs.testers.runNixOSTest {
  name = "linux-vm-boot-test";
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

        virtualisation.memorySize = 2048;
        virtualisation.libvirt.enable = true;
        virtualisation.libvirtd.enable = true;

        services.imperativeContainment = {
          linux-vm = {
            enable = true;
            memoryMiB = 512;
            cores = 1;
            pinOffset = 0;
            osType = "linux";
            networkType = "user";
            graphics = "none";
            createDiskIfMissing = true;
            diskSize = "2G";
          };
        };
      };
  };

  testScript = ''
    import time

    start_all()

    host.wait_for_unit("multi-user.target")
    host.wait_for_unit("libvirtd.service")

    # Check VM state - NixVirt may auto-start it
    result = host.succeed("virsh --connect qemu:///system domstate linux-vm 2>/dev/null || echo 'not defined'")
    print(f"Initial VM state: {result}")

    # If not running, start it
    if "running" not in result and "not defined" not in result:
        host.succeed("virsh --connect qemu:///system start linux-vm")

    # Wait for VM to be running
    result = host.succeed("virsh --connect qemu:///system domstate linux-vm")
    print(f"VM state: {result}")

    # Verify it's running
    assert "running" in result, f"Expected VM to be running, got: {result}"

    # Shutdown the VM gracefully
    host.succeed("virsh --connect qemu:///system shutdown linux-vm")

    # Wait for it to stop
    time.sleep(5)
    result = host.succeed("virsh --connect qemu:///system domstate linux-vm || true")
    print(f"VM state after shutdown: {result}")

    print("Linux VM boot test passed!")
  '';
}
