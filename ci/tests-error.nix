# THE SECOND TEST OUTPUT — cells whose `expr` genuinely ABORTS, read by
# `nix-unit --flake ./ci#testsError`. Structural placement mirrors gen-harness's own
# ci/tests-error.nix: this file lives OUTSIDE `./tests` (the whole of `testModules`), wired
# through `extraModules` in ../flake.nix, so nothing depends on a filter predicate.
#
# O3/O9 of specs/2026-09-16-gen-select-adapter-defaults-spec.md §3 — the caller-function-
# totality falsifier cells (den-hoag-g8lo): a CLOSED-PATTERN formal (`{ id }: …`) has its arity
# erased by `functionArgs`, so no door built from `isFunction`/`isAttrs` can distinguish it from
# an open one, and calling it with the plain string `id` this library always passes raises Nix's
# own "expected a set but found a string" TypeError — a raw interpreter abort, not a `throw`,
# which `builtins.tryEval` does not catch (measured, both adapters, same class). These cells
# assert that abort BY NAME so a future change that quietly closes or quietly widens the escape
# is visible either way, rather than leaving mode D untested because it cannot be forced under
# `flake.tests` without crashing the batch asserter behind `checks.default`.
{
  lib,
  genSelect,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;

  # A REAL kind, for the live control inside each kind-mark cell below.
  schema = genSchema.evalSchema { } [
    { config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; }; }
  ];

  # The stand-in the retired `? kind && ? options` guard admitted. den-hoag's compat tree mints
  # exactly this and feeds it to two live `sel.kind` constructions, with an in-file comment
  # sanctioning it — that tree is frozen (ADR-0002) and ADR-0034 rules breaking it acceptable at
  # this seam, so the evasion comes out by becoming INEXPRESSIBLE here rather than by an edit there.
  standIn = {
    kind = "user";
    options = { };
  };

  # den-hoag-l0y: two `host` kinds whose only difference is an option typed with a nixpkgs
  # `lib.types` type — unmigrated, so the component is SEALED and the two mint one mark.
  mkHost = d: (genSchema.evalSchema { } [ { config.schema.host.options = d; } ]).host;
  kS = mkHost { addr = genMerge.mkOption { type = lib.types.str; }; };
  kI = mkHost { addr = genMerge.mkOption { type = lib.types.int; }; };
  kS2 = mkHost { addr = genMerge.mkOption { type = lib.types.str; }; };
  kG = mkHost { addr = genMerge.mkOption { type = genMerge.types.str; }; };
  instances = genMerge.evalModuleTree { } [
    {
      options.hs = genSchema.mkInstanceRegistry { } kG;
      config.hs.axon.addr = "10.0.0.1";
    }
  ];
  registryCtx =
    kindFor:
    sel.adapters.registry.mkContext {
      nodes = [ "axon" ];
      data = id: instances.config.hs.${id};
      parent = _: null;
      inherit kindFor;
    };
  scopeCtx = sel.adapters.scope.mkContext {
    node = _: {
      id = "n1";
      type = "host";
      parent = null;
      id_hash = "h-n1";
    };
    get = _: _: [ ];
  };

  # den-hoag-l0y (β): the sealed-collision fixture, shared with ./tests/entity-sealed.nix.
  F = import ./entity-sealed-fixture.nix {
    inherit
      lib
      genSelect
      genSchema
      genMerge
      ;
  };
  # `sel.entity`'s live controls: a two-argument selector over a migrated kind decides.
  entryU = {
    id_hash = "h-sini";
    name = "sini";
  };
  decides = e: (builtins.tryEval (builtins.deepSeq e e)).success;
  identityBlindCtx = {
    data = _: { role = "x"; };
    parent = _: null;
  };
  malformedEntryCtx = {
    data = _: {
      __identity = {
        id_hash = throw "malformed entry: no id_hash";
        kind = removeAttrs (sel.kind schema.user) [ "__sel" ];
        entry = { };
      };
    };
    parent = _: null;
  };
  malformedEntryForCtx = sel.adapters.scope.mkContext {
    node = id: {
      inherit id;
      type = "host";
      parent = null;
      decls = { };
    };
    get = _: _: [ ];
    entryFor = id: if id == "host:axon" then { name = "axon"; } else null;
  };
  # The fixture's `note` carries a default, open content gen-schema seals per construction
  # (den-hoag-egei0), so the pair differs at both components and the refusal names both.
  sealedMsgAt =
    comps: site:
    "^gen-select: ${site}: two declarations of 'host' mint one identity and are unequal only at sealed component\\(s\\) ${comps}: a sealed component is compared by its seal, the whole value under Nix `==`, where two separately built functions are never equal, so two separate constructions are refused even where the values they compute are equal; a sealed component has no identity, because identity is minted from inert structure alone";
  sealedMsg = sealedMsgAt "'open\\.options\\.note\\.default', 'options\\.note\\.type'";
  # A twin of one declaration carrying open content differs at its open subject alone.
  twinMsg = sealedMsgAt "'open\\.options\\.note\\.default'";
  typeMsg = sealedMsgAt "'options\\.note\\.type'";

  # den-hoag-egei0: the PURE type collision, E2s's original subject. `note` carries no default and
  # no other open content, so its twin decides and the refusal names the type alone.
  T =
    let
      mkKind = decl: (genSchema.evalSchema { } [ { config.schema.host.options = decl; } ]).host;
      decl = t: {
        addr = genMerge.mkOption { type = genMerge.types.str; };
        note = genMerge.mkOption { type = t; };
      };
      k1 = mkKind (decl lib.types.lines);
      k1t = mkKind (decl lib.types.lines);
      k2 = mkKind (decl lib.types.commas);
      c =
        (genMerge.evalModuleTree { } [
          {
            options.h1 = genSchema.mkInstanceRegistry { } k1;
            options.h1t = genSchema.mkInstanceRegistry { } k1t;
            options.h2 = genSchema.mkInstanceRegistry { } k2;
            config.h1.p.addr = "10.0.0.1";
            config.h1t.p.addr = "10.0.0.1";
            config.h2.p.addr = "10.0.0.1";
          }
        ]).config;
      nodes = {
        t1 = c.h1.p;
        t1t = c.h1t.p;
        t2 = c.h2.p;
      };
      kinds = {
        t1 = k1;
        t1t = k1t;
        t2 = k2;
      };
    in
    {
      inherit k1 nodes;
      s1 = nodes.t1;
      reg = sel.adapters.registry.mkContext {
        nodes = builtins.attrNames nodes;
        data = id: nodes.${id};
        parent = _: null;
        kindFor = id: kinds.${id};
      };
    };
  marksMsg =
    site:
    "^gen-select: ${site}: two entries share the id_hash '[^']+' but carry kinds with different marks \\('host', 'host'\\); gen-schema mints an entry's id_hash over its kind's mark, so one of these kinds is not its entry's kind\\. Pass each entry's own kind value\\.$";
  kindBlindMsg =
    tag: node:
    "^gen-select: sel\\.${tag} matched against a kind-blind projection \\(node ${node} is entity-backed but __identity\\.kind is null or absent\\)\\. Pass the registry adapter's `kind` argument, supply a `kindFor`, or use a kind-bearing projection\\.$";
  kindFirstMsg =
    got:
    "^gen-select: sel\\.entity expects the entry's kind value first \\(sel\\.entity schema\\.host hosts\\.axon\\): a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`; a kind's identity comes only from the one mint\\); got ${got}\\.$";
