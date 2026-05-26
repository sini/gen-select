{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  gen ? import <gen> { },
  ...
}:
import ./lib {
  inherit lib;
  genPure = gen.pure;
}
