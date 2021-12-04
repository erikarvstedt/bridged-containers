#!/usr/bin/env bash
set -euo pipefail

# Run this from within the flake dev shell (`nix develop`).

# ./lib.sh is automatically sourced by the dev shell
source ./lib.sh

trap stop EXIT


# Start the nodes
start

# node1 runs bitcoind in regtest mode
node1 systemctl status bitcoind --no-pager

# node2 runs an electrs service that is connected to bitcoind from node1
node2 systemctl status electrs --no-pager

# Container nodes have WAN access, but it's unused in regtest
node1 curl example.com

# Make bitcoind RPC call from node2 to node1
node2 bitcoin-cli getblockchaininfo

# Call electrs on node2 from the main network namespace.
# The address of node2 is automatically resolved via the `mymachines` systemd NSS module
echo '{"method": "blockchain.headers.subscribe", "id": 0, "params": []}' | nc node2 50001 | head -1 | jq
# Demo nss-mymachines
getent ahosts node2

# ~75% of the startup time of node1 is spent creating the bitcoind regtest wallet (70%) and blocks (5%).
# By caching wallet creation in a nix derivation, this demo could run even faster.
node1 systemd-analyze critical-chain --no-pager

# Delete the nodes and the bridge
stop
