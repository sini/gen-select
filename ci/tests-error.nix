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
in
{
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
        msg = "^gen-select: adapters\\.scope\\.mkContext: node n1 has the positional type \"host\", which is a name and not a kind declaration; sel\\.kind compares minted kind identities and cannot match it \\(den-hoag-l0y\\)\\.$";
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
