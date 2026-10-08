# `kindEq` and `entityEq` are ./default.nix's one kind relation (gen-schema's `kindEq` subject
# through `algebra.sealedCollisionEq`) and one entity relation, handed in so that the matcher and
# `selectorEq` cannot disagree.
{
  kindKey,
  kindEq,
  entityEq,
  selectorKind,
}:
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
            throw "gen-select: sel.${tag} observes the in-flight accessor `${acc}` at a NON-MONOTONE position. A selector may not observe a graph under construction negatively: a query observes reached declarations only, so negation reads only what an earlier stratum settled (Datafun's discrete/monotone separation). Either evaluate this selector against the materialized projection, or drop `${acc}` from the context's `inFlight` list once it is frozen.";
        }) inFlight
      )
      // {
        inFlight = [ ];
      };

  # The node's projected kind KEY for `sel.entity` at a sealed stamp, or a refusal by name. The guards
  # are the `sel.kind` arm's; that arm keeps its inline copy because routing it through this call
  # measured +46 to +80 bytes per node on kindMatch (den-hoag-l0y (β)). A record that omits `kind`
  # is kind-blind exactly as `kind = null` is: before (β) `sel.entity` never read the field, so an
  # entity-only hand projection had no reason to carry it, and a bare `.kind` would abort
  # uncatchably on it rather than refuse by name.
  nodeKindKey =
    tag: id: data:
    let
      k = data.__identity.kind or null;
    in
    if k == null then
      throw "gen-select: sel.${tag} matched against a kind-blind projection (node ${id} is entity-backed but __identity.kind is null or absent). Pass the registry adapter's `kind` argument, supply a `kindFor`, or use a kind-bearing projection."
    else if builtins.isString k then
      # A name compared against a minted identity never matches: the A1 silent never-match.
      throw
        "gen-select: sel.${tag} matched against a projection whose __identity.kind for node ${id} is the kind name \"${k}\"; a kind name is a reference, not a kind declaration. Project the kind's key (the registry adapter's `kind`/`kindFor` take the kind value)."
    else if !(builtins.isAttrs k && k ? identity && k ? name && k ? sealed) then
      throw "gen-select: sel.${tag} matched against a projection whose __identity.kind for node ${id} is not a kind key ({ identity; name; sealed; }, what the registry adapter projects from a kind value); got ${builtins.typeOf k}."
    else
      k;

  matchOne =
    selector: id: ctx:
    let
      # A non-selector is a wrong-form argument, refused by name and catchably (grammar R10 rule 2:
      # `star`, `attrs` and `any` are other members' names too, and handing one of those here must
      # not abort on the `__sel` read).
      tag =
        if builtins.isAttrs selector && selector ? __sel then
          selector.__sel
        else
          throw "gen-select.matches: got ${builtins.typeOf selector}${
            if builtins.isAttrs selector then " with no `__sel`" else ""
          }, expected a selector (a record built by gen-select's constructors)";
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
      else if data.__identity.id_hash != selector.id_hash then
        false
      # Equal stamps share one sealed key set (./default.nix `entityEq`); empty, the stamp is the whole
      # identity and the node's kind is not read, so a kind-blind context still answers. The
      # selector's kind is admitted by shape first (./default.nix `selectorKind`).
      else if (selectorKind "gen-select: sel.entity" "sel.entity kind entry" selector).sealed == { } then
        true
      else
        entityEq "gen-select: sel.entity" {
          inherit (data.__identity) id_hash;
          kind = nodeKindKey "entity" id data;
        } selector

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
      else if (data.__identity.kind or null) == null then
        # `or null`: a hand projection whose record omits `kind` is kind-blind, and must refuse by
        # name here rather than abort uncatchably on the attribute access.
        throw
          "gen-select: sel.kind matched against a kind-blind projection (node ${id} is entity-backed but __identity.kind is null or absent). Pass the registry adapter's `kind` argument, supply a `kindFor`, or use a kind-bearing projection."
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

    else if tag == "subkind" then
      # The `kind` arm's guards, then the node's kind or one of its transitive ancestors decided as
      # `sel.kind` decides (den-hoag-l0y). The ancestor map is keyed by mark: a miss is `false`, and a
      # hit is decided by `kindEq`, so a same-named parent at another mark never matches and an
      # open-content twin in the lineage is refused by name rather than admitted by its mark. One
      # lookup per node, and one `sealedCollisionEq` on a hit only. A projection with no map cannot
      # answer, so it is refused by name, never read as "no ancestors".
      let
        data = (discreteCtx ctx "subkind").data id;
      in
      if !(data ? __identity) then
        throw "gen-select: sel.subkind matched against an identity-blind context (its `data ${id}` has no __identity key). Use adapters.scope.mkContext / adapters.registry.mkContext, or project __identity."
      else if data.__identity == null then
        false
      else
        let
          k = nodeKindKey "subkind" id data;
          ancestors = k.ancestors or null;
        in
        if !(builtins.isAttrs ancestors) then
          throw "gen-select: sel.subkind matched against a projection whose __identity.kind for node ${id} carries no ancestor map (`ancestors`, gen-schema's `__kindAncestors`), so whether the node's kind is a subkind cannot be answered. Project the kind with the registry or scope adapter, from a gen-schema that publishes `__kindAncestors`."
        else if k.identity == selector.identity then
          kindEq "gen-select: sel.subkind" k selector
        else
          let
            a = ancestors.${selector.identity} or null;
          in
          if a == null then false else kindEq "gen-select: sel.subkind" (kindKey a) selector

    else if tag == "coord" then
      # Product-coordinate match (Imrich & Klavžar, Handbook of Product Graphs): a cell
      # is a coordinate tuple; this tests membership of the sub-product fixing one
      # coordinate. Coordinate-blind context throws, the identity-blind twin; a
      # cell lacking the dimension is a legitimate heterogeneous union → false; a
      # coordinate value without id_hash throws on the `.id_hash` access (malformed).
      # At an equal stamp the coordinate is decided as `entity` decides (den-hoag-8hqx0): the
      # selector's kind admitted by shape, the empty-sealed shortcut, then `entityEq` against the
      # context's per-dimension kind (`adapters.product.mkContext`'s `kinds`, published as the
      # context field `coordKinds`). That kind is read only there, so the per-cell cost is unchanged.
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
          if c.id_hash != selector.id_hash then
            false
          else if
            (selectorKind "gen-select: adapters.product.coord" "adapters.product.coord dim kind entry" selector)
            .sealed == { }
          then
            true
          else
            let
              k = (ctx.coordKinds or { }).${selector.dim} or null;
            in
            entityEq "gen-select: adapters.product.coord" {
              inherit (c) id_hash;
              kind =
                if k == null then
                  throw "gen-select: adapters.product.coord matched against a kind-blind product context (dimension '${selector.dim}' of node ${id} has no kind, and the selector's kind has sealed components). Pass adapters.product.mkContext's `kinds`."
                else if !(builtins.isAttrs k && k ? identity && k ? name && k ? sealed) then
                  throw "gen-select: adapters.product.coord matched against a context whose `coordKinds.${selector.dim}` is not a kind key ({ identity; name; sealed; }, what adapters.product.mkContext projects from `kinds`); got ${builtins.typeOf k}."
                else
                  k;
            } selector
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
