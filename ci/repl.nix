# gen-select REPL — all exports in scope, aliased as sel.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;
  genSelect = import ../lib { inherit lib; };
in
{
  inherit lib genSelect;
  sel = genSelect;
}
// genSelect
