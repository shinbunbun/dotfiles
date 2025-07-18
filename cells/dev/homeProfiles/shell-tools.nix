# cells/dev/homeProfiles/shell-tools.nix
{ inputs, cell }:
{ pkgs, ... }:
{
  # zsh config
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    plugins = [
      {
        name = "zsh-completions";
        src = pkgs.zsh-completions.src;
      }
      {
        name = "nix-zsh-completions";
        src = pkgs.nix-zsh-completions.src;
      }
    ];
  };

  # LSD config
  programs.lsd = {
    enable = true;
  };

  # starship config
  programs.starship = {
    enable = true;
    settings = {
      status = {
        disabled = false;
      };
      time = {
        disabled = false;
        utc_time_offset = "+9";
        time_format = "%Y-%m-%d %H:%M";
      };
    };
  };

  # direnv config
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };
}
