{
  description = "gen-select: selector algebra for attributed graph positions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen.url = "github:sini/gen";
  };

  outputs =
    { nixpkgs, gen, ... }:
    let
      selectLib = import ./lib {
        lib = nixpkgs.lib;
        genPure = gen.pure;
      };
    in
    {
      lib = selectLib;
    };
}
