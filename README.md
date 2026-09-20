rebuild currently doesnt work and you should use
```sh
# desktop:
sudo nixos-rebuild switch --impure --flake /etc/nixos#desktop

# laptop:
sudo nixos-rebuild switch --impure --flake /etc/nixos#laptop

# everything else:
sudo nixos-rebuild switch --impure --flake /etc/nixos#default
```

<details>
  <summary>Issues</summary>
    
  * using dirs was a bad idea cause it only knows the recent directories of the last shell
    
</details>
