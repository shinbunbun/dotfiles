{
  inputs,
  cell,
}: {
  default = {
    home.stateVersion = "24.05";

    xdg.enable = true;
    programs.gpg.enable = true;
    programs.ssh.enable = true;
  };
}
