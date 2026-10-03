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


    # ZFS config 

    boot.supportedFilesystems = [ "zfs" ];

    boot.zfs.forceImportRoot = false;
    boot.zfs.extraPools = [ "tank" ];
    boot.zfs.devNodes = "/dev/disk/by-id/";

    networking.hostId = "1d78b437";

    services.zfs.autoScrub = {
        enable = true;
        pools = [ "tank" ];
        interval = "monthly";
    };


    # NAS groups
    users.groups = {
        alice = {};
        bob = {};

        nas = {};
        nas-shared = {};
        nas-media = {};
        nas-backups = {};
    };

    # NAS users
    users.users = {
        alice = {
            isSystemUser = true;
            group = "alice";
            description = "NAS user Alice";
            extraGroups = [
                "nas"
                "nas-shared"
                "nas-media"
            ];
        };

        bob = {
            isSystemUser = true;
            group = "bob";
            description = "NAS user Bob";
            extraGroups = [
                "nas"
                "nas-shared"
            ];
        };
    };

    systemd.tmpfiles.rules = [
        "z /tank/shared  2770 root nas-shared  -"
        "z /tank/media   2770 root nas-media   -"
        "z /tank/backups 2770 root nas-backups -"
    ];


    # Samba

    services.samba = {
        enable = true;
        openFirewall = true;

        settings = {
            global = {
                workgroup = "WORKGROUP";
                "server string" = "NixOS NAS";
                "netbios name" = "NAS";

                security = "user";
                "map to guest" = "never";
            };

            shared = {
                path = "/tank/shared";

                browseable = true;
                "read only" = false;
                "guest ok" = false;

                "valid users" = "@nas-shared";
                "force group" = "nas-shared";

                "create mask" = "0660";
                "force create mode" = "0660";

                "directory mask" = "2770";
                "force directory mode" = "2770";
            };

            media = {
                path = "/tank/media";

                browseable = true;
                "read only" = false;
                "guest ok" = false;

                "valid users" = "@nas-media";
                "force group" = "nas-media";

                "create mask" = "0660";
                "force create mode" = "0660";

                "directory mask" = "2770";
                "force directory mode" = "2770";
            };

            backups = {
                path = "/tank/backups";

                browseable = true;
                "read only" = false;
                "guest ok" = false;

                "valid users" = "@nas-backups";
                "force group" = "nas-backups";

                "create mask" = "0660";
                "force create mode" = "0660";

                "directory mask" = "2770";
                "force directory mode" = "2770";
            };
        };
    };

    # Windows network discovery.
    services.samba-wsdd = {
        enable = true;
        openFirewall = true;
    };

    # samba should start after zfs shares are mounted
    systemd.services.samba-smbd.unitConfig.RequiresMountsFor = [
        "/tank/shared"
        "/tank/media"
        "/tank/backups"
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
