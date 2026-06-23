/*
  GitHub Actions Self-Hosted Runner 設定 - homeMachine

  dotfiles-private リポジトリ用のセルフホステッドランナーを homeMachine で起動します。
  従来は nixos-desktop で動作していましたが、deploy-rs が nixos-desktop 自身を
  再構築する際に runner サービスが再起動して自分自身の job を殺してしまう問題
  (Issue #639) を解決するため homeMachine へ移設しました。

  - dotfiles-private の deploy 対象は nixos-desktop のみで、homeMachine は対象外
  - dotfiles (本リポジトリ) の homeMachine deploy は ubuntu-latest + WireGuard 経由で
    実行されるため、自己破壊経路は存在しない
  - Attic キャッシュ (192.168.1.3:8080) は同一ホスト上にあり、ビルドキャッシュは局所的

  ラベル設計 (#769):
    この runner は deploy 専用 ("deploy" ラベル付き)。dotfiles-private の deploy job
    (deploy.yaml) だけが "deploy" ラベルを要求し、deploy 対象 (nixos-desktop) 以外の
    ホスト = homeMachine でのみ実行されることを保証する (#639 自己破壊回避)。deploy 以外の
    CI job は "build-only" ラベルで nixos-desktop の build runner プール
    (dotfiles-private github-runner-ci.nix) に流れ、homeMachine には来ない。
    base ラベル (nixos / x86_64-linux) は据え置き、追加で deploy を付与する。

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
    # deploy 専用ラベル (#769)。deploy.yaml の deploy job だけがこの runner に流れ、
    # build-only ジョブ (nixos-desktop プール) はここに来ない。
    extraLabels = [
      "nixos"
      "x86_64-linux"
      "deploy"
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
