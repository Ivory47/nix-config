{ config, lib, pkgs, ... }:

{

    virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
    };    

    users.users."user".extraGroups = lib.mkAfter [ "docker" ];

    environment.systemPackages = with pkgs; [
        docker-compose
    ];
}
