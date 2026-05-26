# gen-select REPL — all exports in scope, aliased as sel.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;
  selectLib = import ../lib { inherit lib; };
in
{
  inherit lib selectLib;
  sel = selectLib;
}
// selectLib
