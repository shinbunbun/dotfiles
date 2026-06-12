## ビルドターゲット

| ターゲット名 | アーキテクチャ | 種別 | 備考 |
|-------------|--------------|------|------|
| `homeMachine` | x86_64-linux | NixOS | deploy-rs対象（ホスト名: homemachine） |
| `g3pro` | x86_64-linux | NixOS | deploy-rs対象（ホスト名: g3pro） |
| `macbook` | aarch64-darwin | Darwin | |
| `macmini` | aarch64-darwin | Darwin | |

## 作業ルール
- 新しい作業を始める時はmainに移動してpullしてbranchを切ってください
- 作業が終わったら、`nix flake check`と`nix fmt`と`nix build`で動作確認を行ってください
- ローカルで動作確認が可能な場合は、動作確認手順を示してください

## コーディングルール
- 値はハードコードせずにshared/config.nixに書いてください
- 各モジュールファイルの冒頭に日本語のブロックコメントを追加
  - モジュールの機能、提供する設定、使用方法を明記
