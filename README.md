# nix-dotfiles-template

[![Auto Update Flakes (PR Mode)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml)
[![Nix CI](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml)
[![std CI(macOS)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-macos.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-macos.yaml)
[![std CI(NixOS)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-nixos.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-nixos.yaml)

## Setup

1. `echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf`
2. `nix --extra-experimental-features nix-command --extra-experimental-features flakes develop`
3. `std //toplevel/darwinConfigurations/macOS:switch`
