{ pkgs, lib, ... }:

let
  ipPrefix = "10.200.100";
  numBitcoinBlocks = 100;

  modules.deterministicSecrets = {
    nix-bitcoin.generateSecretsCmds._deterministicSecrets = ''
      makePasswordSecret() {
        [[ -e $1 ]] || echo aaaaaaaa > "$1"
      }
    '';
  };

  ip = "${pkgs.iproute}/bin/ip";
  iptables = "${pkgs.iptables}/bin/iptables";
in
{
  # Run bridge setup/teardown before/after container `node1`
  systemd.services."container@node1" = {
    preStart = ''
      ${ip} link add name br-containers type bridge
      ${ip} link set br-containers up
      ${ip} addr add ${ipPrefix}.1/24 dev br-containers

      # Enable WAN access
      ${iptables} -w -t nat -A POSTROUTING -s ${ipPrefix}.0/24 -j MASQUERADE
    '';

    postStop = ''
      ${iptables} -w -t nat -D POSTROUTING -s ${ipPrefix}.0/24 -j MASQUERADE || true

      ${ip} link del br-containers || true
    '';
  };

  # Start container `node2` after the bridge setup has finished
  systemd.services."container@node2" = rec {
    requires = [ "container@node1.service" ];
    after = requires;
  };

  containers = {
    node1 = {
      privateNetwork = true;
      localAddress = "${ipPrefix}.2/24";
      hostBridge = "br-containers";

      config = { config, ... }: let
        bitcoind = config.services.bitcoind;
      in {
        networking.defaultGateway.address = "${ipPrefix}.1";

        imports = [
          <nix-bitcoin/modules/modules.nix>
          modules.deterministicSecrets
        ];

        nix-bitcoin.generateSecrets = true;

        services.bitcoind = {
          enable = true;
          regtest = true;
          listen = true;
          listenWhitelisted = true; # Needed by electrs
          address = "0.0.0.0";
          rpc.address = "0.0.0.0";
          rpc.allowip = [
            "0.0.0.0/0" # Allow all addresses
          ];
        };

        # Create regtest blocks
        systemd.services.bitcoind.postStart = lib.mkAfter ''
          cli=${bitcoind.cli}/bin/bitcoin-cli
          if ! $cli listwallets | ${pkgs.jq}/bin/jq -e 'index("test")'; then
            $cli -named createwallet  wallet_name=test load_on_startup=true
            address=$($cli -rpcwallet=test getnewaddress)
            $cli generatetoaddress ${toString numBitcoinBlocks} $address
          fi
        '';

        networking.firewall.allowedTCPPorts = [
          bitcoind.port
          bitcoind.whitelistedPort
          bitcoind.rpc.port
        ];
      };
    };

    node2 = {
      privateNetwork = true;
      localAddress = "${ipPrefix}.3/24";
      hostBridge = "br-containers";

      config = { config, ... }: let
        inherit (config.services) electrs bitcoind;
      in {
        networking.defaultGateway.address = "${ipPrefix}.1";

        imports = [
          <nix-bitcoin/modules/modules.nix>
          modules.deterministicSecrets

          <nix-bitcoin/modules/presets/bitcoind-remote.nix>
        ];

        nix-bitcoin.generateSecrets = true;

        # Use bitcoind from container `node1`
        services.bitcoind = {
          enable = true;
          regtest = true;
          address = "${ipPrefix}.2";
          rpc.address = "${ipPrefix}.2";
        };

        services.electrs = {
          enable = true;
          address = "0.0.0.0";
        };

        networking.firewall.allowedTCPPorts = [
          electrs.port
        ];
      };
    };
  };
}
