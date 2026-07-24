#!/usr/bin/env bash
# generate-flake.sh — Generate a new flake.nix from the go-standard template
#
# Usage: generate-flake.sh [options] <project-name>
#   --templ         Add templ support (treefmt + devShell)
#   --private-deps  Include go-nix-helpers for private deps
#   --no-push       Don't push to GitHub (default)
#   --push          Push to GitHub after generation
#   --dir <path>    Target directory (default: $PROJECTS_DIR/<project-name>)
#   --template <t>  Template to use: "go-standard" (default) or "go-flake-parts"
#   --help          Show this help message
set -euo pipefail

if [ $# -eq 0 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: generate-flake.sh [options] <project-name>"
  echo ""
  echo "Options:"
  echo "  --templ         Add templ support (treefmt + devShell)"
  echo "  --private-deps  Include go-nix-helpers for private deps"
  echo "  --no-push       Don't push to GitHub (default)"
  echo "  --push          Push to GitHub after generation"
  echo "  --dir <path>    Target directory (default: \$PROJECTS_DIR/<project-name>)"
  echo "  --template <t>  Template: \"go-standard\" (default) or \"go-flake-parts\""
  echo ""
  echo "Environment:"
  echo "  PROJECTS_DIR   Base directory for projects (default: $(cd "$(dirname "$0")/.." && pwd)/.."
  echo ""
  echo "Example:"
  echo "  generate-flake.sh my-project --templ --private-deps"
  exit 0
fi

PROJECT=""
USE_TEMPL=false
USE_PRIVATE_DEPS=false
PUSH=false
TEMPLATE="go-standard"
CUSTOM_DIR=""

# Parse arguments: flags can come before or after the project name
while [ $# -gt 0 ]; do
  case "$1" in
    --templ)         USE_TEMPL=true; shift ;;
    --private-deps)  USE_PRIVATE_DEPS=true; shift ;;
    --no-push)       PUSH=false; shift ;;
    --push)          PUSH=true; shift ;;
    --dir)           CUSTOM_DIR="$2"; shift 2 ;;
    --template)      TEMPLATE="$2"; shift 2 ;;
    --help|-h)       exit 0 ;;
    -*)              echo "ERROR: Unknown option: $1"; exit 1 ;;
    *)               PROJECT="$1"; shift ;;
  esac
done

if [ -z "$PROJECT" ]; then
  echo "ERROR: Project name is required"
  echo "Usage: generate-flake.sh [options] <project-name>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve template path
TEMPLATE_FILE="$REPO_ROOT/templates/$TEMPLATE/flake.nix"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "ERROR: Template not found at $TEMPLATE_FILE"
  echo "Available templates: go-standard, go-flake-parts"
  exit 1
fi

# Resolve target directory
if [ -n "$CUSTOM_DIR" ]; then
  TARGET_DIR="$CUSTOM_DIR"
else
  PROJECTS_DIR="${PROJECTS_DIR:-$(cd "$REPO_ROOT/.." && pwd)}"
  TARGET_DIR="$PROJECTS_DIR/$PROJECT"
fi

TARGET="$TARGET_DIR/flake.nix"

if [ -f "$TARGET" ]; then
  echo "ERROR: $TARGET already exists"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Copy template
cp "$TEMPLATE_FILE" "$TARGET"

# Replace placeholders (works with both templates)
sed -i "s/REPLACE_ME/$PROJECT/g" "$TARGET"

# Add templ support if requested (only relevant for go-flake-parts template)
if [ "$USE_TEMPL" = true ] && [ "$TEMPLATE" = "go-flake-parts" ]; then
  sed -i '/programs = {/a\              templ.enable = true;' "$TARGET"
  sed -i '/golangci-lint$/a\                templ,' "$TARGET"
fi

# For go-standard template, uncomment the enableTempl line
if [ "$USE_TEMPL" = true ] && [ "$TEMPLATE" = "go-standard" ]; then
  sed -i 's/# *enableTempl = true;/enableTempl = true;/' "$TARGET"
fi

# Remove private deps section if not requested (go-flake-parts template only)
if [ "$USE_PRIVATE_DEPS" = false ] && [ "$TEMPLATE" = "go-flake-parts" ]; then
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
  read -rp "Push to GitHub? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$TARGET_DIR"
    gh repo create "LarsArtmann/$PROJECT" --private --source=. --push
    echo "Created and pushed to github.com:LarsArtmann/$PROJECT"
  fi
fi
