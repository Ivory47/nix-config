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
        nixosConfigurations.default = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";

            specialArgs = {
                inherit inputs;
            };

            modules = [
                ./configuration.nix
            ];
        };
    };
}
