#!/usr/bin/env bash
# nixpkgs_publish.sh — automates publishing a PyPI package to nixpkgs
# Usage: ./nixpkgs_publish.sh <pypi-package-name> [version] [your-github-username]
# Example: ./nixpkgs_publish.sh py4web 1.20240101.1 myhandle

set -euo pipefail

# ── Args ────────────────────────────────────────────────────────────────────
PACKAGE="${1:-}"
VERSION="${2:-}"
GH_USER="${3:-}"

if [[ -z "$PACKAGE" ]]; then
  echo "Usage: $0 <package-name> [version] [github-username]"
  exit 1
fi

# ── Config ───────────────────────────────────────────────────────────────────
NIXPKGS_DIR="${NIXPKGS_DIR:-$HOME/nixpkgs}"
PKG_DIR="$NIXPKGS_DIR/pkgs/development/python-modules/$PACKAGE"
BRANCH="$PACKAGE"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
die()     { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "'$cmd' is required but not found."
  done
}

# ── 0. Check requirements ────────────────────────────────────────────────────
info "Checking requirements..."
require nix git curl python3

# ── 1. Resolve latest version from PyPI if not provided ─────────────────────
if [[ -z "$VERSION" ]]; then
  info "Fetching latest version of '$PACKAGE' from PyPI..."
  VERSION=$(curl -fsSL "https://pypi.org/pypi/$PACKAGE/json" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['version'])")
  info "Latest version: $VERSION"
fi

# ── 2. Fetch metadata from PyPI ──────────────────────────────────────────────
info "Fetching package metadata from PyPI..."
PYPI_JSON=$(curl -fsSL "https://pypi.org/pypi/$PACKAGE/$VERSION/json")

DESCRIPTION=$(echo "$PYPI_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['summary'])")
HOME_PAGE=$(echo "$PYPI_JSON"   | python3 -c "import sys,json; d=json.load(sys.stdin)['info']; print(d.get('project_url') or d.get('home_page') or '')")
LICENSE_STR=$(echo "$PYPI_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['license'] or 'unknown')")

# Map common license strings to nix lib.licenses attrs
map_license() {
  case "${1,,}" in
    *mit*)          echo "licenses.mit" ;;
    *apache*2*)     echo "licenses.asl20" ;;
    *bsd*3*)        echo "licenses.bsd3" ;;
    *bsd*2*|*bsd*)  echo "licenses.bsd2" ;;
    *gpl*3*)        echo "licenses.gpl3Only" ;;
    *gpl*2*)        echo "licenses.gpl2Only" ;;
    *lgpl*3*)       echo "licenses.lgpl3Only" ;;
    *mpl*2*)        echo "licenses.mpl20" ;;
    *isc*)          echo "licenses.isc" ;;
    *)              echo "licenses.unfree  # TODO: verify" ;;
  esac
}
NIX_LICENSE=$(map_license "$LICENSE_STR")

