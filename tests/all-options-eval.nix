{ pkgs, NixVirt, self }:

pkgs.testers.runNixOSTest {
  name = "all-options-eval-test";
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
        virtualisation.cores = 2;
        virtualisation.libvirt.enable = true;
        virtualisation.libvirtd.enable = true;
        virtualisation.libvirtd.qemu.swtpm.enable = true;
        environment.systemPackages = [ pkgs.swtpm ];

        # Define a dummy bridge so libvirt doesn't complain if it checks
        networking.bridges.dummybr0.interfaces = [];

        services.imperativeContainment = {
          test-vm-full = {
            enable = true;
            autostart = false; # Do not start, as it would fail due to missing PCI device
            osType = "windows";
            cores = 2;
            pinOffset = 0;
            memoryMiB = 1024;
            pciPassthrough = [ "00:1f.3" "04:00.0" ];
            enableTPM = true;
            vmsPath = "/var/lib/custom-vms";
            diskPath = "/var/lib/custom-vms/test-vm-full.qcow2"; # Cannot use createDiskIfMissing with diskPath
            diskDev = "sda";
            diskBus = "sata";
            cdromDev = "sdc";
            graphics = "spice";
            networkType = "bridge";
            hostBridge = "dummybr0";
            isoPath = null; # Windows VM with null isoPath gets virtio-win cdrom
            arch = "x86_64";
            cpuMode = "host-model";
            restartOnCrash = false;
          };
          
          test-vm-linux-copy = {
            enable = true;
            autostart = false;
            osType = "linux";
            cores = 1;
            pinOffset = 1;
            memoryMiB = 512;
            graphics = "vnc";
            networkType = "user";
            copyDiskFromStore = true;
            createDiskIfMissing = false; # Can't use both
            diskPath = null; # Will auto-compute to /var/lib/vms/test-vm-linux-copy.qcow2
          };
        };
      };
  };

  testScript = ''
    start_all()

    host.wait_for_unit("multi-user.target")
    host.wait_for_unit("libvirtd.service")

    # Check that both VMs are defined
    result = host.succeed("virsh --connect qemu:///system list --all")
    print(f"Defined VMs:\n{result}")
    assert "test-vm-full" in result, "test-vm-full was not defined"
    assert "test-vm-linux-copy" in result, "test-vm-linux-copy was not defined"

    # Dump XML for test-vm-full and verify options
    xml_full = host.succeed("virsh --connect qemu:///system dumpxml test-vm-full")
    print(f"FULL XML:\n{xml_full}")
    
    # Assertions on test-vm-full XML
    assert "<memory unit='KiB'>1048576</memory>" in xml_full, "Memory mismatch"
    assert "<vcpu placement='static'>2</vcpu>" in xml_full, "vCPU mismatch"
    assert "<cpu mode='host-model'" in xml_full, "CPU mode mismatch"
    assert "bus='sata'" in xml_full, "Disk bus mismatch"
    assert "dev='sda'" in xml_full, "Disk dev mismatch"
    assert "type='spice'" in xml_full, "Graphics mismatch"
    assert "bridge='dummybr0'" in xml_full, "Bridge mismatch"
    assert "<on_crash>destroy</on_crash>" in xml_full, "Crash action mismatch (should be destroy since configured to false)"
    
    # Check PCI passthrough translation (00:1f.3 -> bus 0, slot 31 (0x1f), function 3)
    assert "domain='0x0000' bus='0x00' slot='0x1f' function='0x3'" in xml_full, "PCI passthrough 1 mismatch"
    # (04:00.0 -> bus 4, slot 0, function 0)
    assert "domain='0x0000' bus='0x00' slot='0x04' function='0x0'" in xml_full, "PCI passthrough 2 mismatch"

    # Windows-specific hyperv features
    assert "<hyperv " in xml_full or "<hyperv>" in xml_full, "Hyper-V features missing for Windows"
    assert "<spinlocks state='on' retries='8191'/>" in xml_full, "Hyper-V spinlocks missing"

    # Dump XML for test-vm-linux-copy and verify options
    xml_linux = host.succeed("virsh --connect qemu:///system dumpxml test-vm-linux-copy")
    
    # Assertions on test-vm-linux-copy XML
    assert "<memory unit='KiB'>524288</memory>" in xml_linux, "Memory mismatch"
    assert "type='vnc'" in xml_linux, "Graphics mismatch"
    assert "type='user'" in xml_linux, "Network user mismatch"
    assert "<hyperv>" not in xml_linux, "Hyper-V features should not be present for Linux"
    assert "<on_crash>restart</on_crash>" in xml_linux, "Crash action mismatch (should be default restart)"

    print("All module options rendered correctly in Libvirt XML!")
  '';
}
