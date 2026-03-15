/*
  MLX Metal GPU対応オーバーレイ

  nixpkgsのMLXはMetal無効（MLX_BUILD_METAL=FALSE）でビルドされているため、
  PyPIのプリビルトwheel（Metal対応済）で置き換える。
  mlx_metalパッケージのlibmlx.dylibをMLX本体にコピーし、
  rpathをパッチすることでApple Silicon GPUでのLLM推論を有効にする。

  aarch64-darwin以外のシステムでは何も変更しない。

  参考: https://aldur.blog/micros/2025/11/04/mlx-with-metal-support-through-nix/
*/
final: prev:
let
  inherit (prev) lib stdenv;
  isDarwinAarch64 = stdenv.isDarwin && stdenv.isAarch64;
in
lib.optionalAttrs isDarwinAarch64 {
  python313 = prev.python313.override {
    packageOverrides = pfinal: pprev: {
      # mlx-lmのテスト・importチェックもmlx.core経由でMetal初期化が走るため無効化
      # （Nixサンドボックス内ではGPUアクセスできずクラッシュする）
      # sentencepieceは本来nativeCheckInputsだがdoCheck=falseで除外されるため
      # dependenciesに追加（wheelメタデータがランタイム依存として宣言しているため）
      mlx-lm = pprev.mlx-lm.overridePythonAttrs (old: {
        doCheck = false;
        pythonImportsCheck = [ ];
        dependencies = (old.dependencies or [ ]) ++ [ pfinal.sentencepiece ];
      });

      mlx =
        let
          version = "0.30.5";
          platform = "macosx_14_0_arm64";

          # Metal GPUバックエンド（libmlx.dylibを含む）
          mlx-metal = pfinal.buildPythonPackage {
            pname = "mlx_metal";
            inherit version;
            format = "wheel";

            src = pfinal.fetchPypi {
              pname = "mlx_metal";
              inherit version;
              format = "wheel";
              inherit platform;
              python = "py3";
              dist = "py3";
              hash = "sha256-+Ch9AgQXAjGu/aCwOsuztUM2hIvoPnkW1+8Y1E4jWTo=";
            };

            dontStrip = true;
            doCheck = false;
          };
        in
        pfinal.buildPythonPackage {
          pname = "mlx";
          inherit version;
          format = "wheel";

          src = pfinal.fetchPypi {
            pname = "mlx";
            inherit version;
            format = "wheel";
            inherit platform;
            python = "cp313";
            dist = "cp313";
            abi = "cp313";
            hash = "sha256-H9k8495WsBaZ3BipZzyJUQ8XchJfxI9jhdyma+NFAPw=";
          };

          nativeBuildInputs = [ prev.fixDarwinDylibNames ];

          # mlx-metalはlib/のコピーで統合するため、wheelメタデータの依存宣言を除去
          # （propagatedBuildInputsに入れるとmlx/名前空間のファイルが衝突する）
          pythonRemoveDeps = [ "mlx-metal" ];

          # mlx_metalからMetal対応libmlx.dylibをコピー
          postInstall = ''
            libdir=${mlx-metal}/lib/python3.13/site-packages/mlx
            cp -r "$libdir/lib" "$out/lib/python3.13/site-packages/mlx/"
          '';

          # .soファイルのrpathとlibmlx.dylib参照をパッチ
          postFixup = ''
            libdir="$out/lib/python3.13/site-packages/mlx"

            if [ -f "$libdir/lib/libmlx.dylib" ]; then
              for so in "$libdir"/*.so; do
                if [ -f "$so" ] && [ "$so" != "$libdir/core.cpython-313-darwin.so" ]; then
                  install_name_tool -add_rpath "$libdir/lib" "$so" 2>/dev/null || true
                  install_name_tool -change @rpath/libmlx.dylib "$libdir/lib/libmlx.dylib" "$so" 2>/dev/null || true
                fi
              done
            else
              echo "ERROR: libmlx.dylib not found after copying from mlx_metal"
              false
            fi
          '';

          dontStrip = true;
          doCheck = false;

          # Metal初期化にGPUアクセスが必要なためNixサンドボックス内ではimportチェック不可
          pythonImportsCheck = [ ];

          meta = {
            description = "Array framework for Apple silicon (Metal GPU enabled)";
            homepage = "https://github.com/ml-explore/mlx";
            license = lib.licenses.mit;
            platforms = lib.platforms.darwin;
          };
        };
    };
  };
}
