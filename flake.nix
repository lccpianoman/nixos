{
  description = "Luke's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Tracked solely for claude-code, which releases far faster than the stable
    # channel backports it. Nothing else may be taken from this input.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative partitioning — used by nixos-anywhere to install nixcraft.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Packaged Minecraft servers + the services.minecraft-servers module.
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secrets encrypted into this repo, decrypted at activation with each
    # host's SSH host key. Recipients live in .sops.yaml.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, nur, disko, nix-minecraft, sops-nix, ... }:
  let
    mkHost = modules: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit modules;
    };
  in {
    nixosConfigurations.nixvps = mkHost [
      sops-nix.nixosModules.sops
      ./hosts/nixvps/configuration.nix
    ];

    nixosConfigurations.calliope = mkHost [
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
      ./hosts/calliope/configuration.nix
    ];

    nixosConfigurations.nixcraft = mkHost [
      disko.nixosModules.disko
      nix-minecraft.nixosModules.minecraft-servers
      sops-nix.nixosModules.sops
      { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
      ./hosts/nixcraft/configuration.nix
    ];

    nixosConfigurations.nixnotdix = mkHost [
      {
        nixpkgs.overlays = [
          nur.overlays.default
          # claude-code only, straight from unstable — see the input comment.
          # Imported rather than read from legacyPackages so it picks up this
          # host's nixpkgs.config (claude-code is unfree).
          (final: prev: {
            inherit (import nixpkgs-unstable {
              inherit (prev.stdenv.hostPlatform) system;
              inherit (prev) config;
            }) claude-code;
          })
        ];
      }
      ./hosts/nixnotdix/configuration.nix
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.luke = import ./hosts/nixnotdix/home.nix;
      }
    ];
  };
}
