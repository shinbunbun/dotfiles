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
    # systemd-boot が ESP に保持する世代数の上限。
    # ESP (vfat) は小容量 (g3pro は 486MB) で世代毎に kernel+initrd が ~85MB 積み上がる。
    # limit=5 では 5 世代 (~425MB) が ESP をほぼ埋め切り DiskSpaceLow が解消しなかったため
    # 3 に引き下げる (3 世代 ~255MB、残り ~230MB)。current+2 でロールバックには十分。
    bootConfigurationLimit = v.assertPositiveInt "system.bootConfigurationLimit" 3;
  };

  deploy = {
    sshDomain = v.assertString "deploy.sshDomain" "ssh.shinbunbun.com";
    user = v.assertString "deploy.user" "deploy";
  };
}
