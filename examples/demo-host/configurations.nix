{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Network Bridge
  networking.useDHCP = false;
  networking.bridges.br0.interfaces = [ "eth0" ];
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

  # Fix for systemd credential error (status=243/CREDENTIALS)
  systemd.services.libvirtd.serviceConfig = {
    LoadCredentialEncrypted = pkgs.lib.mkForce "";
    LoadCredential = pkgs.lib.mkForce "";
  };

  # Set systemd timeout to 5s to fail fast
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "5s";
    DefaultTimeoutStartSec = "5s";
  };

  # Execute the Module
  services.imperativeContainment = {
    "windows-stateful-mess" = {
      enable = true;
      autostart = true;
      osType = "windows";
      enableTPM = false;
      cores = 2;
      pinOffset = 2;
      memoryMiB = 2048;
      # Note: Point this to your actual local ISO path
      isoPath = "/home/charles/code/nix/imperative-containment/windows_isos/SERVER_EVAL_x64FRE_en-us.iso";
      createDiskIfMissing = true;
      diskSize = "30G";
      copyIsoFromStore = false; # Set to false to use local path directly
      networkType = "user";
      graphics = "spice";
    };

    # "nn" = {
    #   enable = true;
    #   autostart = true;
    #   osType = "linux";
    #   cores = 1;
    #   pinOffset = 0;
    #   memoryMiB = 256;
    #   networkType = "user";
    #   copyDiskFromStore = true;
    # };
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
