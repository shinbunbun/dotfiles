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
        cocoapods
        llvm
        nerd-fonts.fira-code
        nil
        nixd
        nixfmt-rfc-style
        warp-terminal
      ];

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # GitHub CLI config
      /*
        programs.git.extraConfig = {
          "credential \"https://github.com\"" = {
            helper = "gh auth git-credential";
          };
          "credential \"https://gist.github.com\"" = {
            helper = "gh auth git-credential";
          };
        };
      */

      # font setting
      fonts.fontconfig.enable = true;
    };
}
