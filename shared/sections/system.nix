/*
  システム・Git・デプロイ設定セクション

  NixOSバージョン、タイムゾーン、Git設定、デプロイ設定を定義します。
*/
v: {
  git = {
    userName = v.assertString "git.userName" "shinbunbun";
    userEmail = v.assertEmail "git.userEmail" "34409044+shinbunbun@users.noreply.github.com";
    coreEditor = v.assertString "git.coreEditor" "code --wait";
  };

  system = {
    nixosStateVersion = v.assertString "system.nixosStateVersion" "21.11";
    homeStateVersion = v.assertString "system.homeStateVersion" "24.11";
    timeZone = v.assertString "system.timeZone" "Asia/Tokyo";
  };

  deploy = {
    sshDomain = v.assertString "deploy.sshDomain" "ssh.shinbunbun.com";
    user = v.assertString "deploy.user" "deploy";
  };
}
