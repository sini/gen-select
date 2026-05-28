{
  inputs = {
    gen.url = "github:sini/gen";
    gen-algebra.url = "github:sini/gen-algebra";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      genAlgebra = inputs.gen-algebra.pure;
      selectLib = import ../lib { inherit lib genAlgebra; };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-select";
      testModules = ./tests;
      specialArgs = { inherit selectLib genAlgebra; };
    };
}
