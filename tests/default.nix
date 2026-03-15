{ pkgs, self }:

{
  linux-vm-boot-test = import ./linux-vm-boot.nix { inherit pkgs self; };
  windows-vm-boot-test = import ./windows-vm-boot.nix { inherit pkgs self; };
  all-options-eval-test = import ./all-options-eval.nix { inherit pkgs self; };
  repro-credentials-bug-test = import ./repro-credentials-bug.nix { inherit pkgs self; };
}
