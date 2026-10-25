#!/bin/bash
set -e
# 安装 Nix（单用户）并用它提供 OpenROAD，全程不用 Docker
if ! command -v nix >/dev/null 2>&1; then
  echo "Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
fi

# 确保 nix 在 PATH
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

echo "nix: $(command -v nix || echo MISSING)"

# 尝试从 nixpkgs 取 openroad（若无则给出备选）
echo "=== try nix-env openroad ==="
nix-env -iA nixpkgs.openroad 2>&1 | tail -20 || true
which openroad || true
openroad -version 2>&1 | head -5 || true
