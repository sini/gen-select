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
  schema = genSchema.evalSchema {
    modules = [
      { config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; }; }
    ];
  };

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
  mkHost = d: (genSchema.evalSchema { modules = [ { config.schema.host.options = d; } ]; }).host;
  kS = mkHost { addr = genMerge.mkOption { type = lib.types.str; }; };
  kI = mkHost { addr = genMerge.mkOption { type = lib.types.int; }; };
  kS2 = mkHost { addr = genMerge.mkOption { type = lib.types.str; }; };
  kG = mkHost { addr = genMerge.mkOption { type = genMerge.types.str; }; };
  instances = genMerge.evalModuleTree {
    modules = [
      {
        options.hs = genSchema.mkInstanceRegistry kG { };
        config.hs.axon.addr = "10.0.0.1";
      }
    ];
  };
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
  sealedMsg =
    site:
    "^gen-select: ${site}: two declarations of 'host' mint one identity and differ, compared as values, only at sealed component\\(s\\) 'options\\.note\\.type'; a sealed component has no identity \\(ADR-0034\\)";
  marksMsg =
    site:
    "^gen-select: ${site}: two entries share the id_hash '[^']+' but carry kinds with different marks \\('host', 'host'\\); gen-schema mints an entry's id_hash over its kind's mark, so one of these kinds is not its entry's kind\\. Pass each entry's own kind value\\.$";
  kindBlindMsg =
    tag: node:
    "^gen-select: sel\\.${tag} matched against a kind-blind projection \\(node ${node} is entity-backed but __identity\\.kind is null or absent\\)\\. Pass the registry adapter's `kind` argument, supply a `kindFor`, or use a kind-bearing projection\\.$";
  kindFirstMsg =
    got:
    "^gen-select: sel\\.entity expects the entry's kind value first \\(sel\\.entity schema\\.host hosts\\.axon\\): a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`, ADR-0034\\); got ${got}\\.$";
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
    # The kind argument: the retired one-argument form, refused BY NAME at the match (E5). Eager, so
    # it is catchable; a lazily curried form would hand `matches` a function and abort uncatchably.
    test-kind-first-entry-refused = {
      expr =
        assert decides (sel.matches (sel.entity F.kS1 F.s1) "s1" F.reg);
        sel.matches (sel.entity F.s1) "s1" F.reg;
      expectedError = {
        type = "ThrownError";
        msg = kindFirstMsg "an entry \\(the one-argument form is retired: the entry's kind decides a sealed collision\\)";
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
    # E1 · Controls: the separately evaluated twin decides true, another instance false.
    test-e1-selectorEq-sealed-collision = {
      expr =
        assert
          F.tr (sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS1t F.s1t)) == true
          && F.tr (sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS1 F.s1q)) == false;
        sel.selectorEq (sel.entity F.kS1 F.s1) (sel.entity F.kS2 F.s2);
      expectedError = {
        type = "ThrownError";
        msg = sealedMsg "selectorEq";
      };
    };
    # E2 · Controls: the entity's own node and its twin's node decide true.
    test-e2-match-sealed-collision = {
      expr =
        assert
          F.tr (sel.matches (sel.entity F.kS1 F.s1) "s1" F.reg) == true
          && F.tr (sel.matches (sel.entity F.kS1 F.s1) "s1t" F.reg) == true;
        sel.matches (sel.entity F.kS1 F.s1) "s2" F.reg;
      expectedError = {
        type = "ThrownError";
        msg = sealedMsg "sel\\.entity";
      };
    };
    # E2s · the selection over the fixture refuses rather than return ["s1" "s1t" "s2"]. Control:
    # the migrated entity's selection decides.
    test-e2s-selection-sealed-collision = {
      expr =
        assert
          F.tr (builtins.filter (id: sel.matches (sel.entity F.kA F.a) id F.reg) (builtins.attrNames F.nodes))
          == [ "a" ];
        builtins.filter (id: sel.matches (sel.entity F.kS1 F.s1) id F.reg) (builtins.attrNames F.nodes);
      expectedError = {
        type = "ThrownError";
        msg = sealedMsg "sel\\.entity";
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
    # E3 · the scope adapter: its lazy kind refusal. Control: a migrated kind decides there.
    test-e3-kind-blind-scope = {
      expr =
        assert F.tr (sel.matches (sel.entity F.kA F.a) "a" F.scope) == true;
        sel.matches (sel.entity F.kS1 F.s1) "s1" F.scope;
      expectedError = {
        type = "ThrownError";
        msg = "^gen-select: adapters\\.scope\\.mkContext: node s1 has the positional type \"host\", which is a name and not a kind declaration; sel\\.kind, and sel\\.entity at a stamp whose kind has sealed components, compare minted kind identities and cannot match it \\(den-hoag-l0y\\)\\.$";
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

  # THE PROVENANCE MARK's refusals (ADR-0034). Message cells, because at HEAD these same two
  # expressions SUCCEEDED: a `.success == false` cell would have been red for the right reason and
  # green for the wrong one the moment any refusal appeared. What must hold is that the message
  # names the mark, which is now the thing the guard actually reads.
  flake.testsError.kind-mark = {
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
        msg = "^gen-select: sel\\.kind expects a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`, ADR-0034\\); got an attrset with no mark\\. A hand-written `\\{ kind = \\.\\.\\.; options = \\.\\.\\.; \\}` is not a kind value — take the kind from a schema \\(e\\.g\\. `schema\\.widget`\\)\\.$";
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
        msg = "^gen-select: adapters\\.registry\\.mkContext `kind` expects a gen-schema kind value carrying a mint-backed mark \\(`__mint\\.minted`, ADR-0034\\); got an attrset with no mark\\. A hand-written `\\{ kind = \\.\\.\\.; options = \\.\\.\\.; \\}` is not a kind value — take the kind from a schema \\(e\\.g\\. `schema\\.widget`\\)\\.$";
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
        msg = "^gen-select: selectorEq: two declarations of 'host' mint one identity and differ, compared as values, only at sealed component\\(s\\) 'options\\.addr\\.type'; a sealed component has no identity \\(ADR-0034\\)";
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
        msg = "^gen-select: adapters\\.registry\\.mkContext `kindFor` returned the kind name \"host\"; a kind name is a reference, and resolving it to its declaration needs the shared resolver \\(den-hoag-7gp66 P1\\)\\. Return the kind value\\.$";
      };
    };

    # C4 · `sel.kind` over the scope adapter refuses by name (a positional type is a name, not a
    # kind declaration). Control: `attrs` on the projected `type`, same context and node.
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
        msg = "^gen-select: adapters\\.scope\\.mkContext: node n1 has the positional type \"host\", which is a name and not a kind declaration; sel\\.kind, and sel\\.entity at a stamp whose kind has sealed components, compare minted kind identities and cannot match it \\(den-hoag-l0y\\)\\.$";
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
            cellIds = [ "c1" ];
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
}
