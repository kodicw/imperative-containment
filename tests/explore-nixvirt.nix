{
  description = "Explore NixVirt";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, NixVirt }: {
    debug = builtins.attrNames NixVirt.lib.domain.templates;
  };
}
