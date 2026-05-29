{
  description = "gen-select: selector algebra for attributed graph positions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen-algebra.url = "github:sini/gen-algebra";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      genSelect = import ./lib {
        lib = nixpkgs.lib;
        genAlgebra = inputs.gen-algebra.pure;
      };
    in
    {
      lib = genSelect;
    };
}
