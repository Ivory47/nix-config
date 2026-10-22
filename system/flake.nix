{
    description = "NixOS system configuration";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

        nixpkgs-tailscale.url = 
            "github:NixOS/nixpkgs/c59305bab2065cfecc4944690d9eedbb56f3a9fa";

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
                    ./modules/nvidia.nix
                    ./modules/docker.nix
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
