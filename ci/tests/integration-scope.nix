# A1 CLOSURE — the acceptance test for roadmap item 1. Identity/kind matching through a
# REAL gen-scope.eval graph seeded from REAL gen-schema instances, including the neededBy
# shape (the predicate den-hoag's B4 fixpoint evaluates per entity scope). This is the
# exact path the 2026-06-09 readiness audit found untested. Test-tier deps reach through
# the gen hub; the library stays Class A.
{
  lib,
  genSelect,
  genScope,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;
  inherit (genSchema) mkSchemaOption mkInstanceRegistry;

  mkEval =
    siniUid:
    genMerge.evalModuleTree {
      modules = [
        (
          { config, ... }:
          {
            options.schema = mkSchemaOption { };
            config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; };
            config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; };
            options.users = mkInstanceRegistry config.schema.user { };
            options.hosts = mkInstanceRegistry config.schema.host { };
            config.users.sini.uid = siniUid;
            config.users.vic.uid = 1001;
            config.users.ghost.uid = 4242; # registered but never placed in the graph
            config.hosts.axon.addr = "10.0.0.1";
            config.hosts.sini.addr = "10.0.0.9"; # host homonym of a user — id_hash embeds kind
          }
        )
      ];
    };

  eval = mkEval 1000;
  schema = eval.config.schema;
  users = eval.config.users;
  hosts = eval.config.hosts;

  # A stale generation: same names, sini's identity field changed → different id_hash.
  staleSini = (mkEval 5000).config.users.sini;

  # Real gen-scope root descriptors; node types set to kind names; entries written to
  # decls.<id>.__entry (the den-hoag registration convention the default entryFor reads).
  roots = {
    "host:axon" = {
      id = "host:axon";
      type = "host";
      parent = null;
      decls.__entry = hosts.axon;
    };
    "host:sini" = {
      id = "host:sini";
      type = "host";
      parent = null;
      decls.__entry = hosts.sini;
    };
    "user:sini" = {
      id = "user:sini";
      type = "user";
      parent = "host:axon";
      decls.__entry = users.sini;
    };
    "user:vic" = {
      id = "user:vic";
      type = "user";
      parent = "host:axon";
      decls.__entry = users.vic;
    };
    "svc:plain" = {
      id = "svc:plain";
      type = "svc";
      parent = "host:axon";
      decls = { }; # synthetic non-entity node
    };
  };

  result = genScope.eval {
    inherit roots;
    attributes = {
      children = _self: id: lib.filterAttrs (_: n: n.parent == id) roots;
    };
    parseParent = id: roots.${id}.parent or null;
  };

  ctx = sel.adapters.scope.mkContext { inherit (result) node get; };
  allIds = builtins.attrNames roots;
  matchIds = selector: builtins.filter (sel.adapters.graph.mkPredicate selector ctx) allIds;
  sortStr = builtins.sort (a: b: a < b);
in
{
  flake.tests.integration-scope = {
    # (a) the neededBy shape: sel.kind through mkPredicate returns exactly the user nodes.
    test-neededby-kind-user = {
      expr = sortStr (matchIds (sel.kind schema.user));
      expected = [
        "user:sini"
        "user:vic"
      ];
    };
    test-neededby-kind-host = {
      expr = sortStr (matchIds (sel.kind schema.host));
      expected = [
        "host:axon"
        "host:sini"
      ];
    };

    # (b) sel.entity matches exactly one node.
    test-entity-matches-one = {
      expr = matchIds (sel.entity users.sini);
      expected = [ "user:sini" ];
    };

    # (c) same selectors through has (parent position) and within (child position).
    test-has-user-from-host = {
      expr = sel.matches (sel.has (sel.kind schema.user)) "host:axon" ctx;
      expected = true;
    };
    test-within-host-from-user = {
      expr = sel.matches (sel.within (sel.kind schema.host)) "user:sini" ctx;
      expected = true;
    };

    # (d) equal names in different kinds do not cross-match (id_hash embeds kind).
    test-cross-kind-no-collision = {
      expr = matchIds (sel.entity users.sini);
      expected = [ "user:sini" ]; # NOT host:sini, despite the shared name
    };

    # (e) synthetic non-entity node inside the same graph: quiet false (E5).
    test-nonentity-quiet-kind = {
      expr = sel.matches (sel.kind schema.user) "svc:plain" ctx;
      expected = false;
    };
    test-nonentity-quiet-entity = {
      expr = sel.matches (sel.entity users.sini) "svc:plain" ctx;
      expected = false;
    };

    # ---- dangling-entry behaviour ----
    # (a) entry registered but never placed in the graph → no match, no throw.
    test-dangling-entry-empty = {
      expr = matchIds (sel.entity users.ghost);
      expected = [ ];
    };
    # (b) stale registry generation (changed identity field, same name) → no match.
    test-stale-generation-empty = {
      expr = matchIds (sel.entity staleSini);
      expected = [ ];
    };
  };
}
