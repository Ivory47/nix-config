{
    description = "NixOS system configuration";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

        silentSDDM = {
            url = "github:uiriansan/SilentSDDM";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = inputs@{ nixpkgs, ... }: {
        nixosConfigurations = {
            desktop = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";

                specialArgs = {
                    inherit inputs;
                };

                modules = [
                    ./configuration.nix
                    ./common/configuration-gui.nix
                    ./hosts/desktop/configuration.nix
                ];
            };

            laptop = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";

                specialArgs = {
                    inherit inputs;
                };

                modules = [
                    ./configuration.nix
                    ./common/configuration-gui.nix
                    ./hosts/laptop/configuration.nix
                ];
            };

            nas-server = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";

                specialArgs = {
                    inherit inputs;
                };

                modules = [
                    ./configuration.nix
                    ./common/configuration-server.nix
                    ./hosts/nas-server/configuration.nix
                ];
            };

            default = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";

                specialArgs = {
                    inherit inputs;
                };

                modules = [
                    ./configuration.nix
                    ./common/configuration-gui.nix
                ];
            };
        };
    };
}
