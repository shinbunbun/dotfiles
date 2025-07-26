{
  inputs,
  cell,
}:
{
  default =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.gh
        pkgs.llvm
        pkgs.nerd-fonts.fira-code
        pkgs.nil
        pkgs.nixd
        pkgs.nixfmt-rfc-style
        pkgs.warp-terminal
        pkgs.google-chrome
      ];

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # font setting
      fonts.fontconfig.enable = true;
    };
}
