# Product-coordinate adapter — gen-select's side of the gen-product contract.
#
# Imrich & Klavžar, Handbook of Product Graphs: vertices of a product graph are
# coordinate tuples and a sub-product fixes a subset of coordinates. `coord`/`inSlice`
# are the vertex-membership predicates of such sub-products. The adapter consumes an
# accessor shape (cellIds + coordsFor) satisfied by gen-product's `pgraph.nodes` +
# `pgraph.product.coordsOf` — no gen-product import (pure structural translator).
{
  and,
  isSchemaKind,
  kindKey,
  projectedKindKey,
}:
let
  # coord dim kind entry — the vertex-membership predicate of the sub-product fixing `dim` at the
  # entity `entry` DECIDES AN ENTITY IDENTITY at one position, which is `sel.entity`'s decision, so it
  # takes the entry's kind exactly as `sel.entity` does (den-hoag-8hqx0; ADR-0034). gen-schema mints
  # `id_hash` over the kind's MARK, and two kinds differing only at a sealed component share a mark,
  # so their instances at equal keys share a stamp: the stamp alone cannot decide. The payload stores
  # the kind's KEY (../default.nix `kindKey`) beside the stamp, and the match and `selectorEq` decide
  # through `entityEq`, the one entity relation, refusing such a collision by name. Only plain,
  # `==`-comparable data is stored for a migrated kind; a sealed kind's `sealed` subjects may hold
  # functions, so `builtins.toJSON` of such a selector aborts, as it already did for `sel.entity`.
  #
  # The kind is judged at the SECOND application (`builtins.seq`), so the retired two-argument call
  # `coord "host" entry` refuses by name when the selector is used, rather than handing `matches` a
  # function that aborts uncatchably at `selector.__sel`.
  #
  # ★ ARGUED IMPOSSIBILITY (ADR-0034: a surviving comparison owes one at its declaration). A kind that
  # is NOT the entry's kind but mints the entry's MARK is not detected here: `coord "host" k2 s1`,
  # with `k2` sealed-colliding with `s1`'s own kind, carries `k2`'s sealed subjects, and nothing in
  # `s1` names its own, because a gen-schema entry carries its stamp and not its kind. At an equal
  # mark the selector's kind is therefore taken on the caller's word. What would have to change: the
  # entry would have to carry its kind (den-hoag-l0y (β) arm (i), rejected at +19 thunks per instance
  # on every instance), which is a gen-schema change. A kind at a DIFFERENT mark is refused by
  # `entityEq` wherever the other side's kind is in hand; on a migrated selector the match reads no
  # node kind, and the stamp decides (the same residue as `sel.entity`'s).
  coord =
    dim: kindValue:
    let
      kind =
        if builtins.isString kindValue then
          throw "gen-select: adapters.product.coord expects the coordinate's kind value after the dimension (coord \"host\" schema.host hosts.axon), got the string \"${kindValue}\". A kind name is a reference; pass the kind value."
        else if !(isSchemaKind kindValue) then
          throw "gen-select: adapters.product.coord expects the coordinate's kind value after the dimension (coord \"host\" schema.host hosts.axon): a gen-schema kind value carrying a mint-backed mark (`__mint.minted`; a kind's identity comes only from the one mint); got ${
            if builtins.isAttrs kindValue && kindValue ? id_hash then
              "an entry (the two-argument form is retired: the coordinate's kind decides a sealed collision)"
            else if builtins.isAttrs kindValue then
              "an attrset with no mark"
            else
              builtins.typeOf kindValue
          }."
        else
          kindKey kindValue;
    in
    builtins.seq kind (
      entry:
      if builtins.isString entry then
        throw "gen-select: adapters.product.coord expects a registry entry (an attrset carrying id_hash); got a string. Pass the entry value, never a name string."
      else if !(builtins.isAttrs entry && entry ? id_hash) then
        throw "gen-select: adapters.product.coord expects a registry entry (an attrset carrying id_hash); got ${builtins.typeOf entry}."
      else
        {
          __sel = "coord";
          inherit dim kind;
          inherit (entry) id_hash;
          name = entry.name or null; # display/errors only; excluded from selectorEq
        }
    );
in
{
  inherit coord;

  # inSlice { <dim> = { kind; entry; }; … } — construction-time sugar for the conjunction of one
  # `coord dim kind entry` per fixed dimension (like child/descendant, no runtime tag). Each kind
  # rides beside its own entry, so there is no shared kind record for a foreign entry to borrow.
  # `inSlice { }` == `and [ ]` is vacuously true, consistent with existing and-semantics. Dims
  # iterate in attrNames order, irrelevant to the conjunction result and stable for structural
  # equality. The retired `{ <dim> = entry; }` value carries `id_hash` and no `kind`/`entry`, so it
  # refuses by name, catchably, where the conjunct is forced.
  #
  # ★ ARGUED IMPOSSIBILITY: `coord`'s, above. A `kind` that is not its `entry`'s kind but mints the
  # same mark is taken on the caller's word; detecting it needs the entry to carry its kind.
  inSlice =
    coords:
    and (
      map (
        dim:
        let
          v = coords.${dim};
        in
        if builtins.isAttrs v && v ? kind && v ? entry then
          coord dim v.kind v.entry
        else
          throw "gen-select: adapters.product.inSlice expects { <dim> = { kind; entry; }; } (inSlice { host = { kind = schema.host; entry = hosts.axon; }; }); dimension '${dim}' got ${
            if builtins.isAttrs v && v ? id_hash then
              "an entry (the { <dim> = entry; } form is retired: the coordinate's kind decides a sealed collision)"
            else if builtins.isAttrs v then
              "an attrset without both `kind` and `entry`"
            else
              builtins.typeOf v
          }."
      ) (builtins.attrNames coords)
    );

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
      # dim -> the kind VALUE of that factor's coordinates. A factor is one registry, so one kind
      # per dimension. Projected once as kind keys, published as the context field `coordKinds`
      # (shared references, so the digest is paid per kind and nothing is minted; a per-cell `data`
      # projection measured +10 to +17 B per cell for a constant, den-hoag-8hqx0 §2.3).
      #
      # ★ REQUIRED IN EFFECT FOR A FACTOR OF A COMPARED KIND. A dimension absent here is kind-blind.
      # A coord selector reads the node's kind only at an equal stamp whose kind has sealed
      # components: a MIGRATED kind (no sealed components) decides on the stamp and never reads it,
      # while a kind WITH sealed components is refused by name, even on the coordinate's own cell,
      # because an identity is demanded of a compared value with no subject in hand (ADR-0034).
      kinds ? { },
    }:
    let
      kindKeys = builtins.mapAttrs (
        dim: k:
        if isSchemaKind k then
          projectedKindKey k
        else
          throw "gen-select: adapters.product.mkContext `kinds.${dim}` expects a gen-schema kind value carrying a mint-backed mark (`__mint.minted`; a kind's identity comes only from the one mint); got ${
            if builtins.isString k then "the kind name \"${k}\"" else builtins.typeOf k
          }."
      ) kinds;
    in
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
      coordKinds = kindKeys;
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
