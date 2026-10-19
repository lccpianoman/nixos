{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "nixvps" = {
        Hostname = "66.228.49.38";
        User = "luke";
        Port = 47291;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };
      "nixcraft" = {
        Hostname = "96.30.206.210";
        User = "luke";
        Port = 47291;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };
      "calliope" = {
        Hostname = "192.168.0.10";
        User = "luke";
        Port = 47291;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };
    };
  };
}
