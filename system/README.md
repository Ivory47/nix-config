rebuild currently doesnt work and you should use
``bash
# desktop:
sudo nixos-rebuild switch --flake /etc/nixos#desktop

# laptop:
sudo nixos-rebuild switch --flake /etc/nixos#laptop

# everything else:
sudo nixos-rebuild switch --flake /etc/nixos#default
``
