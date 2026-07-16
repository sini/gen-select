# Product-coordinate adapter — gen-select's side of the gen-product contract.
#
# Imrich & Klavžar, Handbook of Product Graphs: vertices of a product graph are
# coordinate tuples and a sub-product fixes a subset of coordinates. `coord`/`inSlice`
# are the vertex-membership predicates of such sub-products. The adapter consumes an
# accessor shape (cellIds + coordsFor) satisfied by gen-product's `pgraph.nodes` +
# `pgraph.product.coordsOf` — no gen-product import (pure structural translator).
{ and }:
let
  # coord dim entry — validates the entry exactly like sel.entity (structural
  # `? id_hash`, strings throw) and stores only plain, `==`-comparable data.
  coord =
    dim: entry:
    if builtins.isString entry then
      throw "gen-select: adapters.product.coord expects a registry entry (an attrset carrying id_hash); got a string. Pass the entry value, never a name string."
    else if !(builtins.isAttrs entry && entry ? id_hash) then
      throw "gen-select: adapters.product.coord expects a registry entry (an attrset carrying id_hash); got ${builtins.typeOf entry}."
    else
      {
        __sel = "coord";
        inherit dim;
        inherit (entry) id_hash;
        name = entry.name or null; # display/errors only; excluded from selectorEq
      };
in
{
  inherit coord;

  # inSlice — construction-time sugar for the conjunction of one coord per fixed
  # dimension (like child/descendant, no runtime tag). `inSlice { }` == `and [ ]` is
  # vacuously true, consistent with existing and-semantics. Dims iterate in attrNames
  # order, irrelevant to the conjunction result and stable for structural equality.
  inSlice = coords: and (map (dim: coord dim coords.${dim}) (builtins.attrNames coords));

  mkContext =
    {
      cellIds, # [ cellId ] — gen-product's pgraph.nodes
      coordsFor, # cellId -> { <dim> = registry-entry; … } — gen-product's product.coordsOf
      dataFor ? (_: { }), # cellId -> attrset (extra matchable cell data)
      parent ? (_: null), # product lattices are flat by default; overridable
    }:
    {
      # Cells are not entities: __identity is null (an entity-backed-cell variant can
      # pass richer dataFor later). __coords carries the coordinate tuple; merged last.
      data =
        id:
        (dataFor id)
        // {
          __coords = coordsFor id;
          __identity = null;
        };
      inherit parent;
      # With the default flat `parent` these all yield [ ]; when `parent` is supplied
      # the registry adapter's derivations apply (structural selectors over the
      # containment lattice are gen-product's business, not the matcher's).
      children = id: builtins.filter (nid: parent nid == id) cellIds;
      ancestors =
        id:
        let
          go =
            visited: nid:
            let
              p = parent nid;
            in
            if p == null then
              [ ]
            else if visited ? ${p} then
              [ ]
            else
              [ p ] ++ go (visited // { ${p} = true; }) p;
        in
        go { ${id} = true; } id;
      siblings =
        id:
        let
          p = parent id;
        in
        if p == null then
          [ ]
        else
          builtins.filter (cid: cid != id) (builtins.filter (nid: parent nid == p) cellIds);
    };
}
