# cells/dev/homeProfiles/ai-tools.nix
{ inputs, cell }:
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
  ];

  home.file.".claude/CLAUDE.md" = {
    text = ''
      ユーザーには日本語で応答してください。
    '';
  };
}
