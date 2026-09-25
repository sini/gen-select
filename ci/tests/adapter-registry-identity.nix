# E2 + E6 through the registry adapter over REAL gen-schema instances. This is the
# default-path case the review caught: gen-schema instances carry no type/kind field,
# so kind must come from the registry `kind` argument (or an explicit kindFor), never
# from the datum. Test-tier deps (genSchema/genMerge) reach through the gen hub; the
# library itself stays Class A.
{
  genSelect,
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

  eval = genMerge.evalModuleTree {
    modules = [
      {
        options.users = mkInstanceRegistry schema.user { };
        options.hosts = mkInstanceRegistry schema.host { };
        config.users.sini.uid = 1000;
        config.users.vic.uid = 1001;
        config.hosts.axon.addr = "10.0.0.1";
      }
    ];
  };
  users = eval.config.users;
  hosts = eval.config.hosts;

  userNodes = builtins.attrNames users; # [ "sini" "vic" ]
  userData = id: users.${id};

  # kind passed → every node projects the registry kind.
  ctxK = sel.adapters.registry.mkContext {
    nodes = userNodes;
    data = userData;
    parent = _: null;
    kind = schema.user;
  };
  # kind omitted, no kindFor → kind-blind projection (loud for sel.kind).
  ctxNoK = sel.adapters.registry.mkContext {
    nodes = userNodes;
    data = userData;
    parent = _: null;
  };

  # Heterogeneous two-kind union behind one context, routed by explicit per-id kindFor.
  unionNodes = [
    "u:sini"
    "h:axon"
  ];
  unionData =
    id:
    {
      "u:sini" = users.sini;
      "h:axon" = hosts.axon;
    }
    .${id};
  ctxUnion = sel.adapters.registry.mkContext {
    nodes = unionNodes;
    data = unionData;
    parent = _: null;
    kindFor = id: if id == "u:sini" then schema.user else schema.host;
  };

  # Bare-name kindFor result — a kind name is a REFERENCE, and resolving it needs the shared
  # resolver (den-hoag-7gp66 P1), so the adapter refuses it by name (den-hoag-l0y).
  ctxBare = sel.adapters.registry.mkContext {
    nodes = userNodes;
    data = userData;
    parent = _: null;
    kindFor = _: "user";
  };

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;

  # Two kinds sharing the name `host` that are different DECLARATIONS: B adds a non-key option,
  # so the key sets are equal and only the declaration separates them. Their instances `pewter`
  # carry equal key values. gen-schema's stamp carries the kind's minted identity, so the two are
  # two entities, and `sel.entity` — which compares stamps and holds no kind — must say so.
  twinSchema =
    extra:
    (genSchema.evalSchema {
      modules = [
        {
          config.schema.host.options = {
            addr = genMerge.mkOption { type = genMerge.types.str; };
          }
          // extra;
        }
      ];
    }).host;
  kindA = twinSchema { };
  kindB = twinSchema {
    tags = genMerge.mkOption {
      type = genMerge.types.listOf genMerge.types.str;
      default = [ ];
    };
  };
  pewterOf =
    kindValue:
    (genMerge.evalModuleTree {
      modules = [
        {
          options.hosts = mkInstanceRegistry kindValue { };
          config.hosts.pewter.addr = "10.0.0.9";
        }
      ];
    }).config.hosts.pewter;
  pewterA = pewterOf kindA;
  pewterB = pewterOf kindB;
  ctxOf =
    inst:
    sel.adapters.registry.mkContext {
      nodes = [ "pewter" ];
      data = _: inst;
      parent = _: null;
    };
in
{
  flake.tests.adapter-registry-identity = {
    # ---- E6: default entryFor finds identity in the datum (data IS the entry) ----
    test-default-entryfor-idhash = {
      expr = (ctxK.data "sini").__identity.id_hash == users.sini.id_hash;
      expected = true;
    };

    # ---- E2: kind argument projects the registry kind → sel.kind matches every node ----
    test-kind-matches-all-nodes = {
      expr = builtins.all (id: sel.matches (sel.kind schema.user) id ctxK) userNodes;
      expected = true;
    };
    test-entity-matches-one-node = {
      expr = builtins.filter (id: sel.matches (sel.entity users.sini) id ctxK) userNodes;
      expected = [ "sini" ];
    };

    # ---- E2: kind-blind context is loud for sel.kind, transparent for sel.entity ----
    test-kind-blind-throws = {
      expr = throws (sel.matches (sel.kind schema.user) "sini" ctxNoK);
      expected = true;
    };
    test-entity-works-without-kind = {
      expr = sel.matches (sel.entity users.sini) "sini" ctxNoK;
      expected = true;
    };

    # ---- heterogeneous union: explicit kindFor routes each kind correctly ----
    test-union-routes-user = {
      expr = sel.matches (sel.kind schema.user) "u:sini" ctxUnion;
      expected = true;
    };
    test-union-routes-host = {
      expr = sel.matches (sel.kind schema.host) "h:axon" ctxUnion;
      expected = true;
    };
    test-union-no-crossmatch = {
      expr = sel.matches (sel.kind schema.host) "u:sini" ctxUnion;
      expected = false;
    };

    # ---- same name, different declarations: two entities ----
    test-entity-separates-same-name-kinds = {
      expr = {
        selectorEq = sel.selectorEq (sel.entity pewterA) (sel.entity pewterB);
        matchesOtherKind = sel.matches (sel.entity pewterA) "pewter" (ctxOf pewterB);
        # the live arm: the entity matches its own node
        matchesOwnKind = sel.matches (sel.entity pewterA) "pewter" (ctxOf pewterA);
      };
      expected = {
        selectorEq = false;
        matchesOtherKind = false;
        matchesOwnKind = true;
      };
    };

    # ---- bare-name kindFor refused; the kind-value context above answers ----
    test-bare-name-kindfor-refused = {
      expr = {
        bare = throws (sel.matches (sel.kind schema.user) "sini" ctxBare);
        value = sel.matches (sel.kind schema.user) "sini" ctxK;
      };
      expected = {
        bare = true;
        value = true;
      };
    };

    # ---- malformed kind argument (no `options`) → throws when the context is used ----
    test-malformed-kind-arg-throws = {
      expr = throws (
        (sel.adapters.registry.mkContext {
          nodes = userNodes;
          data = userData;
          parent = _: null;
          kind = {
            kind = "user";
          }; # missing options
        }).data
      );
      expected = true;
    };
  };
}
