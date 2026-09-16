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
      # Accessor names (drawn from data/parent/children/ancestors/siblings) that
      # read a graph still under construction. Passed straight through to the
      # returned context for gen-select's discrete/monotone separation
      # (match.nix's discreteCtx) to clear at a non-monotone read. Conservative
      # default: a context that declares nothing in flight is unchanged.
      inFlight ? [ ],
    }:
    {
      # Cells are not entities: __identity is null (an entity-backed-cell variant can
      # pass richer dataFor later). __coords carries the coordinate tuple; merged last.
      data =
        id:
        (dataFor id)
        // {
          # No framework-agnostic fallback exists for coordsFor (cells are not
          # entities), so it stays required. These two checks are the totality
          # doors the required formal was missing: a non-function or a wrong-
          # shaped/under-applied result would otherwise write silently into
          # __coords and produce a plausible-looking wrong match downstream in
          # match.nix's `?` test, never a throw (ADR-0025 item 1; mirrors this
          # file's own discreteCtx house rule in match.nix).
          __coords =
            if !(builtins.isFunction coordsFor) then
              throw "gen-select: adapters.product.mkContext's `coordsFor` must be a function (cellId -> { <dim> = registry-entry; ... }); got ${builtins.typeOf coordsFor}."
            else
              let
                c = coordsFor id;
              in
              if !(builtins.isAttrs c) then
                throw "gen-select: adapters.product.mkContext's `coordsFor` must return an attrset of dimension -> registry-entry for cell ${id}; got ${builtins.typeOf c} (an under-applied coordsFor returns a function here)."
              else
                c;
          __identity = null;
        };
      inherit parent inFlight;
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
