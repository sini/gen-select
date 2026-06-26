# Purity invariant (gen-prelude design §5): gen-select is dependency-free — builtins
# only, no nixpkgs.lib and no gen-algebra. This pins "pure" as a checked property: a
# stray `lib.foo` / `lib.types` / `evalModules` / `genAlgebra` / nixpkgs input creeping
# back into the library source fails CI.
#
# Scope: lib/**.nix + the root flake.nix + default.nix (the library + its entries).
# NOT ci/ — the test harness legitimately uses nixpkgs.lib (including, here, to scan).
{ lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here
  # because `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  readNix =
    dir:
    map (name: {
      inherit name;
      code = stripComments (builtins.readFile (dir + "/${name}"));
    }) (lib.filter (lib.hasSuffix ".nix") (lib.attrNames (builtins.readDir dir)));

  sources =
    readNix libDir
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  # Tokens signalling a nixpkgs-lib tether, the module-system tier, or a gen-algebra dep.
  forbidden = [
    "nixpkgs" # a nixpkgs flake input / reference
    "lib." # any nixpkgs lib call (lib.types, lib.genAttrs, …)
    "{ lib }" # the old `{ lib }` parameter signature
    "{ lib," # `{ lib, … }` parameter signature
    "evalModules" # module-system tier
    "mkOption" # module-system tier
    "genAlgebra" # the dropped gen-algebra dependency
    "gen-algebra" # …and its flake-input form
  ];

  violations = lib.concatMap (
    src: map (tok: "${src.name}: '${tok}'") (lib.filter (tok: lib.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-dependency-free = {
    expr = violations;
    expected = [ ];
  };
}
