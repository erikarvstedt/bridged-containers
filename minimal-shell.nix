# A `mkShell` replacement that doesn't pull in the whole nixpkgs
# build stdenv.

{ pkgs, system }:
{
# A list of packages to add to the shell environment
packages ? []
, ...
}@attrs:
derivation ({
  inherit system;

  name = "shell-env";

  # reference: https://github.com/NixOS/nix/blob/94ec9e47030c2a7280503d338f0dca7ad92811f5/src/nix-build/nix-build.cc#L494
  "stdenv" = pkgs.writeTextFile rec {
    name = "setup";
    executable = true;
    destination = "/${name}";
    text = ''
      set -e

      # This is needed for `--pure` to work as expected.
      # https://github.com/NixOS/nix/issues/5092
      PATH=

      for p in $packages; do
        export PATH=$p/bin:$PATH
      done
    '';
  };

  outputs = [ "out" ];

  builder = pkgs.stdenv.shell;
} // attrs)
