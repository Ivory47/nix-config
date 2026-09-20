rebuild currently doesnt work and you should use
```sh
# desktop:
sudo nixos-rebuild switch --impure --flake /etc/nixos#desktop

# laptop:
sudo nixos-rebuild switch --impure --flake /etc/nixos#laptop

# everything else:
sudo nixos-rebuild switch --impure --flake /etc/nixos#default
```
