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

  リソース分離方針 (homeMachine: 4 cores / 15.5 GB RAM、Grafana 実測ベース):
    homeMachine は k3s control plane / Attic / CNPG / observability などの
    本番サービスを多数抱えているため、runner の CPU / IO / メモリ消費が
    他サービスを圧迫しないよう cgroup レベルで明示的に絞る。
    24h メモリピーク ~8G / load1 ピーク 9.04 を踏まえ、2 コア + 4G 程度の
    予算を runner に割り当てる方針。
    - MemoryMax=4G / MemoryHigh=3G: 4 GB ハード上限 + 3 GB ソフト上限。
      残り ~12 GB は他サービスとカーネル page cache 用に確保
    - CPUQuota=200%: 4 cores のうち最大 2 cores を absolute 上限。
      アイドル時に全コアを食い潰すのを防ぐ
    - CPUWeight=50: default 100 に対し半分。競合時はさらに譲る
    - IOWeight=50: 同上、Attic / CNPG WAL flush への波及抑制
    - Nice=10: best-effort スケジュール優先度を下げる
    - TasksMax=2048: fork bomb 抑止
    - NIX_CONFIG の cores=2 / max-jobs=1: nix-daemon 経由のビルド本体は
      runner 外の cgroup で走るため、クライアント側 hint で並列度を絞る
      (1 derivation あたり 2 コアまで、同時 1 derivation のみ)
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
    nodeRuntimes = [ "node24" ];
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
        cores = 2
        max-jobs = 1
      '';
      # actions/checkout@v4 など node20 を要求する JS action を node24 で動かす。
      # nodeRuntimes から node20 を外しているため、これがないと runner が
      # node20 バイナリを起動しようとして即死する。2026-06-16 に GitHub 側で
      # default が node24 に切り替わったら不要になる。
      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 = "true";
    };
    serviceOverrides = {
      # メモリ (homeMachine 15.5 GB 中 4 GB を runner に割当)
      MemoryMax = "4G";
      MemoryHigh = "3G";

      # CPU (4 cores 中 2 cores を absolute 上限、競合時はさらに譲る)
      CPUQuota = "200%";
      CPUWeight = 50;

      # IO は proportional yield のみ
      IOWeight = 50;

      # スケジュール優先度
      Nice = 10;

      # fork bomb / 暴走対策
      TasksMax = 2048;
    };
  };
}
