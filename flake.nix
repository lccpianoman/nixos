{
  description = "Luke's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nur, ... }: {
    # `nix fmt` — nixfmt (RFC 166 style) wrapped in treefmt for whole-tree runs.
    # Declared only; run it when a big reformat diff is acceptable.
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

    nixosConfigurations.nixvps = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nixvps/configuration.nix
      ];
    };

    nixosConfigurations.nixnotdix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nixpkgs.overlays = [ nur.overlays.default ]; }
        ./hosts/nixnotdix/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.luke = import ./hosts/nixnotdix/home.nix;
        }
      ];
    };
  };
}
