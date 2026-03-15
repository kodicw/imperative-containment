{ pkgs, NixVirt, self, windowsIsoPkg }:

{
  linux-vm-boot-test = import ./linux-vm-boot.nix { inherit pkgs NixVirt self; };
  windows-vm-boot-test = import ./windows-vm-boot.nix { inherit pkgs NixVirt self windowsIsoPkg; };
  all-options-eval-test = import ./all-options-eval.nix { inherit pkgs NixVirt self; };
  repro-credentials-bug-test = import ./repro-credentials-bug.nix { inherit pkgs NixVirt self; };
}
