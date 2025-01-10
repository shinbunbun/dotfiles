{
  inputs,
  cell,
}:
{
  git = {
    programs.git = {
      enable = true;

      userName = "shinbunbun";
      userEmail = "34409044+shinbunbun@users.noreply.github.com";

      extraConfig = {
        core.editor = "code --wait";
      };
    };
  };

  zsh =
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
        shellAliases = {
          ls = "lsd";
        };
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
    };

  vim =
    { pkgs, ... }:
    {
      # vim config
      programs.vim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [ vim-airline ];
      };
    };
  
  google_cloud_sdk =
    { pkgs, ... }: let
      google-cloud-sdk-with-cloud-datastore-emulator = pkgs.google-cloud-sdk.withExtraComponents ([pkgs.google-cloud-sdk.components.cloud-datastore-emulator]);
    in 
    {
      home.packages = with pkgs; [
        google-cloud-sdk-with-cloud-datastore-emulator
      ];
    };
}
