# nix-dotfiles-template

## Setup

1. `echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf`
2. `nix --extra-experimental-features nix-command --extra-experimental-features flakes develop`
3. `std //toplevel/darwinConfigurations/macOS:switch`
