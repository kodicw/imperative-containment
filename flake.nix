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
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      nixosConfigurations.demo-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ./examples/demo-host/configurations.nix
        ];
      };

      nixosModules.default =
        { ... }:
        {
          imports = [
            NixVirt.nixosModules.default
            ./modules/imperative-containment.nix
          ];
          _module.args.NixVirt = NixVirt;
        };

      # Tests
      packages.x86_64-linux = import ./tests {
        inherit
          pkgs
          self
          ;
      };

      checks.x86_64-linux = {
        linux-vm-boot-test = self.packages.x86_64-linux.linux-vm-boot-test;
        windows-vm-boot-test = self.packages.x86_64-linux.windows-vm-boot-test;
        all-options-eval-test = self.packages.x86_64-linux.all-options-eval-test;
        repro-credentials-bug-test = self.packages.x86_64-linux.repro-credentials-bug-test;
      };
    };
}
