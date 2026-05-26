{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  gen-algebra ? import <gen-algebra> { },
  ...
}:
import ./lib {
  inherit lib;
  genPure = gen-algebra.pure;
}
