{
  description = "gen-select: selector algebra for attributed graph positions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen-algebra.url = "github:sini/gen-algebra";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      selectLib = import ./lib {
        lib = nixpkgs.lib;
        genPure = inputs.gen-algebra.pure;
      };
    in
    {
      lib = selectLib;
    };
}
