{ config, pkgs, ... }:

{
    hardware.graphics.enable = true;

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia-container-toolkit.enable = true;

    hardware.nvidia = {
        modesetting.enable = true;
        open = true;
        nvidiaSettings = true;
        powerManagement.enable = true;
    };
}
