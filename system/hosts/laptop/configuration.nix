{ ... }:

{

    networking.hostName = "nixos-laptop";

    environment.sessionVariables = {
        NIX_CONFIG_TYPE = "laptop";
    };
}
