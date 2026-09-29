# The examples emit derivations (checks, devShells); `tests` is the non-derivation output.
# After 29a2b16 the examples take `gen-select.lib`, so the parent is supplied as the working-tree lib.
{ lib, genSelect, ... }:
let
  of = d: {
    inherit
      ((import ../../examples/${d}/flake.nix).outputs {
        gen-select.lib = genSelect;
        nixpkgs.lib = lib;
        nix-unit = null;
      })
      tests
      ;
  };
in
{
  gen.ci.examples = lib.genAttrs [ "css-selectors" "sql-where" ] of;
}
