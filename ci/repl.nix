# gen-select REPL — all exports in scope, aliased as sel. Run: nix repl --impure --file ci/repl.nix
#
# gen-select takes ONE library dependency, gen-algebra, for the identity-regime discipline
# `selectorEq` reads; nixpkgs `lib` is exposed only for interactive convenience and is not a
# library dependency.
#
# ★ THE gen-algebra REV COMES FROM ci/flake.lock, not from a bare registry lookup, so the repl
# evaluates the library against EXACTLY the input the suite does. A repl that silently drifted
# from the suite is a worse debugging surface than no repl — it would answer questions about a
# library nobody is testing. Resolved through the root node's input mapping rather than by
# assuming the node's name, since a transitive copy takes the `_2` suffix and either could
# sort first.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;

  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  algebraRev = lock.nodes.${lock.nodes.root.inputs.gen-algebra}.locked.rev;
  algebra = (builtins.getFlake "github:sini/gen-algebra/${algebraRev}").lib;

  genSelect = import ../lib { inherit algebra; };
in
{
  inherit lib genSelect algebra;
  sel = genSelect;
}
// genSelect
