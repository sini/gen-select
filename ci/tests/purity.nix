# Purity invariant (gen-prelude design §5). gen-select is nixpkgs-free — no nixpkgs.lib and
# no module-system tier — and its library dependency budget is EXACTLY ONE: gen-algebra.
#
# ★ THE INVARIANT NARROWED KNOWINGLY, AND THE TEST NARROWED WITH IT. This suite used to
# forbid `gen-algebra` outright, because gen-select vendored the identity-regime discipline
# rather than importing it. That copy was priced as one trivial line when the relation WAS
# one line; it became a ~40-line dispatch over a tagged sum, and four libraries holding four
# copies of one sum is how the four stop agreeing. The edge is now taken deliberately.
#
# ★ A BAN THAT JUST LOSES A TOKEN IS WEAKER THAN WHAT IT REPLACED, so the token ban is
# paired with a POSITIVE arm: the root flake's declared inputs must be EXACTLY
# [ "gen-algebra" ]. Dropping the token alone would let a SECOND library dependency in
# unnoticed, which is the thing the original invariant actually protected.
#
# Scope: lib/**.nix + the root flake.nix + default.nix (the library + its entries).
# NOT ci/ — the test harness legitimately uses nixpkgs.lib (including, here, to scan).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here
  # because `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # Recursively collect every .nix under a directory (covers lib/adapters/ too).
  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
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

  # Tokens signalling a nixpkgs-lib tether or the module-system tier. `gen-algebra` is no
  # longer among them — it is the one declared dependency, and the arm below is what keeps
  # that a budget of ONE rather than an open door.
  forbidden = [
    "nixpkgs" # a nixpkgs flake input / reference
    "lib." # any nixpkgs lib call (lib.types, lib.genAttrs, …)
    "{ lib }" # the old `{ lib }` parameter signature
    "{ lib," # `{ lib, … }` parameter signature
    "evalModules" # module-system tier
    "mkOption" # module-system tier
  ];

  # The root flake's OWN declared inputs, read from the lock rather than from the flake
  # expression: the lock is what a consumer actually resolves, so a dependency that reached
  # a consumer could not hide from this arm.
  declaredInputs = builtins.attrNames (builtins.fromJSON (builtins.readFile ../../flake.lock))
    .nodes.root.inputs;

  violations = lib.concatMap (
    src:
    map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-nixpkgs-free = {
    expr = violations;
    expected = [ ];
  };

  # THE DEPENDENCY BUDGET, pinned by contents rather than by count — a count is satisfied by
  # swapping one dependency for another, which is not the property.
  flake.tests.purity.test-library-declares-exactly-one-dependency = {
    expr = declaredInputs;
    expected = [ "gen-algebra" ];
  };
}
