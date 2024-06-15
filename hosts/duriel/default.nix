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
      hostId = "9fe3ff83";
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
      services = {
        blocky = {
          enable = true;
          package = pkgs.unstable.blocky;
          config = import ./config/blocky.nix;
        };

        chrony = {
          enable = true;
          servers = [
            "0.nl.pool.ntp.org"
            "1.nl.pool.ntp.org"
            "2.nl.pool.ntp.org"
            "3.nl.pool.ntp.org"
          ];
        };

        node-exporter.enable = true;

        onepassword-connect = {
          enable = true;
          credentialsFile = config.sops.secrets.onepassword-credentials.path;
        };

        openssh.enable = true;
      };

      users = {
        groups = {
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
