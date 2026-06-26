{
  inputs = {
    gen.url = "github:sini/gen";
    # nixpkgs is the CI runner's dependency (test harness, treefmt). gen-select itself
    # (../lib) takes no inputs — see the zero-dependency note in ../flake.nix.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen, ... }:
    let
      genSelect = import ../lib { };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-select";
      testModules = ./tests;
      specialArgs = { inherit genSelect; };
    };
}
