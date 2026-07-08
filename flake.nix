{
  description = "Neovim integration for contextualize";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor = pkgs:
        pkgs.vimUtils.buildVimPlugin {
          pname = "cx.nvim";
          version = "flake";
          src = self;
          doCheck = false;
        };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = packageFor pkgs;
          cx-nvim = packageFor pkgs;
        });

      overlays.default = final: _prev: {
        cx-nvim = packageFor final;
      };
    };
}
