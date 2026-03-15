{
  description = "Test Flake for Imperative Containment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, NixVirt }:
    let
      lib = nixpkgs.lib;
      allDomains = self.nixosConfigurations.test-host.config.virtualisation.libvirt.connections."qemu:///system".domains;
    in
    {
      nixosConfigurations.test-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit NixVirt; };
        modules = [
          NixVirt.nixosModules.default
          ./modules/imperative-containment.nix
          ({ pkgs, lib, ... }: {
            boot.loader.grub.enable = false;
            fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
            system.stateVersion = "24.05";

            services.imperativeContainment = {
               "linux-vm" = {
                  enable = true;
                  diskPath = "/tmp/test-vm-linux.qcow2";
                  memoryMiB = 2048;
                  cores = 2;
                  pinOffset = 0;
                  osType = "linux";
                  networkType = "bridge";
               };
               "windows-vm" = {
                  enable = true;
                  osType = "windows";
                  enableTPM = false;
                  cores = 4;
                  pinOffset = 2;
                  memoryMiB = 4096;
                  isoPath = ./windows.iso;
                  createDiskIfMissing = true;
                  diskSize = "20G";
                  copyIsoFromStore = true;
                  networkType = "bridge";
                  graphics = "spice";
               };
               "pci-vm" = {
                  enable = true;
                  osType = "linux";
                  cores = 4;
                  pinOffset = 8;
                  memoryMiB = 8192;
                  diskPath = "/tmp/test-vm-pci.qcow2";
                  pciPassthrough = [
                    "01:00.0"
                    "01:00.1"
                  ];
                  networkType = "bridge";
               };
            };
          })
        ];
      };

      packages.x86_64-linux.linux-vm-xml = (builtins.head allDomains).definition;
      packages.x86_64-linux.windows-vm-xml = (builtins.elemAt allDomains 2).definition;
      packages.x86_64-linux.pci-vm-xml = (builtins.elemAt allDomains 1).definition;
    };
}
