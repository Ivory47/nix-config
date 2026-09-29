{ ... }:

{
    imports = [
        ../../modules/nvidia.nix
    ];

    networking.hostName = "nixos-nas";

    networking.interfaces.enp8s0.wakeOnLan = {
        enable = true;
        policy = [ "magic" ];
    };

    environment.sessionVariables = {
        NIX_CONFIG_TYPE = "nas-server";
    };
}
