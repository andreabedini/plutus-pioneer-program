#!/usr/bin/env bash

REF=2fbb7abb22138a434bb6c4f663a81e9b9dc51e98
HASH=09bylak24mkcnpa33796pfq18f6gb84dgy3dl1lmrv7f2qrm618h

export PLUTUS_REPO=$(nix-prefetch-url --unpack --print-path https://github.com/input-output-hk/plutus/tarball/$REF $HASH | tail -1)

echo "Using plutus repository in $PLUTUS_REPO"

start_backend() {
  GHC_WITH_PKGS=$(nix-build --no-out-link -E "(import $PLUTUS_REPO {}).plutus.haskell.project.ghcWithPackages(ps: [ ps.plutus-core ps.plutus-tx ps.plutus-contract ps.plutus-ledger ps.playground-common ])")

  export PATH=$GHC_WITH_PKGS/bin:$PATH
  export FRONTEND_URL=https://localhost:8009
  export WEBGHC_URL=http://localhost:8080

  $(nix-build --no-out-link $PLUTUS_REPO -A plutus-playground.server)/bin/plutus-playground-server webserver
}

export -f start_backend

start_frontend() {
  export CLIENT_DIR=$(nix-build --no-out-link $PLUTUS_REPO -A plutus-playground.client)

  echo "Serving $CLIENT_DIR"

  CADDY=$(nix-build --no-out-link -E "(import <nixpkgs> {}).caddy")/bin/caddy

  $CADDY run --adapter caddyfile --config - <<EOF
  {
          admin off
          http_port 8008
          https_port 8009
          skip_install_trust
  }

  localhost {
          root * $CLIENT_DIR
          reverse_proxy /api/* localhost:8080
          file_server
  }
EOF
}

export -f start_frontend

SESSION_NAME=$(basename $PWD)

tmux \
  set-option -g remain-on-exit                                               \; \
  new-session -s $SESSION_NAME -n nix-shell nix-shell $PLUTUS_REPO/shell.nix \; \
  new-window                   -n backend   start_backend                    \; \
  new-window                   -n frontend  start_frontend                   \;
