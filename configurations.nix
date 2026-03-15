{ config, pkgs, windowsIsoPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Network Bridge
  networking.useDHCP = false;
  networking.bridges.br0.interfaces = [ "eno1" ];
  networking.interfaces.eno1.useDHCP = false;
  networking.interfaces.br0.useDHCP = true;

  # Lightweight Desktop Environment
  services.xserver.enable = true;
  services.displayManager = {
    sddm.enable = true;
    autoLogin = {
      enable = true;
      user = "root";
    };
  };
  services.desktopManager.cosmic.enable = true;

  # Enable SSH
  services.openssh.enable = true;

  # User for demo
  users.users.charles = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "libvirtd"
    ];
  };

  # Execute the Module
  services.imperativeContainment = {
    "windows-stateful-mess" = {
      enable = true;
      osType = "windows";
      enableTPM = false;
      cores = 2;
      pinOffset = 2;
      memoryMiB = 2048;
      isoPath = windowsIsoPath;
      createDiskIfMissing = true;
      diskSize = "30G";
      copyIsoFromStore = true;
      networkType = "user";
      graphics = "vnc";
    };

    "nn" = {
      enable = true;
      osType = "linux";
      cores = 1;
      pinOffset = 0;
      memoryMiB = 256;
      networkType = "user";
      copyDiskFromStore = true;
    };
  };

  # VM specific settings (for nixos-rebuild build-vm)
  virtualisation.vmVariant = {
    boot.kernelParams = [
      "kvm.ignore_msrs=1"
    ];
    virtualisation.memorySize = 8192;
    virtualisation.cores = 4;
    virtualisation.diskSize = 61440; # 60GB
    services.getty.autologinUser = "root";
  };

  system.stateVersion = "24.05";
}
