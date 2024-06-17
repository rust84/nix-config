{
  pkgs,
  lib,
  config,
  hostname,
  ...
}:
let
  ifGroupsExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
  ];

  config = {
    networking = {
      hostName = hostname;
      hostId = "007f0200";
      useDHCP = true;
      firewall.enable = false;
    };

    users.users.russell = {
      uid = 1000;
      name = "russell";
      home = "/home/russell";
      group = "russell";
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ../../homes/russell/config/ssh/ssh.pub);
      hashedPasswordFile = config.sops.secrets."users/russell/password".path;
      isNormalUser = true;
      extraGroups =
        [
          "wheel"
          "users"
        ]
        ++ ifGroupsExist [
          "network"
          "samba-users"
        ];
    };
    users.groups.russell = {
      gid = 1000;
    };

    system.activationScripts.postActivation.text = ''
      # Must match what is in /etc/shells
      chsh -s /run/current-system/sw/bin/fish russell
    '';

    modules = {
      filesystems.zfs = {
        enable = true;
        mountPoolsAtBoot = [
          "tank"
        ];
      };

      services = {
        nfs.enable = true;

        node-exporter.enable = true;

        openssh.enable = true;

        samba = {
          enable = true;
          shares = {
            Docs = {
              path = "/borg/documents";
              "read only" = "no";
            };
            Media = {
              path = "/borg/share";
              "read only" = "no";
            };
            Paperless = {
              path = "/borg/documents/paperless";
              "read only" = "no";
            };
          };
        };

        smartd.enable = true;
        smartctl-exporter.enable = true;
      };

      users = {
        groups = {
          external-services = {
            gid = 65542;
          };
          admins = {
            gid = 991;
            members = [
              "russell"
            ];
          };
        };
      };
    };

    # Use the systemd-boot EFI boot loader.
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}
