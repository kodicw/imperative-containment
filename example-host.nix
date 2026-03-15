{
  config,
  pkgs,
  ...
}:

{
  imports = [
    # Include your hardware scan here
    # ./hardware-configuration.nix
  ];

  # 1. Enable Libvirt and KVM (Mandatory)
  virtualisation.libvirt.enable = true;
  virtualisation.libvirtd.enable = true;
  
  # 2. Fix for potential systemd 259+ credential errors
  systemd.services.libvirtd.serviceConfig = {
    LoadCredentialEncrypted = pkgs.lib.mkForce "";
    LoadCredential = pkgs.lib.mkForce "";
  };

  # 3. Define a bridge if you want VMs on your LAN (Optional)
  # networking.bridges.br0.interfaces = [ "eno1" ]; # Replace eno1 with your NIC
  # networking.interfaces.br0.useDHCP = true;

  # 4. Configure Your VMs
  services.imperativeContainment = {
    "my-windows-vm" = {
      enable = true;
      autostart = true;
      osType = "windows";
      
      # Resources
      cores = 4;
      memoryMiB = 8192;
      
      # Storage (Imperative)
      vmsPath = "/var/lib/vms";
      createDiskIfMissing = true;
      diskSize = "64G";
      
      # Installation Media (Local Path)
      # Download an ISO and put the absolute path here:
      isoPath = "/var/lib/isos/windows-server-2022.iso";
      copyIsoFromStore = false; # Read directly from host disk
      
      # Network
      networkType = "user"; # Use "bridge" if you set up br0 above
      
      # Display
      graphics = "spice"; # Connect via virt-manager or spice client
    };
  };

  # Add your user to libvirtd group
  users.users.myuser.extraGroups = [ "libvirtd" ];
  
  system.stateVersion = "24.05";
}
