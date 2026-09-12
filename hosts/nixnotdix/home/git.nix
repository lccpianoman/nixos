{ ... }:

let
  identity = import ../../../common/identity.nix;
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = identity.name;
      user.email = identity.email;
      init.defaultBranch = "main";
    };
  };
}
