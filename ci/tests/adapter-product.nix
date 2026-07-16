# P1 (coordinate matching), P2 (slice conjunction), P3 (coordinate-blind loud; missing
# dims quiet), plus coord construction (E3-analog) and coord equality (E7). Mock entries
# as coordinates — sel.coord reads only id_hash + name.
{ genSelect, ... }:
let
  sel = genSelect;
  P = sel.adapters.product;

  h1 = {
    id_hash = "h-axon";
    name = "axon";
  };
  h2 = {
    id_hash = "h-blade";
    name = "blade";
  };
  u1 = {
    id_hash = "u-sini";
    name = "sini";
  };
  u2 = {
    id_hash = "u-vic";
    name = "vic";
  };

  # 2x2 host x user cell set.
  coordMap = {
    c11 = {
      host = h1;
      user = u1;
    };
    c12 = {
      host = h1;
      user = u2;
    };
    c21 = {
      host = h2;
      user = u1;
    };
    c22 = {
      host = h2;
      user = u2;
    };
  };
  cellIds = builtins.attrNames coordMap;
  ctx = P.mkContext {
    inherit cellIds;
    coordsFor = id: coordMap.${id};
  };
  matchCells = selector: builtins.filter (id: sel.matches selector id ctx) cellIds;
  sortStr = builtins.sort (a: b: a < b);

  # Heterogeneous cell missing the user dimension.
  hetCtx = P.mkContext {
    cellIds = [ "x" ];
    coordsFor = _: { host = h1; };
  };
  # Coordinate-blind context (no __coords projected).
  blindCtx = {
    data = _: { };
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };
  # Malformed coordinate value (no id_hash).
  badCtx = P.mkContext {
    cellIds = [ "b" ];
    coordsFor = _: {
      host = {
        name = "nope";
      };
    };
  };

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  flake.tests.adapter-product = {
    # ---- P1 ----
    test-coord-hit = {
      expr = sel.matches (P.coord "host" h1) "c11" ctx;
      expected = true;
    };
    test-coord-miss = {
      expr = sel.matches (P.coord "host" h2) "c11" ctx;
      expected = false;
    };
    test-coord-user-dim = {
      expr = sel.matches (P.coord "user" u1) "c11" ctx;
      expected = true;
    };

    # ---- P2 ----
    test-inslice-row = {
      expr = sortStr (matchCells (P.inSlice { host = h1; }));
      expected = [
        "c11"
        "c12"
      ];
    };
    test-inslice-single-cell = {
      expr = matchCells (
        P.inSlice {
          host = h1;
          user = u2;
        }
      );
      expected = [ "c12" ];
    };
    test-inslice-empty-all = {
      expr = builtins.length (matchCells (P.inSlice { }));
      expected = 4;
    };
    test-inslice-eq-hand-written-and = {
      # Construction-time sugar: structurally equal to the hand-written conjunction.
      expr = (P.inSlice { host = h1; }) == (sel.and [ (P.coord "host" h1) ]);
      expected = true;
    };

    # ---- P3 ----
    test-coord-blind-throws = {
      expr = throws (sel.matches (P.coord "host" h1) "z" blindCtx);
      expected = true;
    };
    test-missing-dim-false = {
      expr = sel.matches (P.coord "user" u1) "x" hetCtx;
      expected = false;
    };
    test-present-dim-het = {
      expr = sel.matches (P.coord "host" h1) "x" hetCtx;
      expected = true;
    };
    test-malformed-coord-throws = {
      expr = throws (sel.matches (P.coord "host" h1) "b" badCtx);
      expected = true;
    };

    # ---- coord construction ----
    test-coord-string-throws = {
      expr = throws (P.coord "host" "axon");
      expected = true;
    };
    test-coord-no-idhash-throws = {
      expr = throws (P.coord "host" { name = "x"; });
      expected = true;
    };
    test-coord-payload-shape = {
      expr = P.coord "host" h1;
      expected = {
        __sel = "coord";
        dim = "host";
        id_hash = "h-axon";
        name = "axon";
      };
    };

    # ---- E7: coord equality includes dim, excludes display name ----
    test-coord-eq-same = {
      expr = sel.selectorEq (P.coord "host" h1) (P.coord "host" h1);
      expected = true;
    };
    test-coord-eq-diff-dim = {
      expr = sel.selectorEq (P.coord "host" h1) (P.coord "user" h1);
      expected = false;
    };
    test-coord-eq-name-excluded = {
      expr = sel.selectorEq (P.coord "host" h1) (
        P.coord "host" {
          id_hash = "h-axon";
          name = "other";
        }
      );
      expected = true;
    };

    # ---- cell projection: __identity null (cells are not entities); flat by default ----
    test-cell-identity-null = {
      expr = (ctx.data "c11").__identity;
      expected = null;
    };
    test-flat-children-default = {
      expr = ctx.children "c11";
      expected = [ ];
    };
  };
}
