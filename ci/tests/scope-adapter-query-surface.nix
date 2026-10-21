# THE SCOPE ADAPTER READS gen-scope's QUERY SURFACE (den-hoag-5lgmi). `children` and `siblings` are
# the scope's ordered child relation as `genScope.childrenIds` answers it: the selected, spawned and
# `nta` halves, in production order. The `children` attribute alone is the selected half, a node set
# the evaluator does not materialize, and its names' order is not the production order.
#
# Host `h` holds a selected `z:sel`, two spawned children written `s:z` before `s:a`, and one `nta`
# child. Every cell runs beside its control: the same builder through `listToAttrs` reads the names'
# order, so a context answering a constant fails one arm or the other.
{ genSelect, genScope, ... }:
let
  sel = genSelect;
  inherit (genScope) mkKind mkKinds buildRoots;
  evWith =
    form:
    let
      scope = buildRoots {
        kinds = mkKinds [
          (mkKind { } "member")
          (mkKind { } "leaf")
          (mkKind {
            below = [
              "member"
              "leaf"
            ];
            spawns.leaf =
              _: id:
              form (
                if id == "h" then
                  [
                    {
                      name = "s:z";
                      value = { };
                    }
                    {
                      name = "s:a";
                      value = { };
                    }
                  ]
                else
                  [ ]
              );
            nta.sub = _: id: if id == "h" then { g.k1 = [ ]; } else { };
          } "host")
        ];
        parentGraph = genScope.edge {
          from = "z:sel";
          to = "h";
        };
        importGraph = genScope.empty;
        decls = {
          h = { };
          "z:sel" = { };
        };
        types = {
          h = "host";
          "z:sel" = "member";
        };
      };
    in
    genScope.eval { } {
      imports = _: _: [ ];
      children = _: id: if id == "h" then { "z:sel" = scope.nodes."z:sel"; } else { };
    } scope;
  kid = genScope.mintNtaId {
    host = "h";
    name = "sub";
    group = "g";
    key = "k1";
  };
  reads =
    ev:
    let
      ctx = sel.adapters.scope.mkContext {
        inherit (ev) node;
        childrenIds = genScope.childrenIds ev;
      };
    in
    {
      children = ctx.children "h";
      siblingsOfSpawned = ctx.siblings "s:a";
      siblingsOfNta = ctx.siblings kid;
      siblingsOfRoot = ctx.siblings "h";
      siblingsOfSelected = ctx.siblings "z:sel";
      hasLeaf = sel.matches (sel.has (sel.attrs { type = "leaf"; })) "h" ctx;
      hasHost = sel.matches (sel.has (sel.attrs { type = "host"; })) "h" ctx;
      reference = {
        children = genScope.childrenIds ev "h";
        siblingsOfSpawned = genScope.siblings ev "s:a";
        siblingsOfNta = genScope.siblings ev kid;
        siblingsOfRoot = genScope.siblings ev "h";
        siblingsOfSelected = genScope.siblings ev "z:sel";
      };
    };
  production = reads (evWith (xs: xs));
  names = reads (evWith builtins.listToAttrs);
in
{
  flake.tests.scope-adapter-query-surface = {
    test-spawned-and-nta-children-appear-in-production-order = {
      expr = production.children;
      expected = [
        "z:sel"
        "s:z"
        "s:a"
        kid
      ];
    };
    # Control: the same builder through `listToAttrs` reads the names' order.
    test-control-an-attribute-set-builder-reads-in-name-order = {
      expr = names.children;
      expected = [
        "z:sel"
        "s:a"
        "s:z"
        kid
      ];
    };
    test-siblings-of-a-spawned-and-an-nta-child = {
      expr = {
        inherit (production)
          siblingsOfSpawned
          siblingsOfNta
          siblingsOfRoot
          siblingsOfSelected
          ;
      };
      expected = {
        siblingsOfRoot = [ ];
        siblingsOfSelected = [
          "s:z"
          "s:a"
          kid
        ];
        siblingsOfSpawned = [
          "z:sel"
          "s:z"
          kid
        ];
        siblingsOfNta = [
          "z:sel"
          "s:z"
          "s:a"
        ];
      };
    };
    # The context answers what gen-scope's own query surface answers, in both producer forms.
    test-the-context-is-the-query-surface = {
      expr =
        map
          (r: {
            inherit (r)
              children
              siblingsOfSpawned
              siblingsOfNta
              siblingsOfRoot
              siblingsOfSelected
              ;
          })
          [
            production
            names
          ];
      expected = map (r: r.reference) [
        production
        names
      ];
    };
    # `has` reads `children`: a spawned `leaf` and an `nta` `host` child each satisfy it.
    test-has-reaches-a-spawned-and-an-nta-child = {
      expr = {
        inherit (production) hasLeaf hasHost;
      };
      expected = {
        hasLeaf = true;
        hasHost = true;
      };
    };
  };
}
