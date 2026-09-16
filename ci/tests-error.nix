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
{ genSelect, ... }:
let
  sel = genSelect;
in
{
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
