{
  description = "Imperative Containment Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";
    win.url = "path:./windows_isos/SERVER_EVAL_x64FRE_en-us.iso";
    win.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      NixVirt,
      win,
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Turn the ISO into a proper package so it gets copied into the VM's nix store
      # We use a dummy file here to avoid checking in a large proprietary ISO
      windowsIsoPkg = pkgs.runCommand "windows-iso" { } ''
        mkdir -p $out
        echo "dummy iso content" > $out/SERVER_EVAL_x64FRE_en-us.iso
      '';
      windowsIsoPath = "${windowsIsoPkg}/SERVER_EVAL_x64FRE_en-us.iso";
    in
    {
      nixosConfigurations.demo-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit NixVirt;
          windowsIsoPath = win;
        };
        modules = [
          self.nixosModules.default
          NixVirt.nixosModules.default
          ./configurations.nix
        ];
      };

      nixosModules.default = import ./modules/imperative-containment.nix;

      # Add ISO as a package so it gets a nix store path
      packages.x86_64-linux = import ./tests {
        inherit
          pkgs
          NixVirt
          self
          windowsIsoPkg
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
