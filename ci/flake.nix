{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    # TEST-TIER dependencies (the integration + registry-identity groups need real
    # gen-scope.eval results and real gen-schema instances). These are CI-harness inputs and
    # NOT library dependencies — the library itself (../lib) takes exactly one, gen-algebra,
    # declared separately below. gen-schema follows the top-level gen-merge so the merge that
    # builds instances is the same one gen-schema's registries evaluate under.
    gen-scope.url = "github:sini/gen-scope";
    gen-merge.url = "github:sini/gen-merge";
    gen-schema.url = "github:sini/gen-schema";
    gen-schema.inputs.gen-merge.follows = "gen-merge";
    # gen-scope reads kind marks through gen-algebra too: one gen-algebra revision in the graph.
    gen-scope.inputs.gen-algebra.follows = "gen-algebra";
    # gen-algebra is the library's OWN dependency (not a test-tier one): ../lib takes it as
    # a named argument, so the ci flake must supply the same input the root flake does.
    gen-algebra.url = "github:sini/gen-algebra";
    # TEST-TIER: `adapters.program`'s cells solve the bodies it emits (den-hoag-mr6xf), so they
    # need gen-program and the substrate it is applied to, read through gen-scope's own pins.
    gen-program.url = "github:sini/gen-program";
    gen-program.inputs.gen-scope.follows = "gen-scope";
    gen-program.inputs.gen-algebra.follows = "gen-algebra";
    gen-program.inputs.gen-prelude.follows = "gen-scope/gen-prelude";
    gen-program.inputs.gen-identity.follows = "gen-scope/gen-identity";
    # nixpkgs is the CI runner's dependency (test harness, treefmt).
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-scope,
      gen-schema,
      gen-merge,
      gen-algebra,
      gen-program,
      ...
    }:
    let
      algebra = gen-algebra.lib;
      genSelect = import ../lib { inherit algebra; };
      genScope = gen-scope.lib;
      genSchema = gen-schema.lib;
      genMerge = gen-merge.lib;
      genProgram = import (gen-program + "/lib") {
        prelude = gen-scope.inputs.gen-prelude.lib;
        scope = genScope;
        inherit algebra;
        identity = gen-scope.inputs.gen-identity.lib;
      };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-select";
      testModules = ./tests;
      specialArgs = {
        inherit
          genSelect
          genScope
          genSchema
          genMerge
          genProgram
          algebra
          ;
      };
      # den-hoag-g8lo's mode-D falsifier cells (a closed-pattern coordsFor/entryFor formal
      # calling this library's own `id` string, "expected a set but found a string") genuinely
      # abort: the batch asserter behind checks.default forces every `flake.tests` expr
      # unconditionally and would crash on them rather than fail a cell. Second output instead.
      extraModules = [
        ./tests-error.nix
        # `any` is a TOMBSTONE (lib/constructors.nix, `── THE RETIRED NAME ──`): `checks.root-surface`
        # excludes it from the walk, and the generated `root-surface-retired.test-retired-any` cell
        # pins this exact message at the root seam, so a resurrected or reworded tombstone reds.
        {
          gen.ci.rootSurface.retired.any =
            "gen-select: `any` is renamed `anyOf`. gen-prelude's `any` is the list predicate `any pred list`, and two callables of one sort with different meanings take two names (grammar R10 rule 3); the arguments and the behaviour are unchanged.";
        }
      ];
    };
}
