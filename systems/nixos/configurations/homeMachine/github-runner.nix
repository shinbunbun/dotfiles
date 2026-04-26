/*
  GitHub Actions Self-Hosted Runner 設定 - homeMachine

  dotfiles-private リポジトリ用のセルフホステッドランナーを homeMachine で起動します。
  従来は nixos-desktop で動作していましたが、deploy-rs が nixos-desktop 自身を
  再構築する際に runner サービスが再起動して自分自身の job を殺してしまう問題
  (Issue #639) を解決するため homeMachine へ移設しました。

  - dotfiles-private の deploy 対象は nixos-desktop のみで、homeMachine は対象外
  - dotfiles (本リポジトリ) の homeMachine deploy は ubuntu-latest + WireGuard 経由で
    実行されるため、自己破壊経路は存在しない
  - ラベルは旧 runner と同一 (`nixos`, `x86_64-linux`) のため workflow 側変更は不要
  - Attic キャッシュ (192.168.1.3:8080) は同一ホスト上にあり、ビルドキャッシュは局所的

  リソース分離方針:
    homeMachine は k3s control plane / Attic / CNPG / observability などの
    本番サービスを多数抱えているため、runner の CPU / IO / メモリ消費が
    他サービスを圧迫しないよう cgroup レベルで明示的に絞る。
    - CPUWeight=50 / IOWeight=50: default 100 に対し半分。アイドル時はフルに
      CPU / IO を使えるが、k3s 等が要求した瞬間に譲る
    - MemoryHigh=12G / MemoryMax=16G: ソフト+ハードの 2 段
    - Nice=10: best-effort スケジュール優先度を下げる
    - TasksMax=4096: fork bomb 抑止
    - NIX_CONFIG の cores=4 / max-jobs=2: nix-daemon 経由のビルド本体は
      runner 外の cgroup で走るため、クライアント側で並列度を絞る hint
*/
{
  config,
  pkgs,
  inputs,
  ...
}:
{
  sops.secrets."dotfiles_private_runner_token" = {
    sopsFile = "${inputs.self}/secrets/github-runner-private.yaml";
  };

  services.github-runners.dotfiles-private = {
    enable = true;
    url = "https://github.com/shinbunbun/dotfiles-private";
    tokenFile = config.sops.secrets."dotfiles_private_runner_token".path;
    name = "homemachine";
    extraLabels = [
      "nixos"
      "x86_64-linux"
    ];
    replace = true;
    ephemeral = true;
    nodeRuntimes = [ "node20" ];
    extraPackages = with pkgs; [
      nix
      nixfmt-tree
      git
      gh
      bash
      coreutils
      gnutar
      gzip
      curl
      jq
      openssh
    ];
    extraEnvironment = {
      NIX_CONFIG = ''
        experimental-features = nix-command flakes
        cores = 4
        max-jobs = 2
      '';
    };
    serviceOverrides = {
      # メモリ
      MemoryMax = "16G";
      MemoryHigh = "12G";

      # CPU / IO は他サービスに譲るよう default の半分
      CPUWeight = 50;
      IOWeight = 50;

      # スケジュール優先度
      Nice = 10;

      # fork bomb / 暴走対策
      TasksMax = 4096;
    };
  };
}
