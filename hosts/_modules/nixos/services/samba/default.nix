{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.services.samba;
in
{
  options.modules.services.samba = {
    enable = lib.mkEnableOption "samba";
    shares = lib.mkOption {
      type = lib.types.attrs;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.samba-users = {};

    services.samba = {
      inherit (cfg) shares;

      enable = true;
      package = pkgs.samba;
      openFirewall = true;

      extraConfig = ''
        workgroup = WORKGROUP
        server string = andariel
        netbios name = andariel
        security = user
        #use sendfile = yes
        #max protocol = smb2
        # note: localhost is the ipv6 localhost ::1
        hosts allow = 10.20.1.0/24 127.0.0.1 localhost
        hosts deny = 0.0.0.0/0
        guest account = nobody
        map to guest = bad user
      '';
    };
  };
}
