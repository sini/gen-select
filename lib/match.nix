let
  matchOne =
    selector: id: ctx:
    let
      tag = selector.__sel;
    in
    if tag == "star" then
      true

    else if tag == "attrs" then
      let
        a = selector.a;
        data = ctx.data id;
      in
      builtins.all (k: data ? ${k} && data.${k} == a.${k}) (builtins.attrNames a)

    else if tag == "and" then
      builtins.all (s: matchOne s id ctx) selector.selectors

    else if tag == "any" then
      builtins.any (s: matchOne s id ctx) selector.selectors

    else if tag == "not" then
      !(matchOne selector.selector id ctx)

    else if tag == "has" then
      builtins.any (childId: matchOne selector.selector childId ctx) (ctx.children id)

    else if tag == "within" then
      builtins.any (ancId: matchOne selector.selector ancId ctx) (ctx.ancestors id)

    else if tag == "parentMatches" then
      let
        p = ctx.parent id;
      in
      if p == null then false else matchOne selector.selector p ctx

    else if tag == "entity" then
      # Identity match against the projected __identity record (§4.2). Absence of the
      # key marks an identity-blind context — a projection gap, loud not silent (the
      # 2026-06-09 readiness audit's A1 silent-never-match failure class). `null` is a
      # well-formed "not entity-backed" node and matches nothing without throwing.
      let
        data = ctx.data id;
      in
      if !(data ? __identity) then
        throw "gen-select: sel.entity matched against an identity-blind context (its `data ${id}` has no __identity key). Use adapters.scope.mkContext / adapters.registry.mkContext, or project __identity."
      else if data.__identity == null then
        false
      else
        data.__identity.id_hash == selector.id_hash

    else if tag == "kind" then
      # Kind match — like entity, plus a kind-blind guard: an entity-backed node whose
      # kind the context cannot name (`kind == null`) is a projection gap, not a
      # mismatch. gen-schema instances carry no kind field of their own, so a kind-blind
      # projection would otherwise make every sel.kind silently inert (A1 with the
      # __identity key present, which the identity-blind branch cannot catch).
      let
        data = ctx.data id;
      in
      if !(data ? __identity) then
        throw "gen-select: sel.kind matched against an identity-blind context (its `data ${id}` has no __identity key). Use adapters.scope.mkContext / adapters.registry.mkContext, or project __identity."
      else if data.__identity == null then
        false
      else if data.__identity.kind == null then
        throw "gen-select: sel.kind matched against a kind-blind projection (node ${id} is entity-backed but __identity.kind is null). Pass the registry adapter's `kind` argument, supply a `kindFor`, or use a kind-bearing projection."
      else
        data.__identity.kind == selector.kind

    else if tag == "coord" then
      # Product-coordinate match (Imrich & Klavžar, Handbook of Product Graphs): a cell
      # is a coordinate tuple; this tests membership of the sub-product fixing one
      # coordinate. Coordinate-blind context throws (P3, the identity-blind twin); a
      # cell lacking the dimension is a legitimate heterogeneous union → false; a
      # coordinate value without id_hash throws on the `.id_hash` access (malformed).
      let
        data = ctx.data id;
      in
      if !(data ? __coords) then
        throw "gen-select: coord matched against a coordinate-blind context (its `data ${id}` has no __coords key). Use adapters.product.mkContext, or project __coords."
      else if !(data.__coords ? ${selector.dim}) then
        false
      else
        let
          c = data.__coords.${selector.dim};
        in
        # A coordinate value without id_hash is a malformed projection, not a mismatch.
        if c ? id_hash then c.id_hash == selector.id_hash else throw "gen-select: coord matched a malformed coordinate value for dimension '${selector.dim}' on node ${id} (no id_hash). Coordinates must be registry entries."

    else if tag == "when" then
      selector.fn id ctx

    else
      throw "gen-select: unknown selector tag '${tag}'";
in
{
  matches = matchOne;
}
