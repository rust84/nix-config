{
  pkgs,
  lib,
  config,
  inputs,
  hostname,
  flake-packages,
  ...
}:
{
  imports = [
    ../_modules

    ./secrets
    ./hosts/${hostname}.nix
  ];

  modules = {
    editor = {
      nvim = {
        enable = true;
        package = flake-packages.${pkgs.system}.nvim;
        makeDefaultEditor = true;
      };
    };

    security = {
      ssh = {
        enable = true;
        matchBlocks = {
          "duriel.russhome.xyz" = {
            port = 22;
            user = "russell";
            forwardAgent = true;
          };
          "milton.russhome.xyz" = {
            port = 22;
            user = "russell";
            forwardAgent = true;
          };
        };
      };
    };

    shell = {
      fish.enable = true;

      git = {
        enable = true;
        username = "Russell Hall";
        email = "owner@russellhall.co.uk";
        signingKey = "5D560D07A4694C2F";
      };

      go-task.enable = true;
    };
  };
}
