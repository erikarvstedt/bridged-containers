start() {
  extra-container create containers.nix --start
}

stop() {
  extra-container destroy node1 node2
}

node1() { sudo nixos-container run node1 -- "$@"; }
node2() { sudo nixos-container run node2 -- "$@"; }
