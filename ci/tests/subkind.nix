# `sel.subkind k` matches a node whose kind is `k` or has `k` among its transitive ancestors
# (den-hoag-l0y U3; owner ruling Q3 "a": a new operator, `sel.kind` stays exact). The node's ancestor
# map is gen-schema's `__kindAncestors`, keyed by mark, projected by each adapter beside the kind key;
# a hit is decided by `kindEq`, as `sel.kind` decides. Every cell carries the arm that a library
# which refused, or never matched, everything would fail.
#
# The refusal MESSAGES live in `ci/tests-error.nix`'s `subkind` group; `tryEval` discards a message.
{
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;
  T = genMerge.types;
  intOpt = genMerge.mkOption { type = T.int; };
  openInt =
    d:
    genMerge.mkOption {
      type = T.int;
      default = d;
    };
  tree =
    modules:
    (genMerge.evalModuleTree {
      modules = [ { options.schema = genSchema.mkSchemaOption { }; } ] ++ modules;
    }).config.schema;
  mark = k: k.__mint.minted;

  # `base` carries open content (a default), `baseT` only a type. `fw2` is an independent evaluation
  # of the same declarations: its `baseT` is a type-only twin (one kind, ADR-0034), its `base` an
  # open-content twin (same mark, refused by `kindEq`).
  fwOf =
    _:
    tree [
      {
        config.schema.base.options.b = openInt 0;
        config.schema.baseT.options.b = intOpt;
      }
    ];
  fw = fwOf 1;
  fw2 = fwOf 2;
  V = fw.base;
  VT = fw.baseT;
  # a foreign subkind of `parent`, from a tree of its own
  childOf =
    name: parent:
    (tree [
      {
        config.schema.${name} = {
          inherits = [ parent ];
          options.${name} = intOpt;
        };
      }
    ]).${name};
  sub = childOf "sub" V;
  grand = childOf "grand" sub;
  childTwinT = childOf "subT" fw2.baseT;
  childTwinOpen = childOf "subO" fw2.base;
  # same name and plane as `base`, another mark
  impostor = (tree [ { config.schema.base.options.b = genMerge.mkOption { type = T.str; }; } ]).base;
  childImp = childOf "subI" impostor;

  kinds = {
    b = V;
    s = sub;
    g = grand;
    t = childTwinT;
    o = childTwinOpen;
    i = childImp;
    x = impostor;
  };
  ctx = sel.adapters.registry.mkContext {
    nodes = builtins.attrNames kinds;
    data = id: { id_hash = "h-${id}"; };
    parent = _: null;
    kindFor = id: kinds.${id};
  };
  m = s: id: sel.matches s id ctx;

  tr =
    x:
    let
      r = builtins.tryEval (builtins.deepSeq x x);
    in
    if r.success then r.value else "REFUSED";

  # S6: the field set each adapter projects for a node's kind
  registryFields = builtins.attrNames (ctx.data "s").__identity.kind;
  scopeCtx = sel.adapters.scope.mkContext {
    node = _: {
      id = "n1";
      type = "sub";
      parent = null;
      id_hash = "h-n1";
      kindValue = sub;
    };
    get = _: _: [ ];
  };
  scopeFields = builtins.attrNames (scopeCtx.data "n1").__identity.kind;
  productFields =
    builtins.attrNames
      (sel.adapters.product.mkContext {
        cellIds = [ ];
        coordsFor = _: { };
        kinds.host = sub;
      }).coordKinds.host;
in
{
  flake.tests.subkind = {
    # F14-1 · the operator matches the base kind and its subkind; `sel.kind` stays exact.
    test-operator-matches-both-kinds-kind-stays-exact = {
      expr = {
        subkindOnBase = m (sel.subkind V) "b";
        subkindOnSub = m (sel.subkind V) "s";
        kindOnBase = m (sel.kind V) "b";
        kindOnSub = m (sel.kind V) "s";
        # the direction is not symmetric: a base node is not of the subkind
        subOnBase = m (sel.subkind sub) "b";
      };
      expected = {
        subkindOnBase = true;
        subkindOnSub = true;
        kindOnBase = true;
        kindOnSub = false;
        subOnBase = false;
      };
    };

    # F14-2 · a parent of the same name and plane at another mark is not the kind: `false`, never a
    # match by name. Live arm: the impostor's own subkind matches under the impostor.
    test-impostor-parent-is-not-the-kind = {
      expr = {
        impostorMarkEq = mark impostor == mark V;
        sameName = impostor.kind == V.kind;
        underBase = m (sel.subkind V) "i";
        underImpostor = m (sel.subkind impostor) "i";
      };
      expected = {
        impostorMarkEq = false;
        sameName = true;
        underBase = false;
        underImpostor = true;
      };
    };

    # F14-3 · depth-2 lineage: the ancestor map is transitive, not the direct parents alone.
    test-depth-2-lineage-matches = {
      expr = {
        grandUnderBase = m (sel.subkind V) "g";
        grandUnderSub = m (sel.subkind sub) "g";
        directParents = map (p: p.kind) grand.__kindImports;
      };
      expected = {
        grandUnderBase = true;
        grandUnderSub = true;
        directParents = [ "sub" ];
      };
    };

    # F14-4 · an open-content twin in the lineage is REFUSED, never admitted by its mark alone. Live
    # arm: the same node under its own parent matches.
    test-open-content-twin-in-lineage-refused = {
      expr = {
        marksEqual = mark fw2.base == mark V;
        underBase = tr (m (sel.subkind V) "o");
        underOwnParent = m (sel.subkind fw2.base) "o";
      };
      expected = {
        marksEqual = true;
        underBase = "REFUSED";
        underOwnParent = true;
      };
    };

    # N1 · a type-only twin is one kind (ADR-0034), so its subkind IS a subkind; an open-content twin
    # is refused by `kindEq`, never `false`.
    test-type-only-twin-is-a-subkind-open-twin-refused = {
      expr = {
        typeOnlyTwin = m (sel.subkind VT) "t";
        openTwin = tr (m (sel.subkind V) "o");
        # control: no lineage at all is a plain `false`
        unrelated = m (sel.subkind VT) "s";
      };
      expected = {
        typeOnlyTwin = true;
        openTwin = "REFUSED";
        unrelated = false;
      };
    };

    # S6 · each adapter projects a node's kind as the kind key plus its ancestor map, and nothing else.
    test-registry-projected-node-kind-record-pins-its-field-set = {
      expr = registryFields;
      expected = [
        "ancestors"
        "identity"
        "name"
        "sealed"
      ];
    };
    test-scope-projected-node-kind-record-pins-its-field-set = {
      expr = scopeFields;
      expected = [
        "ancestors"
        "identity"
        "name"
        "sealed"
      ];
    };
    test-product-projected-node-kind-record-pins-its-field-set = {
      expr = productFields;
      expected = [
        "ancestors"
        "identity"
        "name"
        "sealed"
      ];
    };
    # S6 · the selector payload stays the kind key: a selector never reads ancestors.
    test-subkind-selector-payload-is-the-kind-key = {
      expr = builtins.attrNames (sel.subkind V);
      expected = [
        "__sel"
        "identity"
        "name"
        "sealed"
      ];
    };

    # SEL · `selectorEq` decides two subkind selectors as the `kind` arm does: an open-content twin
    # REFUSED (a fall-through `==` would say `false`), a type-only twin `true`, another kind `false`.
    test-selectorEq-on-subkind-decides-as-the-kind-arm = {
      expr = {
        openTwin = tr (sel.selectorEq (sel.subkind V) (sel.subkind fw2.base));
        kindArmOpenTwin = tr (sel.selectorEq (sel.kind V) (sel.kind fw2.base));
        typeOnlyTwin = sel.selectorEq (sel.subkind VT) (sel.subkind fw2.baseT);
        other = sel.selectorEq (sel.subkind V) (sel.subkind sub);
        acrossTags = sel.selectorEq (sel.subkind VT) (sel.kind VT);
      };
      expected = {
        openTwin = "REFUSED";
        kindArmOpenTwin = "REFUSED";
        typeOnlyTwin = true;
        other = false;
        acrossTags = false;
      };
    };
  };
}
