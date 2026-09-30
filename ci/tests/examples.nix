# The examples emit derivations (checks, devShells); `tests` is the non-derivation output.
# The examples bind gen-select as `import ../.. { }`, the tree they ship in, so the parent is not supplied.
{ lib, ... }:
let
  of = d: {
    inherit
      ((import ../../examples/${d}/flake.nix).outputs {
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
