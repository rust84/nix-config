{
  description = "My Nix Flake";

  inputs = {
    # Nixpkgs and unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixVim
    nixvim = {
      url = "github:nix-community/nixvim/nixos-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust toolchain overlay
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
    };

    # sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-inspect.url = "github:bluskript/nix-inspect";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nix-inspect,
    rust-overlay,
    sops-nix,
    ...
  } @inputs:
  let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    overlays = import ./overlays {inherit inputs;};
    mkSystemLib = import ./lib/mkSystem.nix {inherit inputs overlays;};
    flake-packages = self.packages;

    legacyPackages = forAllSystems (
      system:
        import nixpkgs {
          inherit system;
          overlays = builtins.attrValues overlays;
          config.allowUnfree = true;
        }
    );
  in
  {
    inherit overlays;

    packages = forAllSystems (
      system: let
        pkgs = legacyPackages.${system};
      in
        import ./pkgs {
          inherit pkgs;
          inherit inputs;
        }
    );

    nixosConfigurations = {
      duriel = mkSystemLib.mkNixosSystem "x86_64-linux" "duriel" flake-packages;
      milton = mkSystemLib.mkNixosSystem "x86_64-linux" "milton" flake-packages;
    };

    # Convenience output that aggregates the outputs for home, nixos.
    # Also used in ci to build targets generally.
    ciSystems =
      let
        nixos = nixpkgs.lib.genAttrs
          (builtins.attrNames inputs.self.nixosConfigurations)
          (attr: inputs.self.nixosConfigurations.${attr}.config.system.build.toplevel);
      in
        nixos;
  };
}
