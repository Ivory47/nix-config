{
    description = "Home Manager configuration of user";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        matugen = {
            url = "github:InioX/Matugen";
        };

        hyprmod = {
            url = "github:BlueManCZ/hyprmod";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        nur.url = "github:nix-community/NUR";
    };

    outputs =
        inputs@{ nixpkgs, home-manager, nur, matugen, ... }:
        let
            system = "x86_64-linux";

            pkgs = import nixpkgs {
                inherit system;

                config.allowUnfree = true;

                overlays = [
                    nur.overlays.default
                ];
            };
        in
        {
            homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
                inherit pkgs;

                extraSpecialArgs = {
                    inherit inputs;
                };
                modules = [ ./home.nix ];
            };
        };
}
