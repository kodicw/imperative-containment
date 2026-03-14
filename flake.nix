{
  description = "Imperative Containment Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      NixVirt,
    }:
    {
      nixosConfigurations.demo-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit NixVirt; };
        modules = [
          self.nixosModules.default
          NixVirt.nixosModules.default
          ./configurations.nix
        ];
      };
      
      nixosModules.default = import ./modules/imperative-containment.nix;
    };
}
