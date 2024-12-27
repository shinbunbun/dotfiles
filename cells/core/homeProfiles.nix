{
  inputs,
  cell,
}: {
  default = {
    home.stateVersion = "24.11";

    xdg.enable = true;
    # programs.gpg.enable = true;
    # programs.ssh.enable = true;
  };
}
