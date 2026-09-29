# A1 CLOSURE — the acceptance test for roadmap item 1. Identity/kind matching through a
# REAL gen-scope.eval graph seeded from REAL gen-schema instances, including the neededBy
# shape (the predicate den-hoag's B4 fixpoint evaluates per entity scope). This is the
# exact path the 2026-06-09 readiness audit found untested. Test-tier deps reach through
# the gen hub; the library stays Class A.
#
# ★ `sel.kind` OVER A gen-scope GRAPH COMPARES THE KIND VALUE ITS NODES CARRY (den-hoag-l0y, arm
# (B′)): a gen-scope kind declares its gen-schema value (`mkKind { kindValue = schema.host; }`) and
# every node of it carries that value. The hand-built roots below carry none, so their four kind
# cells stay refusal cells, each beside the live `attrs` arm over the same graph and position; the
# `kinded` cells at the end are the positive half, over a scope `buildRoots` built.
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
  inherit (genSchema) mkInstanceRegistry;

  schema = genSchema.evalSchema {
    modules = [
      {
        config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; };
        config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; };
      }
    ];
  };

  mkEval =
    siniUid:
    genMerge.evalModuleTree {
      modules = [
        {
          options.users = mkInstanceRegistry schema.user { };
          options.hosts = mkInstanceRegistry schema.host { };
          config.users.sini.uid = siniUid;
          config.users.vic.uid = 1001;
          config.users.ghost.uid = 4242; # registered but never placed in the graph
          config.hosts.axon.addr = "10.0.0.1";
          config.hosts.sini.addr = "10.0.0.9"; # host homonym of a user — id_hash embeds kind
        }
      ];
    };

  eval = mkEval 1000;
  users = eval.config.users;
  hosts = eval.config.hosts;

  # A stale generation: same names, sini's identity field changed → different id_hash.
  staleSini = (mkEval 5000).config.users.sini;

  # Real gen-scope root descriptors; node types set to kind names; entries written to
  # decls.<id>.registration (a den-hoag-shaped registration convention; ctx below supplies
  # entryFor explicitly since scope.nix's default no longer reads it).
  roots = {
    "host:axon" = {
      id = "host:axon";
      type = "host";
      parent = null;
      decls.registration = hosts.axon;
    };
    "host:sini" = {
      id = "host:sini";
      type = "host";
      parent = null;
      decls.registration = hosts.sini;
    };
    "user:sini" = {
      id = "user:sini";
      type = "user";
      parent = "host:axon";
      decls.registration = users.sini;
    };
    "user:vic" = {
      id = "user:vic";
      type = "user";
      parent = "host:axon";
      decls.registration = users.vic;
    };
    "svc:plain" = {
      id = "svc:plain";
      type = "svc";
      parent = "host:axon";
      decls = { }; # synthetic non-entity node
    };
  };

  result =
    genScope.eval
      {
        parseParent = id: roots.${id}.parent or null;
      }
      {
        children = _self: id: lib.filterAttrs (_: n: n.parent == id) roots;
      }
      # A hand-built scope states its own order at the site: `eval` takes the whole
      # `{ nodes, nodeOrder }` record, because a bare node map no longer carries the
      # declared vertex order (gen-scope `lib/require-scope.nix`).
      {
        nodes = roots;
        nodeOrder = builtins.attrNames roots;
      };

  # Explicit entryFor: these roots simulate a den-hoag-shaped consumer (identity
  # stashed under decls.registration), so entryFor's framework-agnostic default
  # (scope.nix) would not find it — the default now reads only the node's own
  # top-level id_hash, mirroring the registry adapter's entryFor default.
  ctx = sel.adapters.scope.mkContext {
    inherit (result) node get;
    entryFor = id: (result.node id).decls.registration or null;
  };
  allIds = builtins.attrNames roots;
  matchIds = selector: builtins.filter (sel.adapters.graph.mkPredicate selector ctx) allIds;
  sortStr = builtins.sort (a: b: a < b);

  # A scope whose `host` kind declares its value, and a second `host` declaration beside it.
  otherHost =
    (genSchema.evalSchema {
      modules = [
        {
          config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; };
          config.schema.host.options.port = genMerge.mkOption { type = genMerge.types.int; };
        }
      ];
    }).host;
  kinded = genScope.buildRoots {
    parentGraph = genScope.vertex "a";
    types.a = "host";
    kinds = genScope.mkKinds [
      (genScope.mkKind { kindValue = schema.user; } "user")
      (genScope.mkKind {
        below = [ "user" ];
        kindValue = schema.host;
        spawns.user = _self: id: {
          sprout = {
            id = "sprout";
            parent = id;
            decls = { };
          };
        };
      } "host")
    ];
  };
  sprout = (genScope.eval { } { children = _self: _id: { }; } kinded).get "a" "derived-children";
  kindedCtx = sel.adapters.scope.mkContext {
    node = id: if id == "sprout" then sprout.sprout else kinded.nodes.${id};
    get = _: _: { };
    entryFor = id: { id_hash = "h-${id}"; };
  };
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.integration-scope = {
    # (a) the neededBy shape: sel.kind through mkPredicate returns exactly the user nodes.
    test-neededby-kind-user-refused = {
      expr = {
        refused = throws (matchIds (sel.kind schema.user));
        attrs = sortStr (matchIds (sel.attrs { type = "user"; }));
      };
      expected = {
        refused = true;
        attrs = [
          "user:sini"
          "user:vic"
        ];
      };
    };
    test-neededby-kind-host-refused = {
      expr = {
        refused = throws (matchIds (sel.kind schema.host));
        attrs = sortStr (matchIds (sel.attrs { type = "host"; }));
      };
      expected = {
        refused = true;
        attrs = [
          "host:axon"
          "host:sini"
        ];
      };
    };

    # (b) sel.entity matches exactly one node.
    test-entity-matches-one = {
      expr = matchIds (sel.entity schema.user users.sini);
      expected = [ "user:sini" ];
    };

    # (c) same selectors through has (parent position) and within (child position).
    test-has-user-from-host-refused = {
      expr = {
        refused = throws (sel.matches (sel.has (sel.kind schema.user)) "host:axon" ctx);
        attrs = sel.matches (sel.has (sel.attrs { type = "user"; })) "host:axon" ctx;
      };
      expected = {
        refused = true;
        attrs = true;
      };
    };
    test-within-host-from-user-refused = {
      expr = {
        refused = throws (sel.matches (sel.within (sel.kind schema.host)) "user:sini" ctx);
        attrs = sel.matches (sel.within (sel.attrs { type = "host"; })) "user:sini" ctx;
      };
      expected = {
        refused = true;
        attrs = true;
      };
    };

    # (d) equal names in different kinds do not cross-match (id_hash embeds kind).
    test-cross-kind-no-collision = {
      expr = matchIds (sel.entity schema.user users.sini);
      expected = [ "user:sini" ]; # NOT host:sini, despite the shared name
    };

    # (e) synthetic non-entity node inside the same graph: quiet false (E5).
    test-nonentity-quiet-kind = {
      expr = sel.matches (sel.kind schema.user) "svc:plain" ctx;
      expected = false;
    };
    test-nonentity-quiet-entity = {
      expr = sel.matches (sel.entity schema.user users.sini) "svc:plain" ctx;
      expected = false;
    };

    # ---- dangling-entry behaviour ----
    # (a) entry registered but never placed in the graph → no match, no throw.
    test-dangling-entry-empty = {
      expr = matchIds (sel.entity schema.user users.ghost);
      expected = [ ];
    };
    # (b) stale registry generation (changed identity field, same name) → no match.
    test-stale-generation-empty = {
      expr = matchIds (sel.entity schema.user staleSini);
      expected = [ ];
    };

    # ---- kinded: a scope whose kinds declare their values ----
    # c1: the node matches the declaration its kind carries.
    test-kinded-c1-node-matches-its-kinds-value = {
      expr = sel.matches (sel.kind schema.host) "a" kindedCtx;
      expected = true;
    };
    # c2: and not another declaration of the same name.
    test-kinded-c2-another-declaration-of-the-name-misses = {
      expr = sel.matches (sel.kind otherHost) "a" kindedCtx;
      expected = false;
    };
    # c6: `attrs` on the projected `type` is unaffected (laziness kept).
    test-kinded-c6-attrs-on-type-unaffected = {
      expr = sel.matches (sel.attrs { type = "host"; }) "a" kindedCtx;
      expected = true;
    };
    # c15: a spawned child matches its produced kind's value, and not its host's.
    test-kinded-c15-spawned-child-matches-its-kind = {
      expr = {
        user = sel.matches (sel.kind schema.user) "sprout" kindedCtx;
        host = sel.matches (sel.kind schema.host) "sprout" kindedCtx;
      };
      expected = {
        user = true;
        host = false;
      };
    };
  };
}
