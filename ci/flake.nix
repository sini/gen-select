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
    # gen-algebra is the library's OWN dependency (not a test-tier one): ../lib takes it as
    # a named argument, so the ci flake must supply the same input the root flake does.
    gen-algebra.url = "github:sini/gen-algebra";
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
      ...
    }:
    let
      genSelect = import ../lib { algebra = gen-algebra.lib; };
      genScope = gen-scope.lib;
      genSchema = gen-schema.lib;
      genMerge = gen-merge.lib;
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
          ;
      };
    };
}
