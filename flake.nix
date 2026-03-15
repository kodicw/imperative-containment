{
  description = "Imperative Containment Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";
    windows-iso = {
      url = "path:./windows_isos/SERVER_EVAL_x64FRE_en-us.iso";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      NixVirt,
      windows-iso,
    }:
    let
      windowsIsoPath = windows-iso.outPath;
    in
    {
      nixosConfigurations.demo-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { 
          inherit NixVirt;
          windowsIsoPath = windowsIsoPath;
        };
        modules = [
          self.nixosModules.default
          NixVirt.nixosModules.default
          ./configurations.nix
        ];
      };
      
      nixosModules.default = import ./modules/imperative-containment.nix;
    };
}
