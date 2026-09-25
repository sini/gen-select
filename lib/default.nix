# gen-select takes ONE library dependency: gen-algebra, for the identity-regime discipline
# `selectorEq` reads. Nothing else — no nixpkgs.lib, which was always unused.
#
# ★ THE ZERO-DEPENDENCY CLAIM IS RETIRED KNOWINGLY, not eroded. It held while conservative
# equality was `a.name == b.name` and the vendored copy really was the "one trivial line"
# the old note priced. It stopped holding when the relation became a dispatch over a tagged
# sum with a mint comparison on one arm: a ~40-line discipline in four libraries is four
# readers of one sum that can drift apart, and gen-algebra is the one that AUTHORS the tag.
# gen-algebra declares no inputs of its own, so a consumer of gen-select gains a leaf and
# no closure — which is what makes the edge cheap enough to be worth the consolidation.
#
# Takes its dependency as a named argument: `import ./lib { algebra = <gen-algebra.lib>; }`.
{ algebra }:
let
  # ONE reader of gen-schema's provenance mark, shared by the two kind-admission sites this library
  # has. It is not published: the seam's test is this library's own business, and a second copy in
  # the adapter is how two readers of one tagged sum stop agreeing.
  isSchemaKind = import ./kind-mark.nix;

  # A KIND KEY: what a kind selector carries and what an adapter projects as `__identity.kind`. The
  # minted identity is the key (owner-ruled 2026-09-25, den-hoag-l0y (a)); `name` is display and
  # errors only; `sealed` is the kind's sealed subjects, read so that two kinds minting one mark and
  # differing only at a sealed component are REFUSED by name rather than collapsed (ADR-0034). All
  # three are shared references into the kind value, so the digest is paid once per KIND: nothing
  # here mints, and nothing forces the mark before a comparison demands it.
  kindKey = k: {
    identity = k.__mint.minted;
    name = k.kind;
    sealed =
      k.__sealed
        or (throw "gen-select: the kind value '${k.kind}' carries a mark but no sealed subjects (`__sealed`), so it cannot be compared as gen-schema's own `kindEq` compares it. Take the kind from a gen-schema that stamps both.");
  };

  # THE ONE KIND RELATION: gen-schema's `kindEq` subject handed to the same helper `kindEq` calls, so
  # `selectorEq` and the matcher decide what the producer's own door decides — true, false, or a
  # refusal by name at a sealed collision.
  #
  # Distinct marks decide `false` before either subject is built. That is the helper's own first
  # arm, taken early because the matcher runs this once per NODE: measured on the hub bench's
  # `kindMatch` at n=1600, building both subjects for every node cost 10,406 thunks more than
  # deciding the non-matching half here. Equal marks always reach the helper, so the true/refused
  # decision has one author.
  kindEq =
    site: a: b:
    if a.identity != b.identity then
      false
    else
      algebra.sealedCollisionEq site
        {
          inherit (a) name sealed;
          mark = a.identity;
        }
        {
          inherit (b) name sealed;
          mark = b.identity;
        };

  # THE ONE ENTITY RELATION (den-hoag-l0y (β)). An entity key is `{ id_hash; kind = kindKey; }`.
  # Distinct stamps decide `false` without reading either kind. Equal stamps: gen-schema mints
  # `id_hash` over the kind's MARK (U2), so equal stamps carry equal marks, and a mark is minted over
  # the kind's component tags, which put the sealed marker at every sealed path. So equal stamps have
  # the same SEALED KEY SET, and the entity's identity is total exactly when that set is empty. When
  # it is not, the decision is `kindEq`'s: true, or a refusal by name at a sealed collision. Different
  # marks at an equal stamp is not a collision; it is a kind that is not its entry's kind (or a
  # gen-schema whose stamp omits the mark), refused by name.
  entityEq =
    site: a: b:
    if a.id_hash != b.id_hash then
      false
    else if a.kind.identity != b.kind.identity then
      throw "${site}: two entries share the id_hash '${a.id_hash}' but carry kinds with different marks ('${a.kind.name}', '${b.kind.name}'); gen-schema mints an entry's id_hash over its kind's mark, so one of these kinds is not its entry's kind. Pass each entry's own kind value."
    else
      kindEq site a.kind b.kind;

  constructors = import ./constructors.nix {
    inherit
      isSchemaKind
      kindKey
      kindEq
      entityEq
      algebra
      ;
  };
  match = import ./match.nix { inherit kindEq entityEq; };
  scopeAdapter = import ./adapters/scope.nix;
  graphAdapter = import ./adapters/graph.nix { inherit (match) matches; };
  registryAdapter = import ./adapters/registry.nix { inherit isSchemaKind kindKey; };
  productAdapter = import ./adapters/product.nix { inherit (constructors) and; };
in
constructors
// {
  inherit (match) matches;
  adapters = {
    scope = scopeAdapter;
    graph = graphAdapter;
    registry = registryAdapter;
    product = productAdapter;
  };
}
