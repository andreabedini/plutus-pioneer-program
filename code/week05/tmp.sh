#!/usr/bin/env bash

REF=8f1a47674a99ac9bc2aba3231375d8d6de0641d2
HASH=1vg5iixdnckv7jwlw6d45ccyvdhynjzrnkf580g6m1bska467s9x

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
