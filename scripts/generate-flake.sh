#!/usr/bin/env bash
# generate-flake.sh — Generate a new flake.nix from the go-flake-parts template
# Usage: generate-flake.sh <project-name> [--templ] [--private-deps]
set -euo pipefail

if [ $# -lt 1 ] || [ "$1" = "--help" ]; then
  echo "Usage: generate-flake.sh <project-name> [options]"
  echo "  --templ         Add templ support (treefmt + devShell)"
  echo "  --private-deps  Include go-nix-helpers for private deps"
  echo "  --no-push       Don't push to GitHub"
  exit 0
fi

PROJECT="$1"
shift
USE_TEMPL=false
USE_PRIVATE_DEPS=false
PUSH=true

for arg in "$@"; do
  case "$arg" in
    --templ)         USE_TEMPL=true ;;
    --private-deps)  USE_PRIVATE_DEPS=true ;;
    --no-push)       PUSH=false ;;
  esac
done

TEMPLATE="/home/lars/projects/go-nix-helpers/templates/go-flake-parts/flake.nix"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: Template not found at $TEMPLATE"
  exit 1
fi

TARGET_DIR="/home/lars/projects/$PROJECT"
TARGET="$TARGET_DIR/flake.nix"

if [ -f "$TARGET" ]; then
  echo "ERROR: $TARGET already exists"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Copy template
cp "$TEMPLATE" "$TARGET"

# Replace placeholders
sed -i "s/REPLACE_ME/$PROJECT/g" "$TARGET"

# Add templ support if requested
if [ "$USE_TEMPL" = true ]; then
  # Add templ to treefmt programs
  sed -i '/programs = {/a\              templ.enable = true;' "$TARGET"
  # Add templ to devShell packages
  sed -i '/golangci-lint$/a\                templ,' "$TARGET"
  sed -i '/treefmt-nix config/,+1s/gofumpt.enable = true; goimports.enable = true; nixfmt.enable = true;/gofumpt.enable = true; goimports.enable = true; nixfmt.enable = true; templ.enable = true;/' "$TARGET"
fi

# Remove private deps section if not requested
if [ "$USE_PRIVATE_DEPS" = false ]; then
  # Comment out go-nix-helpers input and references
  sed -i '/go-nix-helpers/,/flake = false/s/^/# /' "$TARGET"
  sed -i '/-- Private deps/,/^  };/s/^/# /' "$TARGET"
fi

echo "Generated $TARGET"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR && git init"
echo "  2. Set vendorHash to \"\" for first build"
echo "  3. nix build .#packages.default --no-out-link 2>&1 | grep 'got:'"
echo "  4. Paste the got: hash as vendorHash"
echo "  5. nix flake check"

if [ "$PUSH" = true ]; then
  read -p "Push to GitHub? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$TARGET_DIR"
    gh repo create "LarsArtmann/$PROJECT" --private --source=. --push
    echo "Created and pushed to github.com:LarsArtmann/$PROJECT"
  fi
fi
