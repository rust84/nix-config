# nix-config

[![built with nix](https://img.shields.io/badge/built_with_nix-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://builtwithnix.org)

This repository holds my NixOS configuration. It is fully reproducible and flakes based.

For adding overlays see [overlays](#Adding-overlays).

## Usage

### Deploying

#### NixOS

Apply NixOS configuration to a node:

```console
$ task nix:deploy-nixos host=duriel
```


### Adding overlays

Overlays should be added as individual nix files to `./overlays` with format

```nix
final: prev: {
    hello = (prev.hello.overrideAttrs (oldAttrs: { doCheck = false; }));
}
```

For more examples see [./overlays](overlays).

[deploy-rs]: https://github.com/serokell/deploy-rs