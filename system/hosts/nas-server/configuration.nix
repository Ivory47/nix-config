{ pkgs, ... }:

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

    environment.systemPackages = with pkgs; [
        smartmontools
    ];


    # Timers
    systemd.timers."youtube-downloader-update" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "*-*-* 04:00:00";
            Unit = "youtube-downloader-update.service";
        };
    };

    systemd.services."youtube-downloader-update" = {
        description = "Update YouTube downloader Docker containers";

        path = [ pkgs.docker pkgs.docker-compose ];

        script = ''
            set -eu
            docker compose --progress plain pull
            docker compose up -d
            '';

        serviceConfig = {
            Type = "oneshot";
            User = "root";
            WorkingDirectory = "/home/user/containers/youtube-downloader";
        };
    };
}
