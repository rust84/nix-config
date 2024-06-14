{
  pkgs,
  inputs,
  ...
}:

inputs.nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
  inherit pkgs;
  extraSpecialArgs = {};
  module = {
    imports = [ ../homes/russell/config/editor/nvim ];
  };
}
