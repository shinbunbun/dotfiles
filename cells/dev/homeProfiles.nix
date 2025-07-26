# cells/dev/homeProfiles.nix
/*
  開発home-managerプロファイルエントリポイント

  このモジュールは開発ツール関連のhome-managerプロファイルを
  統合します：
  - versionControl: Git設定とバージョン管理ツール
  - shellTools: シェル強化ツール（zsh、starship、direnv等）
  - editors: エディタ設定（vim）
  - developmentTools: 開発ツール（cocoapods等）
  - cloudTools: クラウドツール（Google Cloud SDK等）
  - aiTools: AIツール（claude-code等）
  - securityTools: セキュリティツール（age、sops）

  各プロファイルは独立したモジュールとして管理され、
  必要に応じて組み合わせて使用します。
*/
{
  inputs,
  cell,
}:
{
  # モジュール（camelCase）
  versionControl = import ./homeProfiles/version-control.nix { inherit inputs cell; };
  shellTools = import ./homeProfiles/shell-tools.nix { inherit inputs cell; };
  editors = import ./homeProfiles/editors.nix { inherit inputs cell; };
  cloudTools = import ./homeProfiles/cloud-tools.nix { inherit inputs cell; };
  securityTools = import ./homeProfiles/security-tools.nix { inherit inputs cell; };
  developmentTools = import ./homeProfiles/development-tools.nix { inherit inputs cell; };
  aiTools = import ./homeProfiles/ai-tools.nix { inherit inputs cell; };

}
