{ pkgs, ... }:

{
    
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


    # Automatic ZFS snapshots
    services.sanoid = {
        enable = true;
        interval = "hourly";

        datasets = {
            "tank/shared" = {
                autosnap = true;
                autoprune = true;

                hourly = 24;
                daily = 14;
                weekly = 8;
                monthly = 6;
                yearly = 0;
            };

            "tank/backups" = {
                autosnap = true;
                autoprune = true;

                hourly = 24;
                daily = 14;
                weekly = 8;
                monthly = 6;
                yearly = 0;
            };

            "tank/users" = {
                autosnap = true;
                autoprune = true;

                hourly = 24;
                daily = 14;
                weekly = 8;
                monthly = 6;
                yearly = 0;
            };

            "tank/media" = {
                autosnap = true;
                autoprune = true;

                hourly = 24;
                daily = 7;
                weekly = 0;
                monthly = 0;
                yearly = 0;
            };
        };
    };
}
