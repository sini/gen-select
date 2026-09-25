# `kindEq` is ./default.nix's one kind relation (gen-schema's `kindEq` subject through
# `algebra.sealedCollisionEq`), handed in so that the matcher and `selectorEq` cannot disagree.
{ kindEq }:
let
  # Datafun (Arntzenius & Krishnaswami 2016) splits the typing context into a
  # discrete ∆ and a monotone Γ and types every non-monotone operation (¬, =,
  # a caller-supplied function — Fig. 4, lines 349-354) under a CLEARED Γ.
  # gen has no type-level ∆/Γ split, so this clears the *value* instead: a
  # context declares which of its accessors read a graph still under
  # construction (`ctx.inFlight`), and a non-monotone position evaluates
  # under a context in which exactly those accessors refuse by name. A
  # context that declares nothing in flight is unchanged (`discreteCtx` is
  # the identity when `inFlight` is absent or `[ ]`).
  #
  # Two guards ahead of the clearing itself, both closing a way the
  # declaration could fail without saying so: a non-list `inFlight` (e.g. a
  # bare string) would otherwise reach `builtins.listToAttrs` and abort with
  # an uncatchable interpreter error rather than a named, `tryEval`-catchable
  # refusal (ADR-0025 item 1; the house rule this file already states at
  # adapters/scope.nix's `entryFor` throw); an accessor name outside the
  # closed five-name set (e.g. a typo) would otherwise add a dead key and
  # clear nothing — byte-identical to declaring no mechanism at all. Both
  # are named refusals, checked in that order (type first, membership
  # second), before any accessor is cleared.
  discreteCtx =
    ctx: tag:
    let
      inFlight = ctx.inFlight or [ ];
      accessors = [
        "data"
        "parent"
        "children"
        "ancestors"
        "siblings"
      ];
      unknown = builtins.filter (acc: !(builtins.elem acc accessors)) inFlight;
    in
    if !(builtins.isList inFlight) then
      throw "gen-select: sel.${tag}'s context declares `inFlight` as a ${builtins.typeOf inFlight}, not a list of accessor names. `inFlight` must be a list drawn from ${toString accessors}."
    else if unknown != [ ] then
      throw "gen-select: sel.${tag}'s context declares `inFlight` naming an accessor gen-select does not have (${toString unknown}); the accessor set is ${toString accessors}."
    else if inFlight == [ ] then
      ctx
    else
      ctx
      // builtins.listToAttrs (
        map (acc: {
          name = acc;
          value =
            _:
            throw "gen-select: sel.${tag} observes the in-flight accessor `${acc}` at a NON-MONOTONE position. A selector may not observe a graph under construction negatively (ADR-0019/0020; Datafun's discrete/monotone separation). Either evaluate this selector against the materialized projection, or drop `${acc}` from the context's `inFlight` list once it is frozen.";
        }) inFlight
      )
      // {
        inFlight = [ ];
      };

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
        data = (discreteCtx ctx "attrs").data id;
      in
      builtins.all (k: data ? ${k} && data.${k} == a.${k}) (builtins.attrNames a)

    else if tag == "and" then
      builtins.all (s: matchOne s id ctx) selector.selectors

    else if tag == "any" then
      builtins.any (s: matchOne s id ctx) selector.selectors

    else if tag == "not" then
      !(matchOne selector.selector id (discreteCtx ctx "not"))

    else if tag == "has" then
      builtins.any (childId: matchOne selector.selector childId ctx) (ctx.children id)

    else if tag == "within" then
      builtins.any (ancId: matchOne selector.selector ancId ctx) (ctx.ancestors id)

    else if tag == "parentMatches" then
      let
        p = (discreteCtx ctx "parentMatches").parent id;
      in
      if p == null then false else matchOne selector.selector p ctx

    else if tag == "entity" then
      # Identity match against the projected __identity record. Absence of the
      # key marks an identity-blind context — a projection gap, loud not silent (the
      # 2026-06-09 readiness audit's A1 silent-never-match failure class). `null` is a
      # well-formed "not entity-backed" node and matches nothing without throwing.
      let
        data = (discreteCtx ctx "entity").data id;
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
        data = (discreteCtx ctx "kind").data id;
      in
      if !(data ? __identity) then
        throw "gen-select: sel.kind matched against an identity-blind context (its `data ${id}` has no __identity key). Use adapters.scope.mkContext / adapters.registry.mkContext, or project __identity."
      else if data.__identity == null then
        false
      else if data.__identity.kind == null then
        throw "gen-select: sel.kind matched against a kind-blind projection (node ${id} is entity-backed but __identity.kind is null). Pass the registry adapter's `kind` argument, supply a `kindFor`, or use a kind-bearing projection."
      else if builtins.isString data.__identity.kind then
        # A name compared against a minted identity never matches: the A1 silent never-match.
        # Keeping a name comparison beside the identity one is the silent site-local fallback
        # ADR-0034's rider forbids, so a projection that still carries a name is refused by name.
        throw
          "gen-select: sel.kind matched against a projection whose __identity.kind for node ${id} is the kind name \"${data.__identity.kind}\"; a kind name is a reference, not a kind declaration. Project the kind's key (the registry adapter's `kind`/`kindFor` take the kind value)."
      else if
        !(
          builtins.isAttrs data.__identity.kind
          && data.__identity.kind ? identity
          && data.__identity.kind ? name
          && data.__identity.kind ? sealed
        )
      then
        throw "gen-select: sel.kind matched against a projection whose __identity.kind for node ${id} is not a kind key ({ identity; name; sealed; }, what the registry adapter projects from a kind value); got ${builtins.typeOf data.__identity.kind}."
      else
        kindEq "gen-select: sel.kind" data.__identity.kind selector

    else if tag == "coord" then
      # Product-coordinate match (Imrich & Klavžar, Handbook of Product Graphs): a cell
      # is a coordinate tuple; this tests membership of the sub-product fixing one
      # coordinate. Coordinate-blind context throws, the identity-blind twin; a
      # cell lacking the dimension is a legitimate heterogeneous union → false; a
      # coordinate value without id_hash throws on the `.id_hash` access (malformed).
      let
        data = (discreteCtx ctx "coord").data id;
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
        if c ? id_hash then
          c.id_hash == selector.id_hash
        else
          throw "gen-select: coord matched a malformed coordinate value for dimension '${selector.dim}' on node ${id} (no id_hash). Coordinates must be registry entries."

    else if tag == "when" then
      selector.fn id (discreteCtx ctx "when")

    else
      throw "gen-select: unknown selector tag '${tag}'";
in
{
  matches = matchOne;
}
