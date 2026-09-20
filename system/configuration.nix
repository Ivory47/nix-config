{ config, pkgs, inputs, ... }:


# let
#     hostname = builtins.readFile "/etc/hostname";
# in
{
    imports = [
        ./common/configuration.nix
        /etc/nixos/hardware-configuration.nix
    ];

    # imports = [
    #     ./common/configuration.nix
    #     ./hardware-configuration.nix
    # ] ++ (
    #     if hostname == "nixos-desktop\n" then
    #     [ ./hosts/desktop/configuration.nix ]
    #     else if hostname == "nixos-laptop\n" then
    #     [ ./hosts/laptop/configuration.nix ]
    #     else
    #     builtins.trace
    #     "WARNING: Unknown hostname '${hostname}'. No host-specific configuration will be loaded."
    #     [ ]
    # );

    # networking.hostName = "nixos-desktop";
}
