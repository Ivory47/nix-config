{ ... }:

{
    imports = [
        ../../modules/nvidia.nix
    ];


    boot.extraModprobeConfig = ''
        options iwlwifi power_save=0
        options iwlmvm power_scheme=1
    '';

    networking.hostName = "nixos-desktop";

    environment.sessionVariables = {
        NIX_CONFIG_TYPE = "desktop";
    };
}
