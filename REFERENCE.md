# gen-select — API Reference

Selector algebra for attributed graph positions. Selectors are `{ __sel = tag; … }`
attrsets matched by `matches` against an ID-based accessor context. Class A (builtins plus one
library dependency, gen-algebra, for the identity-regime discipline `selectorEq` reads).

- [Context contract](#context-contract)
- [matches](#matches)
- [Constructors](#constructors)
  - [Structural & data selectors](#structural--data-selectors)
  - [Identity-bearing selectors](#identity-bearing-selectors)
  - [Product-coordinate selectors](#product-coordinate-selectors)
- [Equality & identity](#equality--identity)
- [Adapters](#adapters)
- [Data shapes](#data-shapes)
- [Laws](#laws)

## Context contract

`matches` takes a context record of five accessor functions. The `id` argument is not
stored in the context — it is the second argument to `matches`.

| Field       | Type               | Purpose                                                                                                                |
| ----------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `data`      | `id -> attrset`    | attribute data for a node (identity-aware adapters also project `__identity`; the product adapter projects `__coords`) |
| `parent`    | `id -> id \| null` | immediate parent                                                                                                       |
| `children`  | `id -> [id]`       | direct children                                                                                                        |
| `ancestors` | `id -> [id]`       | ancestor chain (parent → root)                                                                                         |
| `siblings`  | `id -> [id]`       | sibling nodes (same parent, excluding self)                                                                            |

## matches

```
matches : selector -> id -> context -> bool
```

Evaluates a selector against the node identified by `id`. Dispatches on the `__sel` tag.
Distinct runtime tags: `star`, `attrs`, `entity`, `kind`, `subkind`, `and`, `any`, `not`,
`has`, `within`, `parentMatches`, `when`, `coord`. (`child`, `descendant`, `inSlice` are
construction-time sugar with no distinct runtime tag.)

## Constructors

### Structural & data selectors

| Constructor                            | Signature                               | Matches when                                                 |
| -------------------------------------- | --------------------------------------- | ------------------------------------------------------------ |
| `star`                                 | `-> selector`                           | always                                                       |
| `attrs a`                              | `attrset -> selector`                   | every k:v in `a` equals in `data id`; missing key = no match |
| `and ss`                               | `[selector] -> selector`                | all match; `and [] = true`                                   |
| `anyOf ss`                             | `[selector] -> selector`                | any matches; `anyOf [] = false`                              |
| `not s`                                | `selector -> selector`                  | `s` does not match                                           |
| `has s`                                | `selector -> selector`                  | some child matches `s`                                       |
| `within s`                             | `selector -> selector`                  | some ancestor matches `s`                                    |
| `parentMatches s`                      | `selector -> selector`                  | the immediate parent matches `s`                             |
| `child { parent; child; }`             | `{ parent; child; } -> selector`        | sugar: `and [ c (parentMatches p) ]`                         |
| `descendant { ancestor; descendant; }` | `{ ancestor; descendant; } -> selector` | sugar: `and [ d (within a) ]`                                |
| `when fn`                              | `fn -> selector`                        | `fn id ctx` returns true                                     |

### Identity-bearing selectors

Match by entity identity / kind. Take values carrying identity (registry entries, kind
values), never `"kind:name"` strings. Both read the reserved `__identity` projection
(see [Data shapes](#data-shapes)).

```
entity : registry-entry    -> selector
kind    : kind-value       -> selector
subkind : kind-value       -> selector
```

**`entity K e`** — matches the node whose `__identity.id_hash` equals `e.id_hash`; when
`K` has sealed components, an equal stamp also compares the node's projected kind with `K`
by `kindEq`, and a sealed collision (or a kind-blind projection) is refused by name. `K` is
judged at the first application, so the retired one-argument `entity e` refuses by name.

- Construction validates `e ? id_hash`. A string throws with an identity-law message; any
  other value lacking `id_hash` throws naming its `builtins.typeOf`.
- Payload `{ __sel = "entity"; id_hash; name = e.name or null; }` — only identity and a
  display-only name; the entry itself is not stored (keeps Nix `==` on selectors total).
- Matching: `__identity` key absent → **throw** (identity-blind context); `null` →
  `false`; record → `id_hash` equality.

**`kind K`** — matches every node whose projected kind (`__identity.kind`) is `K` by gen-schema's
`kindEq` relation: equal minted identity, and a sealed collision refused by name.

- Construction validates the gen-schema kind value's PROVENANCE: `K` must carry the
  mint-backed mark gen-schema stamps at construction (`K ? kind && K.__mint ? minted`,
  ADR-0034). A string throws; so does an attrset with no mark, which the retired
  `K ? options` shape test admitted. The read never forces the digest. Payload
  `{ __sel = "kind"; identity = K.__mint.minted; name = K.kind; sealed = K.__sealed; }`:
  the MINTED IDENTITY is the key (den-hoag-l0y, owner ruling (a)); `name` is display-only.
- Matching: `__identity` key absent → **throw**; `null` → `false`; record with
  `kind == null` → **throw** (kind-blind projection); `kind` a name string → **throw** (a
  name is a reference, not a declaration); record → `algebra.sealedCollisionEq` over the
  kind keys, the helper gen-schema's `kindEq` calls.
- A node carrying a positional `type` but no entry does not match `kind` — use
  `attrs { type = "…"; }` for positional-type matching.

**`subkind K`** — matches every node whose projected kind is `K`, or has `K` among its
transitive ancestors (a kind reaching `K` through gen-schema's `inherits`, at any depth); each
candidate is decided as `kind K` decides. `kind` stays exact.

- Construction is `kind`'s door and payload under the tag `"subkind"`.
- The adapters project the node's kind as `{ identity; name; sealed; ancestors; }`, where
  `ancestors` is gen-schema's `__kindAncestors` (mark → ancestor kind value), a shared
  reference per kind. The selector payload carries no ancestors.
- Matching: `kind`'s guards (identity-blind, `null`, kind-blind, name, malformed key); a key
  whose `ancestors` is not an attrset → **throw** (the question cannot be answered); the
  node's own mark equal to `K`'s → `kindEq`; otherwise `ancestors.${K's mark}`: a miss is
  `false`, a hit is `kindEq` against `K` — so a same-named parent at another mark is `false`,
  a type-only twin in the lineage is `true`, and an open-content twin is refused by name.

**`entityKind`** — removed. Use `kind <kind-value>`, or `attrs { type = "…"; }` for
positional typing.

### Product-coordinate selectors

Namespaced under `adapters.product`. Match cells within a gen-product slice by
coordinates given as registry entries; read the `__coords` projection and the context's
`coordKinds`.

```
adapters.product.coord   : dim-name -> kind -> registry-entry -> selector
adapters.product.inSlice : { <dim> = { kind; entry; }; … } -> selector
```

**`coord dim K e`** — a coordinate decides an entity identity at one position, so it takes
the entry's kind as `entity` does: `K` is validated with `entity`'s guard (judged at the
second application, so the retired two-argument `coord dim e` is refused by name when the
selector is used) and `e` like `entity`'s entry; payload
`{ __sel = "coord"; dim; kind; id_hash; name; }`. Matching: `__coords` absent → **throw**
(coordinate-blind); `dim` absent from the cell → `false`; different `id_hash` → `false`
(a coordinate value without `id_hash` throws); equal `id_hash` → `true` when `K` has no
sealed components, else `entityEq` against the context's kind for `dim` (a sealed collision
is refused by name; a kind-blind context is refused by name).

**`inSlice { <dim> = { kind; entry; }; … }`** — construction-time sugar for the conjunction
of one `coord dim kind entry` per fixed dimension; `inSlice { }` is vacuously true. A
dimension whose value is not `{ kind; entry; }` (the retired `{ <dim> = entry; }` form
included) is refused by name where the conjunct is forced.

**Argued impossibility** (ADR-0034, written at the declarations of `coord`, `inSlice` and
`entity`): a kind that is not its entry's kind but mints the entry's mark is taken on the
caller's word, because a gen-schema entry carries its stamp and not its kind. Detecting it
needs the entry to carry its kind, a gen-schema change.

## Equality & identity

```
isIdentified : selector -> bool
selectorEq   : selector -> selector -> bool
```

`isIdentified` is true when a `when` selector wraps an intensional function (`name`,
`__functor`, `closure`).

`selectorEq` is the canonical dedup relation:

- `when` selectors wrapping intensional functions: **conservative equality** (Palmer
  §2.3/§5.3), dispatched on the wrapped value's `__mint` tag — digest equality when
  minted, otherwise (unmintable or unmigrated) Nix `==` on the reified value — the name
  never decides;
- `entity`: `id_hash`, then (equal stamps) the kind key by `entityEq`: different marks refuse, equal marks decide by `kindEq` (display-only `name` excluded);
- `coord`: `dim`, then as `entity` (display-only `name` excluded);
- `kind`, and `subkind` with `subkind`: `kindEq` over the kind keys (a sealed collision is
  refused by name; `name` excluded);
- everything else: structural `==` on the selector, which forces whatever the payload holds — see the caveat below.

Fig. 5 is a conjunction over identity AND closure, so a name-only relation ships one
conjunct: a program point is constant across a constructor's instances, and comparing it
alone declares behaviourally distinct values equal. The unmintable arm compares the VALUE
rather than a component list — an attribute selection is an indirection, so a
component-wise form is false even against itself and the relation would be empty rather
than finer. Its precision is an allocation artefact: separately-constructed equal-shaped
values compare unequal, which merges strictly less than Fig. 5 and never more.

That arm excludes nothing. No field of a type record refuses when forced (demanding an
identity is gen-types' `idOf`, a function), and `__mint.minted` is shielded by the tagged
sum — its minted and sealed arms live under different key names, and Nix `==` decides on
the name set before forcing any value.

**Caveat on the structural fall-through.** The last bullet is plain Nix `==` on two
selector records, so it forces every value reachable in their payloads. A selector whose
payload holds a throwing value — under any key name — aborts rather than
deciding. This is a property of structural equality over caller-supplied match
specifications, not of the identity regimes: an ordinary key carrying a throw aborts
identically, measured. The `entity` and `coord` branches are unaffected, comparing
`id_hash` and the kind key and never the entry's payload. Both admit each selector's `kind`
by shape at an equal stamp, so a hand-built record without a kind key is refused by name.

Raw `==` is finer than `selectorEq` exactly on the display-only `name`; dedup paths
(neededBy sets, dispatch rule-sets) use `selectorEq`.

## Adapters

Each adapter produces (or is fed into) a five-field context; `matches` never depends on
an adapter directly.

### `adapters.scope.mkContext`

```
{ node, get,
  project  ? (n: (n.decls or {}) // { inherit (n) type; }),
  entryFor ? (id: let n = node id; in if n ? id_hash then n else null),
} -> context
```

Bridges gen-scope's accessor pair. `data id = (project (node id)) // { __identity = …; }`
— the `__identity` record (or `null`) is composed outside the projection and merged last
(a decl named `__identity` cannot shadow it). `__identity.kind` is a named REFUSAL: a
positional node `type` is a name, not a kind declaration, so `sel.kind` over this adapter
throws (lazily; `attrs` on the projected `type` is unaffected) until a gen-scope node's kind
declaration is ruled; `entryFor` defaults to the node itself when it carries `id_hash`
(else `null`), and a framework whose identity lives under its own key supplies `entryFor`. `__identity` is always present, so identity/kind selectors are never silently
inert through this adapter.

### `adapters.registry.mkContext`

```
{ nodes, data, parent,
  kind     ? null,                                                      # registry kind VALUE
  entryFor ? (id: let d = data id; in if d ? id_hash then d else null),
  kindFor  ? (_: kind),                                                 # id -> kindValue | null
} -> context
```

Flat node-list bridge. Derives `children`/`siblings`/`ancestors` from `nodes` + `parent`.
Kind projection cannot default from the datum (gen-schema instances carry no kind field):
pass the registry's `kind` value (validated, projected as its kind key) or an explicit
`kindFor` for heterogeneous unions. A `kindFor` returning a kind NAME is refused by name:
resolving a name needs the shared resolver. Omitting both makes `sel.kind` throw kind-blind while
`sel.entity` still works. Default `entryFor` treats `data id` as the entry.

### `adapters.product.mkContext`

```
{ nodeIds, coordsFor, dataFor ? (_: {}), parent ? (_: null), inFlight ? [ ], kinds ? { } } -> context
```

`data id = (dataFor id) // { __coords = coordsFor id; __identity = null; }`. Flat by
default; when `parent` is supplied the registry-adapter derivations apply. Consumes
gen-product's `pgraph.nodes` (`nodeIds`) + `pgraph.product.coordsOf` (`coordsFor`) without
importing gen-product. `kinds` maps a dimension to the kind value of that factor's
coordinates (one registry, one kind); each is validated and published once per context as
the context field `coordKinds = { <dim> = <kind-key>; }`, never per cell. **Required in
effect for a factor whose kind has sealed components:** a dimension absent from `kinds` is
kind-blind, and a sealed coordinate at an equal stamp refuses there, on its own cell too.
A migrated kind never reads it.

### `adapters.graph`

```
mkPredicate       : selector -> context -> (id -> bool)
mkSelectPredicate : selector -> context -> (attrset -> bool)
```

Context-agnostic; identity/kind/coord selectors flow through unchanged once the context is
enriched.

## Data shapes

```nix
# selector payloads (identity-bearing tags)
{ __sel = "entity"; id_hash = <sha256>; kind = <kind-key>; name = <string|null>; }   # name: display/errors only
{ __sel = "kind";   identity = <mark>; name = <string>; sealed = <attrs>; }  # key: identity
{ __sel = "coord";  dim = <string>; kind = <kind-key>; id_hash = <sha256>; name = <string|null>; }

# __identity — reserved projection into `data id` (enriched adapters)
__identity = null;                                 # not entity-backed
__identity = { id_hash = <sha256>; kind = <kind-key|null>; entry = <registry-entry>; };  # kind-key = { identity; name; sealed; }

# __coords — reserved projection into `data id` (product adapter)
__coords = { <dim-name> = <registry-entry>; … };

# coordKinds — a context field (product adapter), not a `data` key
coordKinds = { <dim-name> = <kind-key>; … };
```

A malformed `entryFor`/coordinate value (no `id_hash`) surfaces a named throw at the first
`id_hash` access — never a silent `null`/mismatch — and does not block `kind` matching,
which reads only the positional kind.

## Laws

| Law | Statement                                                                                                                                                                                                                                                                                                                                                       |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| E1  | `entity K e` matches iff `__identity` is a record with `.id_hash == e.id_hash` (and, when `K` has sealed components, a kind `kindEq` to `K`, refused by name at a sealed collision). Equal-identity entries share a match set; any identity-field difference never cross-matches.                                                                               |
| E2  | `kind K` matches iff `__identity` is a record whose non-null `.kind` is `K`'s kind key by `kindEq`; `.kind == null` throws (kind-blind projection is loud); a name string throws.                                                                                                                                                                               |
| E3  | `entity`/`kind` throw at construction on strings and non-conforming values; no selector is ever produced from a string.                                                                                                                                                                                                                                         |
| E4  | Matching `entity`/`kind` against a context whose `data id` lacks the `__identity` key throws (identity-blind contexts are loud).                                                                                                                                                                                                                                |
| E5  | `__identity = null` yields `false` (non-entity nodes are quiet — structural recursion over mixed graphs needs no guards).                                                                                                                                                                                                                                       |
| E6  | Through the enriched adapters `__identity` is present for every node; `null` iff no entry; `id_hash`/`kind` coherent by construction; `__identity` overrides same-named projection keys; a malformed entry errors at `id_hash` access, `kind` matching unaffected.                                                                                              |
| E7  | `entity`/`kind`/`coord` selectors are function-free over a kind with no sealed components (Nix `==` total, `builtins.toJSON` defined). Over a kind with sealed components the kind key holds its sealed subjects, which may be functions: `==` stays total, and `builtins.toJSON` aborts. `selectorEq` compares identity fields only (display `name` excluded). |
| E8  | Backward compatible: existing selectors, the five-accessor contract, and the graph adapter are byte-compatible; enrichment is additive (`data` output is a superset). Sole break: `sel.entityKind` is removed.                                                                                                                                                  |
| P1  | `coord dim K e` matches iff `__coords` is projected, the cell has `dim`, `__coords.${dim}.id_hash == e.id_hash`, and, when `K` has sealed components, the context's `coordKinds.${dim}` is `K` by `entityEq` (a sealed collision, and a kind-blind context, refuse by name).                                                                                    |
| P2  | `inSlice { <dim> = { kind; entry; }; … }` matches iff every fixed coordinate matches; `inSlice { }` is vacuously true; equal to the hand-written conjunction; a dimension value that is not `{ kind; entry; }` refuses by name.                                                                                                                                 |
| P3  | `__coords` absent → throw; dim absent from a cell → `false`; malformed coordinate value → throw.                                                                                                                                                                                                                                                                |
| P4  | Selectors are static: they read only structural context attributes, never resolved values, and force only the node data a match inspects (`entity`/`kind` never force children).                                                                                                                                                                                |