in
{
  # den-hoag-l0y (β): `sel.entity kindValue entry`'s admission refusals. Three refusals now share
  # one call site (the kind first, then the entry, then the context), so each cell pins WHICH one
  # fired: a `.success == false` cell passes on whichever argument refuses first. Each carries a
  # live control under `tryEval` in the same cell (the kind-mark group's measured reason).
  flake.testsError.entity-admission = {
    # The kind argument: a name string.
    test-kind-first-string-refused = {
      expr =
        assert decides (sel.entity schema.user entryU);
        sel.entity "user";
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: sel\\.entity expects the entry's kind value first \\(sel\\.entity schema\\.host hosts\\.axon\\), got the string \"user\"\\. A kind name is a reference; pass the kind value\\.$";
      };
    };
    # The kind argument: an entry given where the kind belongs, refused BY NAME at the match (E5).
    # Eager, so it is catchable; a lazily curried form would hand `matches` a function and abort
    # uncatchably.
    test-kind-first-entry-refused = {
      expr =
        assert decides (sel.matches (sel.entity F.kS1 F.s1) "s1" F.reg);
        sel.matches (sel.entity F.s1) "s1" F.reg;
      expectedError = {
        type = "ThrownError";
        msg = kindFirstMsg "an entry";
      };
    };
    # The kind argument: an attrset carrying no mark (and no id_hash).
    test-kind-first-unmarked-refused = {
      expr =
        assert decides (sel.entity schema.user entryU);
        sel.entity { name = "x"; };
      expectedError = {
        type = "ThrownError";
        msg = kindFirstMsg "an attrset with no mark";
      };
    };
    # The entry argument, behind a real kind: a name string.
    test-entry-string-refused = {
      expr =
        assert decides (sel.entity schema.user entryU);
        sel.entity schema.user "axon-01";
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: sel\\.entity expects a registry entry \\(an attrset carrying id_hash\\); got a string\\. Pass the entry value \\(e\\.g\\. den\\.hosts\\.axon-01\\), never a name string\\.$";
      };
    };
    # The entry argument, behind a real kind: an attrset without id_hash.
    test-entry-no-idhash-refused = {
      expr =
        assert decides (sel.entity schema.user entryU);
        sel.entity schema.user { name = "x"; };
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: sel\\.entity expects a registry entry \\(an attrset carrying id_hash\\); got set\\.$";
      };
    };
    # The context: identity-blind (no __identity key). Control: an identity-bearing context answers.
    test-identity-blind-context-refused = {
      expr =
        assert decides (sel.matches (sel.entity schema.user entryU) "s1" F.reg);
        sel.matches (sel.entity schema.user entryU) "anything" identityBlindCtx;
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: sel\\.entity matched against an identity-blind context \\(its `data anything` has no __identity key\\)\\.";
      };
    };
    # The context: a malformed entry whose id_hash throws; the entity arm forces the stamp. Control:
    # `sel.kind` over the same node never reads the entry, and matches.
    test-malformed-entry-refused = {
      expr =
        assert
          let
            control = builtins.tryEval (sel.matches (sel.kind schema.user) "bad" malformedEntryCtx);
          in
          control.success && control.value;
        sel.matches (sel.entity schema.user entryU) "bad" malformedEntryCtx;
      expectedError = {
        type = "ThrownError";
        msg = "^malformed entry: no id_hash$";
      };
    };
    # The context: a scope `entryFor` returning a value without id_hash. Control: `attrs` on the
    # projected `type`, same context and node.
    test-malformed-entryfor-refused = {
      expr =
        assert
          let
            control = builtins.tryEval (
              sel.matches (sel.attrs { type = "host"; }) "host:axon" malformedEntryForCtx
            );
          in
          control.success && control.value;
        sel.matches (sel.entity schema.user { id_hash = "x"; }) "host:axon" malformedEntryForCtx;
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: entryFor returned a value without id_hash for node host:axon; a registry entry must carry id_hash\\.$";
      };
    };
  };

  # den-hoag-l0y (β): the sealed collision, E1–E6. ./tests/entity-sealed.nix pins the decided arms;
  # these pin WHICH refusal fired, since three refusals (sealed components, different marks,
  # kind-blind) can now reach one equal stamp.
  flake.testsError.entity-sealed = {
    # E1 · Controls: the separately evaluated twin refuses (its `note` default is open content,
    # den-hoag-egei0), another instance decides false.
    test-e1-selectorEq-sealed-collision = {
      expr =
        assert
          F.tr (sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS1t F.s1t)) == "REFUSED"
          && F.tr (sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS1 F.s1q)) == false;
        sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS2 F.s2);
      expectedError = {
        type = "ThrownError";
        msg = sealedMsg "selectorEq";
      };
    };
    # E2 · Controls: the entity's own node decides true; its twin's node refuses (den-hoag-egei0).
    test-e2-match-sealed-collision = {
      expr =
        assert
          F.tr (sel.matches (sel.entity F.kS1 F.s1) "s1" F.reg) == true
          && F.tr (sel.matches (sel.entity F.kS1 F.s1) "s1t" F.reg) == "REFUSED";
        sel.matches (sel.entity F.kS1 F.s1) "s2" F.reg;
      expectedError = {
        type = "ThrownError";
        msg = sealedMsg "sel\\.entity";
      };
    };
    # E2s · the selection over the fixture refuses rather than return ["s1" "s1t" "s2"]. It now pins
    # the TWIN refusal: `s1t` is reached before `s2`, and a twin of a declaration carrying open
    # content refuses at its `open.*` path alone (den-hoag-egei0). The type collision this cell was
    # written for is E2s-type's, over a fixture with no open content. Control: the migrated
    # entity's selection decides.
    test-e2s-selection-sealed-collision = {
      expr =
        assert
          F.tr (builtins.filter (id: sel.matches (sel.entity F.kA F.a) id F.reg) (builtins.attrNames F.nodes))
          == [ "a" ];
        builtins.filter (id: sel.matches (sel.entity F.kS1 F.s1) id F.reg) (builtins.attrNames F.nodes);
      expectedError = {
        type = "ThrownError";
        msg = twinMsg "sel\\.entity";
      };
    };
    # E2s-type · the selection over a PURE type collision refuses naming the type alone. Control:
    # the entity's own node and its twin's node decide true, so the refusal is the pair's.
    test-e2s-type-selection-sealed-collision = {
      expr =
        assert
          F.tr (sel.matches (sel.entity T.k1 T.s1) "t1" T.reg) == true
          && F.tr (sel.matches (sel.entity T.k1 T.s1) "t1t" T.reg) == true;
        builtins.filter (id: sel.matches (sel.entity T.k1 T.s1) id T.reg) (builtins.attrNames T.nodes);
      expectedError = {
        type = "ThrownError";
        msg = typeMsg "sel\\.entity";
      };
    };
    # E3 · the registry adapter given no kind. Control: a migrated kind decides on its stamp there.
    test-e3-kind-blind-registry = {
      expr =
        assert F.tr (sel.matches (sel.entity F.kA F.a) "a" F.blind) == true;
        sel.matches (sel.entity F.kS1 F.s1) "s1" F.blind;
      expectedError = {
        type = "ThrownError";
        msg = kindBlindMsg "entity" "s1";
      };
    };
    # E3 · the scope adapter: a node carrying no kind value, its lazy refusal. Control: a migrated
    # kind decides there.
    test-e3-kind-blind-scope = {
      expr =
        assert F.tr (sel.matches (sel.entity F.kA F.a) "a" F.scope) == true;
        sel.matches (sel.entity F.kS1 F.s1) "s1" F.scope;
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: adapters\\.scope\\.mkContext: node s1 \\(type \"host\"\\) carries no kind value; sel\\.kind, and sel\\.entity at a stamp whose kind has sealed components, compare minted kind identities\\. Declare the kind's value on its gen-scope kind \\(`mkKind \\{ kindValue = schema\\.<kind>; }`\\)\\.$";
      };
    };
    # E3 / C-2 · a hand record omitting `kind`: the named kind-blind refusal, never an uncatchable
    # missing-attribute abort. Control: a migrated kind decides there without reading a kind.
    test-e3-no-kind-field = {
      expr =
        assert F.tr (sel.matches (sel.entity F.kA F.a) "a" F.noKindField) == true;
        sel.matches (sel.entity F.kS1 F.s1) "s1" F.noKindField;
      expectedError = {
        type = "ThrownError";
        msg = kindBlindMsg "entity" "s1";
      };
    };
    # C-2's sibling on `sel.kind`, the same door. Control: the kind-bearing context decides.
    test-kind-no-kind-field = {
      expr =
        assert F.tr (sel.matches (sel.kind F.kA) "a" F.reg) == true;
        sel.matches (sel.kind F.kS1) "s1" F.noKindField;
      expectedError = {
        type = "ThrownError";
        msg = kindBlindMsg "kind" "s1";
      };
    };
    # E4 · a kind that is not the entry's kind. Control: the entry's own kind on both sides decides.
    test-e4-wrong-kind = {
      expr =
        assert F.tr (sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS1 F.s1)) == true;
        sel.selectorEq (sel.entity F.kA F.s1) (sel.entity F.kS1 F.s1);
      expectedError = {
        type = "ThrownError";
        msg = marksMsg "selectorEq";
      };
    };
    # E6 · version skew stood in by hand (a node of kind `kA` carrying `s1`'s stamp). Control: the
    # selector decides on its own node.
    test-e6-skew = {
      expr =
        assert F.tr (sel.matches (sel.entity F.kS1 F.s1) "s1" F.reg) == true;
        sel.matches (sel.entity F.kS1 F.s1) "skew" F.skew;
      expectedError = {
        type = "ThrownError";
        msg = marksMsg "sel\\.entity";
      };
    };
  };

  # den-hoag-8hqx0: `adapters.product.coord dim kind entry` at the sealed collision, and the doors
  # around it. ./tests/coord-sealed.nix pins the decided arms; these pin WHICH refusal fired. C1–C3
  # are pinned by the sealed-collision sentence and not by `.success`: a build that dropped the
  # context's kind projection refuses the same three cells under the kind-blind message instead.
  flake.testsError.coord-sealed =
    let
      P = sel.adapters.product;
      coordSealedMsg = sealedMsg "adapters\\.product\\.coord";
      coordKindBlindMsg =
        node:
        "^gen-select: adapters\\.product\\.coord matched against a kind-blind product context \\(dimension 'host' of node ${node} has no kind, and the selector's kind has sealed components\\)\\. Pass adapters\\.product\\.mkContext's `kinds`\\.$";
      handMsg =
        site: tag: carries: ctor:
        "^gen-select: ${site}: a `${tag}` selector record carries ${carries} \\(a hand-built record\\?\\)\\. Build it with ${ctor}\\.$";
      coordCtor = "adapters\\.product\\.coord dim kind entry";
      nodeKindMsg =
        got:
        "^gen-select: adapters\\.product\\.coord matched against a context whose `coordKinds\\.host` is not a kind key \\(\\{ identity; name; sealed; \\}, what adapters\\.product\\.mkContext projects from `kinds`\\); got ${got}\\.$";
      entityCtor = "sel\\.entity kind entry";
      hand = {
        __sel = "coord";
        dim = "host";
        inherit (F.s2) id_hash;
        name = "p";
      };
      handE = removeAttrs hand [ "dim" ] // {
        __sel = "entity";
      };
    in
    {
      # C1 · Controls: the separately evaluated twin refuses (its `note` default is open content,
      # den-hoag-egei0), another instance decides false.
      test-c1-selectorEq-sealed-collision = {
        expr =
          assert
            F.tr (sel.selectorEq (P.coord "host" F.kS1 F.s1) (P.coord "host" F.kS1t F.s1t)) == "REFUSED"
            && F.tr (sel.selectorEq (P.coord "host" F.kS1 F.s1) (P.coord "host" F.kS1 F.s1q)) == false;
          sel.selectorEq (P.coord "host" F.kS1 F.s1) (P.coord "host" F.kS2 F.s2);
        expectedError = {
          type = "ThrownError";
          msg = sealedMsg "selectorEq \\(adapters\\.product\\.coord\\)";
        };
      };
      # C2 · Controls (K2 / X2): the coordinate's own cell decides true on the kind-bearing context.
      test-c2-match-sealed-collision = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prod) == true;
          sel.matches (P.coord "host" F.kS1 F.s1) "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg = coordSealedMsg;
        };
      };
      # C2s · the selection over the space refuses rather than return [ "cs2" ]. Control: the
      # migrated coordinate's selection decides.
      test-c2s-selection-sealed-collision = {
        expr =
          assert
            F.tr (builtins.filter (id: sel.matches (P.coord "host" F.kA F.a) id F.prodA) [ "ca" ]) == [
              "ca"
            ];
          builtins.filter (id: sel.matches (P.coord "host" F.kS1 F.s1) id F.prod) [
            "cs2"
            "cs2z"
          ];
        expectedError = {
          type = "ThrownError";
          msg = coordSealedMsg;
        };
      };
      # C3 · `inSlice` at the pair. Control: the coordinate's own slice decides true.
      test-c3-inSlice-sealed-collision = {
        expr =
          assert
            F.tr (
              sel.matches (P.inSlice {
                host = {
                  kind = F.kS2;
                  entry = F.s2;
                };
              }) "cs2" F.prod
            ) == true;
          sel.matches (P.inSlice {
            host = {
              kind = F.kS1;
              entry = F.s1;
            };
          }) "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg = coordSealedMsg;
        };
      };
      # C4 · a kind-blind context. Control (K4b): a migrated coordinate decides on its stamp there.
      test-c4-kind-blind-context = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kA F.a) "ca" F.prodABlind) == true;
          sel.matches (P.coord "host" F.kS1 F.s1) "cs2" F.prodBlind;
        expectedError = {
          type = "ThrownError";
          msg = coordKindBlindMsg "cs2";
        };
      };
      # X1 · the coordinate's OWN cell on a kind-blind context refuses too: `kinds` is required in
      # effect for a factor of a compared kind. Control (X2): the same match on the kind-bearing one.
      test-x1-own-cell-kind-blind = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prod) == true;
          sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prodBlind;
        expectedError = {
          type = "ThrownError";
          msg = coordKindBlindMsg "cs2";
        };
      };
      # C5 · an entry given where the kind belongs, refused BY NAME at the match (the eager `seq`).
      # Control: the three-argument form decides.
      test-c5-two-argument-form = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prod) == true;
          sel.matches (P.coord "host" F.s2) "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: adapters\\.product\\.coord expects the coordinate's kind value after the dimension \\(coord \"host\" schema\\.host hosts\\.axon\\): a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`; a kind's identity comes only from the one mint\\); got an entry\\.$";
        };
      };
      # CF1 · a bare entry as a dimension's value, `inSlice { <dim> = entry; }`, refused BY NAME where
      # the conjunct is forced (it used to hand `matches` a lambda, an uncatchable abort). Control:
      # the kind-bearing form.
      test-cf1-inSlice-bare-entry = {
        expr =
          assert
            F.tr (
              sel.matches (P.inSlice {
                host = {
                  kind = F.kS2;
                  entry = F.s2;
                };
              }) "cs2" F.prod
            ) == true;
          sel.matches (P.inSlice { host = F.s2; }) "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: adapters\\.product\\.inSlice expects \\{ <dim> = \\{ kind; entry; \\}; \\} \\(inSlice \\{ host = \\{ kind = schema\\.host; entry = hosts\\.axon; \\}; \\}\\); dimension 'host' got an entry\\.$";
        };
      };
      # X5 · `kinds` naming a kind by its NAME. Control: a migrated coordinate reads no node kind.
      test-x5-kinds-name-refused = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kA F.s2) "cs2" F.prodKindName) == true;
          sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prodKindName;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: adapters\\.product\\.mkContext `kinds\\.host` expects a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`; a kind's identity comes only from the one mint\\); got the kind name \"host\"\\.$";
        };
      };
      # C7 / CF2 · hand-built records at an equal stamp, one cell per arm and per malformation. The
      # shared control: the same record at a different stamp decides false without reading a kind.
      test-c7-coord-no-kind-match = {
        expr =
          assert F.tr (sel.selectorEq hand (hand // { id_hash = "z"; })) == false;
          sel.matches hand "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg = handMsg "adapters\\.product\\.coord" "coord" "no `kind`" coordCtor;
        };
      };
      test-c7-coord-no-kind-selectorEq = {
        expr =
          assert F.tr (sel.selectorEq hand (hand // { id_hash = "z"; })) == false;
          sel.selectorEq hand hand;
        expectedError = {
          type = "ThrownError";
          msg = handMsg "selectorEq \\(adapters\\.product\\.coord\\)" "coord" "no `kind`" coordCtor;
        };
      };
      test-cf2-coord-kind-name-match = {
        expr =
          assert F.tr (sel.selectorEq hand (hand // { id_hash = "z"; })) == false;
          sel.matches (hand // { kind = "host"; }) "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg = handMsg "adapters\\.product\\.coord" "coord" "the kind name \"host\" as its `kind`" coordCtor;
        };
      };
      test-cf2-coord-kind-no-sealed-match = {
        expr =
          assert F.tr (sel.selectorEq hand (hand // { id_hash = "z"; })) == false;
          sel.matches (
            hand
            // {
              kind = {
                identity = "m";
                name = "host";
              };
            }
          ) "cs2" F.prod;
        expectedError = {
          type = "ThrownError";
          msg =
            handMsg "adapters\\.product\\.coord" "coord"
              "a `kind` that is not a kind key \\(\\{ identity; name; sealed; \\}\\); got set"
              coordCtor;
        };
      };
      # H4 / H7 · the same guard on `sel.entity`'s two arms. Control: a real entity selector decides.
      test-cf2-entity-no-kind-match = {
        expr =
          assert F.tr (sel.matches (sel.entity F.kS2 F.s2) "s2" F.reg) == true;
          sel.matches handE "s2" F.reg;
        expectedError = {
          type = "ThrownError";
          msg = handMsg "sel\\.entity" "entity" "no `kind`" entityCtor;
        };
      };
      test-cf2-entity-no-kind-selectorEq = {
        expr =
          assert F.tr (sel.selectorEq (sel.entity F.kS2 F.s2) (sel.entity F.kS2 F.s2)) == true;
          sel.selectorEq handE handE;
        expectedError = {
          type = "ThrownError";
          msg = handMsg "selectorEq" "entity" "no `kind`" entityCtor;
        };
      };
      # CL-1 · the NODE side: a hand-built context whose `coordKinds.host` is not a kind key, read at an
      # equal stamp whose selector kind is sealed. Without the guard both arms abort uncatchably (a kind
      # NAME: `expected a set but found a string`; a key without `sealed`: at `inherit (a) name sealed`).
      # Control: the same match on the context `mkContext` built decides true.
      test-cl1-node-kind-name = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prod) == true;
          sel.matches (P.coord "host" F.kS2 F.s2) "cs2" (F.prod // { coordKinds.host = "host"; });
        expectedError = {
          type = "ThrownError";
          msg = nodeKindMsg "string";
        };
      };
      test-cl1-node-kind-no-sealed = {
        expr =
          assert F.tr (sel.matches (P.coord "host" F.kS2 F.s2) "cs2" F.prod) == true;
          sel.matches (P.coord "host" F.kS2 F.s2) "cs2" (
            F.prod
            // {
              coordKinds.host = {
                identity = F.kS2.__mint.minted;
                name = "host";
              };
            }
          );
        expectedError = {
          type = "ThrownError";
          msg = nodeKindMsg "set";
        };
      };
    };

  # THE PROVENANCE MARK's refusals (ADR-0034). Message cells, because at HEAD these same two
  # expressions SUCCEEDED: a `.success == false` cell would have been red for the right reason and
  # green for the wrong one the moment any refusal appeared. What must hold is that the message
  # names the mark, which is now the thing the guard actually reads.
  flake.testsError.kind-mark = {
    # den-hoag-1a4f6 K1 · a kind value with a mark and no completion stamp is refused by name at the
    # selector, as gen-schema's `kindEq` refuses it. Control: the stamped kind decides `true`.
    test-stampless-kind-refused-at-the-selector = {
      expr =
        assert
          let
            control = builtins.tryEval (sel.selectorEq (sel.kind schema.user) (sel.kind schema.user));
          in
          control.success && control.value;
        sel.selectorEq (sel.kind (removeAttrs schema.user [ "__kindSelf" ])) (
          sel.kind (removeAttrs schema.user [ "__kindSelf" ])
        );
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: the kind value 'user' carries a mark but no completion stamp \\(`__kindSelf`\\), so nothing ties the mark to this value, as gen-schema's own `kindEq` refuses it\\. Take the kind from a gen-schema that stamps it\\.$";
      };
    };

    test-hand-written-stand-in-refused = {
      expr =
        # ★ LIVE CONTROL, same cell and same run — and it is wrapped in `tryEval` for a reason
        # that was MEASURED rather than assumed. The bare form `assert (sel.kind schema.user) ==
        # …;` does NOT discriminate: when the control refuses, its throw IS this cell's pinned
        # message, so a guard that refused everything passed this cell perfectly. Driven: with the
        # predicate seeded `&& false`, the bare form scored 4/4 green. `tryEval` converts the
        # control's refusal into an `assertion failed`, which matches neither the type nor the
        # message below, so the cell reds.
        assert
          let
            control = builtins.tryEval (sel.kind schema.user);
          in
          control.success && control.value.identity == schema.user.__mint.minted;
        sel.kind standIn;
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: sel\\.kind expects a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`; a kind's identity comes only from the one mint\\); got an attrset with no mark\\. A hand-written `\\{ kind = \\.\\.\\.; options = \\.\\.\\.; \\}` is not a kind value — take the kind from a schema \\(e\\.g\\. `schema\\.widget`\\)\\.$";
      };
    };

    # The adapter's `kind` argument is the SECOND admission point in this library and it fails
    # differently: `mkContext` seqs `validatedKind` to WHNF, so a malformed argument throws as soon
    # as the context is used rather than at the first match. At HEAD that seq passed on the
    # stand-in and the context was built.
    test-registry-context-refuses-an-unmarked-kind = {
      expr =
        let
          mk =
            k:
            sel.adapters.registry.mkContext {
              nodes = [ "n1" ];
              data = _: { };
              parent = _: null;
              kind = k;
            };
        in
        # Same live control, same `tryEval` shape and for the same measured reason.
        assert
          let
            control = builtins.tryEval ((mk schema.user).children "n1");
          in
          control.success && control.value == [ ];
        (mk standIn).children "n1";
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: adapters\\.registry\\.mkContext `kind` expects a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`; a kind's identity comes only from the one mint\\); got an attrset with no mark\\. A hand-written `\\{ kind = \\.\\.\\.; options = \\.\\.\\.; \\}` is not a kind value — take the kind from a schema \\(e\\.g\\. `schema\\.widget`\\)\\.$";
      };
    };
  };

  # den-hoag-l0y: kinds are keyed by MINTED identity. Each cell pins WHICH refusal fired, and each
  # carries a live control under `tryEval` in the same cell (the kind-mark group's measured reason:
  # a bare control whose own refusal matched the pinned message would pass a door that refused
  # everything).
  flake.testsError.kind-identity = {
    # C1s · a sealed collision is refused BY NAME at `selectorEq`, as gen-schema's `kindEq` refuses
    # it. Controls: the sealed twin decides `true`, the migrated pair decides `false`.
    test-selectorEq-sealed-collision-refused = {
      expr =
        assert
          let
            twin = builtins.tryEval (sel.selectorEq (sel.kind kS) (sel.kind kS2));
            migrated = builtins.tryEval (sel.selectorEq (sel.kind kS) (sel.kind kG));
          in
          twin.success && twin.value && migrated.success && !migrated.value;
        sel.selectorEq (sel.kind kS) (sel.kind kI);
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: selectorEq: two declarations of 'host' mint one identity and are unequal only at sealed component\\(s\\) 'options\\.addr\\.type': a sealed component is compared by its seal, the whole value under Nix `==`, where two separately built functions are never equal, so two separate constructions are refused even where the values they compute are equal; a sealed component has no identity, because identity is minted from inert structure alone";
      };
    };

    # C3 · a bare-name `kindFor` is a reference the adapter cannot resolve before the shared
    # resolver lands. Control: a kind-value `kindFor` over the same data answers.
    test-bare-name-kindfor-refused = {
      expr =
        assert
          let
            control = builtins.tryEval (sel.matches (sel.kind kG) "axon" (registryCtx (_: kG)));
          in
          control.success && control.value;
        sel.matches (sel.kind kG) "axon" (registryCtx (_: "host"));
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: adapters\\.registry\\.mkContext `kindFor` returned the kind name \"host\"; a kind name is a reference, and resolving it to its declaration needs the shared resolver\\. Return the kind value\\.$";
      };
    };

    # C4 / c5 · `sel.kind` over a scope node carrying no kind value refuses by name, and never
    # compares its positional `type` (a name, not a kind declaration). Control: `attrs` on the
    # projected `type`, same context and node.
    test-scope-kind-refused = {
      expr =
        assert
          let
            control = builtins.tryEval (sel.matches (sel.attrs { type = "host"; }) "n1" scopeCtx);
          in
          control.success && control.value;
        sel.matches (sel.kind kG) "n1" scopeCtx;
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: adapters\\.scope\\.mkContext: node n1 \\(type \"host\"\\) carries no kind value; sel\\.kind, and sel\\.entity at a stamp whose kind has sealed components, compare minted kind identities\\. Declare the kind's value on its gen-scope kind \\(`mkKind \\{ kindValue = schema\\.<kind>; }`\\)\\.$";
      };
    };

    # A node carrying a `kindValue` with no mint (the hand-written stand-in) is refused by that
    # name, never matched. Control: the same node carrying the minted value matches.
    test-scope-markless-kind-value-refused = {
      expr =
        let
          ctxWith =
            v:
            sel.adapters.scope.mkContext {
              node = _: {
                id = "n1";
                type = "host";
                parent = null;
                id_hash = "h-n1";
                kindValue = v;
              };
              get = _: _: [ ];
            };
        in
        assert F.tr (sel.matches (sel.kind kG) "n1" (ctxWith kG)) == true;
        sel.matches (sel.kind kG) "n1" (ctxWith {
          kind = "host";
          options = { };
        });
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: adapters\\.scope\\.mkContext: node n1 carries a `kindValue` with no mint-backed mark \\(`__mint\\.minted`; a kind's identity comes only from the one mint\\); a hand-written `\\{ kind = \\.\\.\\.; \\.\\.\\. }` is not a kind value\\.$";
      };
    };

    # A hand projection still carrying a kind NAME is refused, never compared against a minted
    # identity (which would never match: the A1 silent never-match). Control: the same node with
    # the kind's key projected matches.
    test-name-projection-refused = {
      expr =
        let
          ctxWith = k: {
            data = _: {
              __identity = {
                id_hash = "h";
                kind = k;
              };
            };
          };
        in
        assert
          let
            control = builtins.tryEval (
              sel.matches (sel.kind kG) "n1" (ctxWith (removeAttrs (sel.kind kG) [ "__sel" ]))
            );
          in
          control.success && control.value;
        sel.matches (sel.kind kG) "n1" (ctxWith "host");
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: sel\\.kind matched against a projection whose __identity\\.kind for node n1 is the kind name \"host\"; a kind name is a reference, not a kind declaration\\.";
      };
    };
  };

  flake.testsError.adapter-totality = {
    # PF-a (den-hoag-8hqx0 landing gate) · `coordsFor` returning a non-attrset, reached THROUGH the
    # matcher with a well-formed three-argument coord: pinned by the context door's message, so a throw
    # from anywhere else (the kind-position refusal, say) cannot pass it. Control: the
    # same selector over a well-formed context decides.
    test-coordsfor-wrong-return-throws-through-match =
      let
        kHost =
          (genSchema.evalSchema { } [
            { config.schema.host.options.addr = genMerge.mkOption { type = genMerge.types.str; }; }
          ]).host;
        s = sel.adapters.product.coord "host" kHost { id_hash = "h1"; };
        mk =
          coordsFor:
          sel.adapters.product.mkContext {
            nodeIds = [ "c1" ];
            inherit coordsFor;
          };
      in
      {
        expr =
          assert sel.matches s "c1" (
            mk (_: {
              host.id_hash = "h1";
            })
          );
          sel.matches s "c1" (mk (_: "oops-a-string"));
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: adapters\\.product\\.mkContext's `coordsFor` must return an attrset of dimension -> registry-entry for cell c1; got string \\(an under-applied coordsFor returns a function here\\)\\.$";
        };
      };
    test-entryfor-pattern-formal-uncatchable = {
      expr =
        let
          ctx = sel.adapters.scope.mkContext {
            node = _: {
              id = "n1";
              type = "x";
              parent = null;
              decls = { };
            };
            get = _: _: throw "get unused in this test";
            entryFor = { id }: null; # closed-pattern formal — arity erased, un-closable
          };
        in
        (ctx.data "n1").__identity;
      expectedError = {
        type = "TypeError";
        msg = "expected a set but found a string: \"n1\"";
      };
    };

    test-coordsfor-pattern-formal-uncatchable = {
      expr =
        let
          ctx = sel.adapters.product.mkContext {
            nodeIds = [ "c1" ];
            coordsFor =
              { id }:
              {
                host = {
                  id_hash = "h1";
                };
              }; # closed-pattern formal
          };
        in
        (ctx.data "c1").__coords;
      expectedError = {
        type = "TypeError";
        msg = "expected a set but found a string: \"c1\"";
      };
    };
  };

  # P2, R7 (b): `child` / `descendant` take one record, and a missing field (absent or misspelt) or a
  # stale positional call is refused BY NAME, catchably. Each cell carries a live control: the
  # well-formed record constructs under `tryEval` in the same cell.
  flake.testsError.record-doors =
    let
      s = sel.star;
      ok = v: (builtins.tryEval (builtins.seq v true)).success;
      childOk = ok (
        sel.child {
          parent = s;
          child = s;
        }
      );
      descOk = ok (
        sel.descendant {
          ancestor = s;
          descendant = s;
        }
      );
      missing =
        door: f: req:
        "^gen-select\\.${door}: required field '${f}' is missing \\(required: ${req}\\) \\(in gen-select\\.checkRequired\\)$";
      notInt =
        door: req:
        "^gen-select\\.${door}: the argument must be an attrset, not a int \\(required: ${req}\\) \\(in gen-select\\.checkRequired\\)$";
    in
    {
      test-child-missing-field-refused = {
        expr =
          assert childOk;
          sel.child { parent = s; };
        expectedError = {
          type = "ThrownError";
          msg = missing "child" "child" "'parent', 'child'";
        };
      };
      test-child-misspelt-field-refused = {
        expr =
          assert childOk;
          sel.child {
            parent = s;
            chlid = s;
          };
        expectedError = {
          type = "ThrownError";
          msg = missing "child" "child" "'parent', 'child'";
        };
      };
      test-child-stale-positional-refused = {
        expr =
          assert childOk;
          sel.child 1;
        expectedError = {
          type = "ThrownError";
          msg = notInt "child" "'parent', 'child'";
        };
      };
      test-descendant-missing-field-refused = {
        expr =
          assert descOk;
          sel.descendant { ancestor = s; };
        expectedError = {
          type = "ThrownError";
          msg = missing "descendant" "descendant" "'ancestor', 'descendant'";
        };
      };
      test-descendant-misspelt-field-refused = {
        expr =
          assert descOk;
          sel.descendant {
            ancestor = s;
            descendent = s;
          };
        expectedError = {
          type = "ThrownError";
          msg = missing "descendant" "descendant" "'ancestor', 'descendant'";
        };
      };
      test-descendant-stale-positional-refused = {
        expr =
          assert descOk;
          sel.descendant 1;
        expectedError = {
          type = "ThrownError";
          msg = notInt "descendant" "'ancestor', 'descendant'";
        };
      };
    };

  # den-hoag-l0y U3: `sel.subkind`'s refusals, each pinning WHICH refusal fired, each with a live
  # control under `tryEval` in the same cell (the kind-mark group's measured reason).
  flake.testsError.subkind =
    let
      T = genMerge.types;
      tree =
        modules:
        (genMerge.evalModuleTree { } ([ { options.schema = genSchema.mkSchemaOption { }; } ] ++ modules))
        .config.schema;
      fwOf =
        _:
        tree [
          {
            config.schema.base.options.b = genMerge.mkOption {
              type = T.int;
              default = 0;
            };
          }
        ];
      V = (fwOf 1).base;
      twin = (fwOf 2).base;
      childOf =
        parent:
        (tree [
          {
            config.schema.sub = {
              inherits = [ parent ];
              options.extra = genMerge.mkOption { type = T.int; };
            };
          }
        ]).sub;
      kinds = {
        s = childOf V;
        o = childOf twin;
      };
      ctx = sel.adapters.registry.mkContext {
        nodes = builtins.attrNames kinds;
        data = id: { id_hash = "h-${id}"; };
        parent = _: null;
        kindFor = id: kinds.${id};
      };
      # a hand projection of the subkind's key with no ancestor map
      noMapCtx = {
        data = _: {
          __identity = {
            id_hash = "h-s";
            kind = removeAttrs ((ctx.data "s").__identity.kind) [ "ancestors" ];
          };
        };
        parent = _: null;
      };
      ok =
        e: v:
        (builtins.tryEval (builtins.deepSeq e e)) == {
          success = true;
          value = v;
        };
    in
    {
      # N1 / F14-4 · an open-content twin in the lineage is refused by `kindEq`'s own text at the
      # match. Control: the subkind of the selector's own kind matches.
      test-open-content-twin-in-lineage-refused-by-name = {
        expr =
          assert ok (sel.matches (sel.subkind V) "s" ctx) true;
          sel.matches (sel.subkind V) "o" ctx;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: sel\\.subkind: two declarations of 'base' mint one identity and are unequal only at sealed component\\(s\\) 'open\\.options\\.b\\.default'";
        };
      };

      # SEL · `selectorEq` refuses two subkind selectors over open-content twins by name, as the
      # `kind` arm does. Control: one kind value with itself decides `true`.
      test-selectorEq-subkind-open-twin-refused-by-name = {
        expr =
          assert ok (sel.selectorEq (sel.subkind V) (sel.subkind V)) true;
          sel.selectorEq (sel.subkind V) (sel.subkind twin);
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: selectorEq: two declarations of 'base' mint one identity and are unequal only at sealed component\\(s\\) 'open\\.options\\.b\\.default'";
        };
      };

      # S6 / P3 · a projected kind key carrying no ancestor map is refused by name, never `false`
      # and never an abort. Control: the adapter's own projection of the same node answers.
      test-projection-without-ancestor-map-refused = {
        expr =
          assert ok (sel.matches (sel.subkind V) "s" ctx) true;
          sel.matches (sel.subkind V) "n" noMapCtx;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: sel\\.subkind matched against a projection whose __identity\\.kind for node n carries no ancestor map \\(`ancestors`, gen-schema's `__kindAncestors`\\), so whether the node's kind is a subkind cannot be answered\\.";
        };
      };

      # The door is `sel.kind`'s: a kind NAME is refused under the operator's own name. Control: the
      # kind value constructs.
      test-subkind-kind-name-refused = {
        expr =
          assert ok (sel.subkind V).__sel "subkind";
          sel.subkind "base";
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select: sel\\.subkind expects a kind value \\(e\\.g\\. schema\\.user\\), got the string \"base\"\\.";
        };
      };
    };

  # den-hoag-7gp66 row 13 (R10 rule 2): `matches` refuses a non-selector by name, catchably, naming
  # the door. Control: the same context answers a real selector.
  flake.testsError.grammar-renames =
    let
      ctx = {
        data = id: { type = id; };
        parent = _: null;
        children = _: [ ];
        ancestors = _: [ ];
        siblings = _: [ ];
      };
    in
    {
      test-matches-names-the-door-for-a-callable = {
        expr =
          assert sel.matches sel.star "a" ctx;
          sel.matches builtins.any "a" ctx;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select\\.matches: got lambda, expected a selector \\(a record built by gen-select's constructors\\)$";
        };
      };
      test-matches-names-the-door-for-a-set = {
        expr =
          assert sel.matches sel.star "a" ctx;
          sel.matches genMerge.types.attrs "a" ctx;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-select\\.matches: got set with no `__sel`, expected a selector";
        };
      };
    };
}
