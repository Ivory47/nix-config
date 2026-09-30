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
# desktop
home-manager switch --flake .#desktop

# laptop
home-manager switch --flake .#laptop

# nas-server
home-manager switch --flake .#nas-server

# everything else
home-manager switch --flake .#default
```

<details>
  <summary>Issues</summary>
    
  * using dirs was a bad idea cause it only knows the recent directories of the current shell
  * link.sh should use paths relative to the git root folder and not relative to itself, because this breaks easily
    
</details>
