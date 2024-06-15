let
  ads-whitelist = builtins.toFile "ads-whitelist" ''
    *.amazonaws.com
  '';
in
{
  ports = {
    dns = "0.0.0.0:53";
    http = 4000;
  };
  bootstrapDns = [
    {
      upstream = "tcp-tls:1.1.1.1:853";
    }
  ];

  upstreams.groups.default = [
    # Cloudflare
    "tcp-tls:1.1.1.1:853"
    "tcp-tls:1.0.0.1:853"
  ];

  caching.cacheTimeNegative = -1;

  conditional = {
    fallbackUpstream = false;
    mapping = {
      "20.10.in-addr.arpa" = "10.20.0.1:53";
      "russhome.xyz" = "10.20.0.1:53";
      "internal" = "10.20.0.1:53";
    };
  };

  # configuration of client name resolution
  clientLookup.upstream = "10.20.0.1:53";

  ecs.useAsClient = true;

  prometheus = {
    enable = true;
    path = "/metrics";
  };

  blocking = {
    loading.downloads.timeout = "4m";
    denylists = {
      ads = [
        "https://big.oisd.nl/domainswild"
      ];
    };

    allowlists = {
      ads = [
        "file://${ads-whitelist}"
      ];
    };

    clientGroupsBlock = {
      default = ["ads"];
    };
  };
}
