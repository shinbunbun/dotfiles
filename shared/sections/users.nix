/*
  ユーザー設定セクション

  NixOS/Darwin環境のユーザー名とホームディレクトリを定義します。
*/
v: {
  users = {
    nixos = {
      username = v.assertString "users.nixos.username" "bunbun";
      homeDirectory = v.assertPath "users.nixos.homeDirectory" "/home/bunbun";
    };
    darwin = {
      username = v.assertString "users.darwin.username" "shinbunbun";
      homeDirectory = v.assertPath "users.darwin.homeDirectory" "/Users/shinbunbun";
    };
  };
}
