{
  inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin";

  outputs = { self, nix-bitcoin }: let
    system = "x86_64-linux";
    pkgs = import nix-bitcoin.inputs.nixpkgs { inherit system; };
    minimalShell = import ./minimal-shell.nix { inherit pkgs system; };
  in {
    devShell.${system} = minimalShell {
      packages = with pkgs; [
        curl
        jq
        netcat
      ];

      # Used for building the containers
      NIX_PATH = "nixpkgs=${nix-bitcoin.inputs.nixpkgs}:nix-bitcoin=${nix-bitcoin}";

      shellHook = ''
        if ! type -P extra-container >/dev/null; then
          echo "This shell requires extra-container to be installed."
          echo "See: https://github.com/erikarvstedt/extra-container/#install"
          exit 1
        fi

        # IPv4 forwarding is only required for container WAN access
        if [[ $(cat /proc/sys/net/ipv4/ip_forward) != 1 ]]; then
          echo "Error: IPv4 forwarding is required."
          echo "Enable via 'echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward'"
          exit 1
        fi

        source ${./lib.sh}
      '';
    };
  };
}