# Extract dependencies from PyPI requires_dist
info "Extracting dependencies..."
DEPS_RAW=$(echo "$PYPI_JSON" | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
reqs = data['info'].get('requires_dist') or []
names = []
for r in reqs:
    # skip extras/conditions
    if ';' in r:
        continue
    name = re.split(r'[\s>=<!(\[]', r)[0].strip()
    if name:
        names.append(name)
for n in sorted(set(names)):
    print(n)
")

# Convert PyPI dep names to nixpkgs python attr names (best-effort)
pypi_to_nix() {
  echo "${1//-/_}" | tr '[:upper:]' '[:lower:]'
}

NIX_DEPS=""
while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  nix_name=$(pypi_to_nix "$dep")
  NIX_DEPS+="    $nix_name\n"
done <<< "$DEPS_RAW"

# ── 3. Compute src hash ──────────────────────────────────────────────────────
info "Computing source hash (this may take a moment)..."
SDIST_URL=$(echo "$PYPI_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data['urls']:
    if f['packagetype'] == 'sdist':
        print(f['url'])
        break
")

if [[ -z "$SDIST_URL" ]]; then
  warn "No sdist found on PyPI — using wheel URL instead"
  SDIST_URL=$(echo "$PYPI_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['urls'][0]['url'])
")
fi

HASH=$(nix-prefetch-url --type sha256 "$SDIST_URL" 2>/dev/null \
  | tail -1 \
  | xargs -I{} nix hash convert --hash-algo sha256 --to sri {} \
  || echo "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=  # TODO: fix hash")

success "Hash: $HASH"

# ── 4. Clone / update nixpkgs ────────────────────────────────────────────────
if [[ ! -d "$NIXPKGS_DIR/.git" ]]; then
  if [[ -n "$GH_USER" ]]; then
    info "Cloning your nixpkgs fork..."
    git clone "https://github.com/$GH_USER/nixpkgs" "$NIXPKGS_DIR"
    cd "$NIXPKGS_DIR"
    git remote add upstream https://github.com/NixOS/nixpkgs
  else
    info "Cloning upstream nixpkgs (no fork specified)..."
    git clone https://github.com/NixOS/nixpkgs "$NIXPKGS_DIR"
    cd "$NIXPKGS_DIR"
  fi
else
  info "Updating existing nixpkgs clone..."
  cd "$NIXPKGS_DIR"
  git fetch upstream 2>/dev/null || git fetch origin
fi

# Create branch
if git show-ref --quiet "refs/heads/$BRANCH"; then
  warn "Branch '$BRANCH' already exists — reusing it"
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH" upstream/master 2>/dev/null \
    || git checkout -b "$BRANCH" origin/master
fi

# ── 5. Write default.nix ─────────────────────────────────────────────────────
info "Writing $PKG_DIR/default.nix ..."
mkdir -p "$PKG_DIR"

# Detect build system
BUILD_SYSTEM="setuptools"
echo "$PYPI_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)['info']
req=d.get('requires_dist') or []
raw=str(d)
if 'flit' in raw.lower(): print('flit-core')
elif 'hatchling' in raw.lower(): print('hatchling')
elif 'poetry' in raw.lower(): print('poetry-core')
else: print('setuptools')
" > /tmp/_bs.txt
BUILD_SYSTEM=$(cat /tmp/_bs.txt)

MAINTAINER_LINE=""
[[ -n "$GH_USER" ]] && MAINTAINER_LINE="    maintainers = with maintainers; [ $GH_USER ];"

cat > "$PKG_DIR/default.nix" <<NIX
{ lib
, buildPythonPackage
, fetchPypi
, $BUILD_SYSTEM
$(echo "$DEPS_RAW" | while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    echo ", $(pypi_to_nix "$dep")"
  done)
}:

buildPythonPackage rec {
  pname = "$PACKAGE";
  version = "$VERSION";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "$HASH";
  };

  build-system = [
    $BUILD_SYSTEM
  ];

  dependencies = [
$(echo -e "$NIX_DEPS")  ];

  pythonImportsCheck = [ "$(echo "$PACKAGE" | tr '-' '_')" ];

  meta = with lib; {
    description = "$DESCRIPTION";
    homepage = "$HOME_PAGE";
    license = $NIX_LICENSE;
$MAINTAINER_LINE
  };
}
NIX

success "Wrote $PKG_DIR/default.nix"

# ── 6. Wire into python-packages.nix ─────────────────────────────────────────
PKGS_NIX="$NIXPKGS_DIR/pkgs/top-level/python-packages.nix"
ENTRY="  $PACKAGE = callPackage ../development/python-modules/$PACKAGE { };"

if grep -q "\"$PACKAGE\"" "$PKGS_NIX" 2>/dev/null || grep -q " $PACKAGE " "$PKGS_NIX" 2>/dev/null; then
  warn "Entry for '$PACKAGE' may already exist in python-packages.nix — skipping"
else
  info "Adding entry to python-packages.nix..."
  # Insert alphabetically before the next package that sorts after it
  python3 - "$PKGS_NIX" "$PACKAGE" "$ENTRY" <<'PYEOF'
import sys, re

path, pkg, entry = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    lines = f.readlines()

# Find insertion point (alphabetical)
pattern = re.compile(r'^\s{2}([a-zA-Z0-9_-]+)\s*=\s*callPackage')
insert_at = None
for i, line in enumerate(lines):
    m = pattern.match(line)
    if m and m.group(1).lower() > pkg.lower():
        insert_at = i
        break

if insert_at is None:
    lines.append(entry + "\n")
else:
    lines.insert(insert_at, entry + "\n")

with open(path, 'w') as f:
    f.writelines(lines)
print(f"Inserted at line {insert_at}")
PYEOF
  success "Added to python-packages.nix"
fi

# ── 7. Build ──────────────────────────────────────────────────────────────────
info "Building python3Packages.$PACKAGE ..."
if nix-build "$NIXPKGS_DIR" -A "python3Packages.$PACKAGE" --no-out-link; then
  success "Build succeeded!"
else
  warn "Build failed — check the nix expression for dependency issues."
  warn "Common fixes:"
  warn "  • Wrong dep name: check nixpkgs for the correct attr"
  warn "  • Missing dep: add it to nixpkgs first in a separate commit"
  warn "  • Hash mismatch: re-run nix store prefetch-file"
fi

# ── 8. Commit ─────────────────────────────────────────────────────────────────
info "Committing..."
cd "$NIXPKGS_DIR"
git add "$PKG_DIR/default.nix" "$PKGS_NIX"
git commit -m "$PACKAGE: init at $VERSION"

# ── 9. Print next steps ───────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "Done! Next steps:"
echo ""
echo "  1. Review generated file:"
echo "       $PKG_DIR/default.nix"
echo ""
echo "  2. Fix any TODOs (deps, license, hash) then rebuild:"
echo "       nix-build $NIXPKGS_DIR -A python3Packages.$PACKAGE"
echo ""
echo "  3. Test import:"
echo "       nix-shell -p python3Packages.$PACKAGE --run \"python -c 'import $(echo "$PACKAGE" | tr '-' '_')'\""
echo ""
if [[ -n "$GH_USER" ]]; then
echo "  4. Push and open a PR:"
echo "       cd $NIXPKGS_DIR"
echo "       git push origin $BRANCH"
echo "       # Then open: https://github.com/$GH_USER/nixpkgs/pull/new/$BRANCH"
else
echo "  4. Push to your fork and open a PR:"
echo "       cd $NIXPKGS_DIR && git push origin $BRANCH"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
