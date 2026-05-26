{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  gen-algebra ? import <gen-algebra> { },
  ...
}:
import ./lib {
  inherit lib;
  genAlgebra = gen-algebra.pure;
}
