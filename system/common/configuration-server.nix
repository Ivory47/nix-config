{ config, pkgs, ... }:

{
    services.openssh = {
        enable = true;
        settings = {
            PasswordAuthentication = false;

            PermitRootLogin = "no";

            # Automatically terminate idle connections
            ClientAliveInterval = 300;
            ClientAliveCountMax = 5;
        };
        openFirewall = true; 
    };

    users.users."user".openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFKPsyihWbMMcJPYAntj8M0kM3fTJzabYAzM2VhSQuGR windows laptop"

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBwuJ8GzD0i/nucCPbxpSBeQqxKhGlNhrK2R7ruf4+9 phone"

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBWvmTcsZmhpx8HwPvTox1qw1xZVTaFbf40nPDRDvt9k user@LinuxLaptop2"

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIINiKm+iNNuiBXKWdxsg18GiUrVL1vAnAW61CTP80PKs linux pc"

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFGIhjTHQ1T/K6XHqcN/dCdcLKJiBOR0aR7hDc/xNTtd nixos laptop"

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8DpVF/WEL9cKkaShpYCm52vD9e0vACicilrd7cz0Lb windows pc"
    ];

    services.fail2ban = {
        enable = true;
        # Quick protection template for SSH
        jails.ssh-iptables = ''
            enabled  = true;
        filter   = sshd
            action   = iptables[name=SSH, port=ssh, protocol=tcp]
            logpath  = /var/log/auth.log
            maxretry = 8
            bantime  = 3600
            '';
    };

    # continuous TRIM for SSDs to maintain speed and longevity
    services.fstrim.enable = true;

    environment.systemPackages = with pkgs; [
        tmux
        btop
        iotop       # storage monitor
        iftop       # network monitor
        rsync
        lm_sensors  # monitor motherboard and CPU temperatures
    ];

    # disabling documentation building to save CPU cycles and space during rebuilds
    documentation.enable = false;
    documentation.nixos.enable = false;
    documentation.man.enable = false;
}
