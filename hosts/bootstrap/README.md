# Installing a new host with nixos-anywhere

1. Boot the NixOS installer
2. Set the root password

        passwd
      
3. Generate an initial config

        nixos-generate-config --no-filesystems --root /mnt

4. Copy the contents of hardware-configuration.nix to this repository.

        cat /mnt/etc/nixos/hardware-config.nix

5. Add your public key to `authorized_keys`.

        mkdir /root/.ssh && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInP9GAskxelbmEOiLDiYfpDQcXUvvoQEjphI7JEhQ6J" | tee authorized_keys

6. Edit `disk-config.nix` with the correct device name!

7. Update the lock file

        nix flake lock

8. Run the installer.

        nix run github:nix-community/nixos-anywhere -- --flake .#bootstrap-machine root@<ip address>

9. Once the system has rebooted then you are ready to apply one of the machine configs.

!!! Note
    Once booted remember to run `nixos-generate-config` and copy the `hardware-configuration.nix` which now contains the root filesystems.
