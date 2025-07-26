{
  inputs,
  cell,
}:
{
  default =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        gh
        llvm
        nerd-fonts.fira-code
        nil
        nixd
        nixfmt-rfc-style
        warp-terminal
        google-chrome
      ];

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # font setting
      fonts.fontconfig.enable = true;
    };
}
