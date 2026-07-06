{
  inputs = {
    gen.url = "github:sini/gen";
    # Test-tier dependencies only (the integration + registry-identity groups need real
    # gen-scope.eval results and real gen-schema instances). They are CI-harness inputs,
    # not library dependencies — the library itself (../lib) stays Class A, builtins-only,
    # same discipline as nixpkgs here. gen-schema follows the top-level gen-merge so the
    # merge that builds instances is the same one gen-schema's registries evaluate under.
    gen-scope.url = "github:sini/gen-scope";
    gen-merge.url = "github:sini/gen-merge";
    gen-schema.url = "github:sini/gen-schema";
    gen-schema.inputs.gen-merge.follows = "gen-merge";
    # nixpkgs is the CI runner's dependency (test harness, treefmt). gen-select itself
    # (../lib) takes no inputs — see the zero-dependency note in ../flake.nix.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen,
      gen-scope,
      gen-schema,
      gen-merge,
      ...
    }:
    let
      genSelect = import ../lib;
      genScope = gen-scope.lib;
      genSchema = gen-schema.lib;
      genMerge = gen-merge.lib;
    in
    gen.lib.mkCi {
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
