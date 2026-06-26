# gen-select REPL — all exports in scope, aliased as sel. Run: nix repl --impure --file ci/repl.nix
#
# gen-select is zero-dependency (builtins only); nixpkgs `lib` is exposed only for
# interactive convenience.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;
  genSelect = import ../lib { };
in
{
  inherit lib genSelect;
  sel = genSelect;
}
// genSelect
