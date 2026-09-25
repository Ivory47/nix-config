{ ... }:

{
    imports = [
        ../../modules/nvidia.nix
    ];

    networking.hostName = "nixos-nas";

    environment.sessionVariables = {
        NIX_CONFIG_TYPE = "nas-server";
    };
}
