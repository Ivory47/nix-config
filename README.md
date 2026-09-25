# System Config

For first use, use the following:
```sh
# desktop:
sudo nixos-rebuild switch --impure --flake /etc/nixos#desktop

# laptop:
sudo nixos-rebuild switch --impure --flake /etc/nixos#laptop

# nas-server:
sudo nixos-rebuild switch --impure --flake /etc/nixos#nas-server

# everything else:
sudo nixos-rebuild switch --impure --flake /etc/nixos#default
```

after that you can use `rebuild` because the device is saved


# User Config (Home manager)

```sh
home-manager switch --flake ~/.config/home-manager
```

<details>
  <summary>Issues</summary>
    
  * using dirs was a bad idea cause it only knows the recent directories of the current shell
    
</details>
