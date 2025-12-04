#!/usr/bin/env bash
# install.sh - install deployment helper to a system prefix (default /opt/deployment)
set -euo pipefail

PREFIX="/opt/deployment"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
EXAMPLE_REPO="example"

usage() {
  cat <<USAGE
Usage: install.sh [--prefix DIR] [--example-repo NAME] [--dry-run] [--help]
  --prefix DIR        Install prefix (default: /opt/deployment)
  --example-repo NAME Name of example repo directory to create (default: example)
  --dry-run           Show what would be done, do not modify system
USAGE
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2;;
    --example-repo) EXAMPLE_REPO="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

info() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

install_file() {
  local src="$1" dest="$2"
  if [[ $DRY_RUN -eq 1 ]]; then
    info "DRY RUN: install $src -> $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    chmod 0755 "$dest"
  fi
}

info "Installing to prefix: $PREFIX (example repo: ${EXAMPLE_REPO})"
if [[ $DRY_RUN -eq 1 ]]; then
  info "DRY RUN mode enabled"
fi

# Install main script if present
if [[ -f "${SRC_DIR}/deployment.sh" ]]; then
  install_file "${SRC_DIR}/deployment.sh" "${PREFIX}/deployment.sh"
else
  info "Note: deployment.sh not found in source dir; please copy it manually if needed."
fi

# Prepare example repo dir under PREFIX/<example-repo>
EXAMPLE_DIR="${PREFIX}/${EXAMPLE_REPO}"
if [[ $DRY_RUN -eq 1 ]]; then
  info "DRY RUN: mkdir -p ${EXAMPLE_DIR}"
else
  mkdir -p "${EXAMPLE_DIR}"
fi

if [[ -f "${SRC_DIR}/deploy.conf.sh" ]]; then
  install_file "${SRC_DIR}/deploy.conf.sh" "${EXAMPLE_DIR}/deploy.conf.sh.example"
fi

# Create tmp/ and backup/ skeletons for convenience
for d in tmp backup; do
  if [[ $DRY_RUN -eq 1 ]]; then
    info "DRY RUN: mkdir -p ${EXAMPLE_DIR}/${d}"
  else
    mkdir -p "${EXAMPLE_DIR}/${d}"
  fi
done

info "Install complete. Edit ${EXAMPLE_DIR}/deploy.conf.sh.example and create your repo dir under ${PREFIX}/<your-repo>."
