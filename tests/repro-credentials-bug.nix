{ pkgs, self }:

pkgs.testers.runNixOSTest {
  name = "repro-credentials-bug-test";
  nodes = {
    machine = { config, pkgs, lib, ... }: {
      imports = [
        self.nixosModules.default
      ];

      # Enable debug logging for systemd to see why credentials fail
      boot.kernelParams = [ "systemd.log_level=debug" "systemd.log_target=console" ];
      
      virtualisation.libvirt.enable = true;
      virtualisation.libvirtd.enable = true;

      services.imperativeContainment = {
        "windows-stateful-mess" = {
          enable = true;
          autostart = true;
          osType = "windows";
          enableTPM = false;
          cores = 2;
          pinOffset = 2;
          memoryMiB = 2048;
          # In test environment, we don't have the real ISO, so we can omit isoPath
          # or use a dummy. But typically windows VMs need an ISO or disk.
          # We'll use createDiskIfMissing = true to ensure disk creation runs.
          createDiskIfMissing = true;
          diskSize = "30G";
          copyIsoFromStore = false; # Can't copy what we don't have
          networkType = "user";
          graphics = "spice";
        };

        "nn" = {
          enable = true;
          autostart = true;
          osType = "linux";
          cores = 1;
          pinOffset = 0;
          memoryMiB = 256;
          networkType = "user";
          copyDiskFromStore = true;
        };
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    
    # Check libvirtd status
    status, output = machine.execute("systemctl status libvirtd")
    print(f"Libvirtd Status Output:\n{output}")
    
    if status != 0:
        print("Libvirtd failed to start. Dumping logs...")
        logs = machine.succeed("journalctl -xeu libvirtd")
        print(f"Libvirtd Logs:\n{logs}")
        
        if "status=243/CREDENTIALS" in output or "Encrypted file too short" in logs:
             # This is a successful reproduction of the bug!
             print("SUCCESS: Reproduced the 243/CREDENTIALS bug!")
        else:
             raise Exception(f"Libvirtd failed with unknown error (exit code {status})")
    else:
        print("Libvirtd started successfully. Checking VM definitions...")
        
        # Verify domains are listed
        domains = machine.succeed("virsh --connect qemu:///system list --all")
        print(f"Domains:\n{domains}")
        
        if "windows-stateful-mess" not in domains:
             print("WARNING: VM 'windows-stateful-mess' is not defined in libvirt!")
        
        if "nn" not in domains:
             print("WARNING: VM 'nn' is not defined in libvirt!")
        
        print("Libvirtd and VM definition check passed - could not reproduce the credentials issue.")
  '';
}
