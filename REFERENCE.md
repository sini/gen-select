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
Distinct runtime tags: `star`, `attrs`, `entity`, `kind`, `and`, `any`, `not`, `has`,
`within`, `parentMatches`, `when`, `coord`. (`child`, `descendant`, `inSlice` are
construction-time sugar with no distinct runtime tag.)

## Constructors

### Structural & data selectors

| Constructor       | Signature                | Matches when                                                 |
| ----------------- | ------------------------ | ------------------------------------------------------------ |
| `star`            | `-> selector`            | always                                                       |
| `attrs a`         | `attrset -> selector`    | every k:v in `a` equals in `data id`; missing key = no match |
| `and ss`          | `[selector] -> selector` | all match; `and [] = true`                                   |
| `any ss`          | `[selector] -> selector` | any matches; `any [] = false`                                |
| `not s`           | `selector -> selector`   | `s` does not match                                           |
| `has s`           | `selector -> selector`   | some child matches `s`                                       |
| `within s`        | `selector -> selector`   | some ancestor matches `s`                                    |
| `parentMatches s` | `selector -> selector`   | the immediate parent matches `s`                             |
| `child p c`       | `sel -> sel -> selector` | sugar: `and [ c (parentMatches p) ]`                         |
| `descendant a d`  | `sel -> sel -> selector` | sugar: `and [ d (within a) ]`                                |
| `when fn`         | `fn -> selector`         | `fn id ctx` returns true                                     |

### Identity-bearing selectors

Match by entity identity / kind. Take values carrying identity (registry entries, kind
values), never `"kind:name"` strings. Both read the reserved `__identity` projection
(see [Data shapes](#data-shapes)).

```
entity : registry-entry    -> selector
kind   : kind-value        -> selector
```

**`entity e`** — matches the node whose `__identity.id_hash` equals `e.id_hash`.

- Construction validates `e ? id_hash`. A string throws with an identity-law message; any
  other value lacking `id_hash` throws naming its `builtins.typeOf`.
- Payload `{ __sel = "entity"; id_hash; name = e.name or null; }` — only identity and a
  display-only name; the entry itself is not stored (keeps Nix `==` on selectors total).
- Matching: `__identity` key absent → **throw** (identity-blind context); `null` →
  `false`; record → `id_hash` equality.

**`kind K`** — matches every node whose `__identity.kind` equals `K.kind`.

- Construction validates the gen-schema kind value (`K ? kind && K ? options`). A string
  throws. Payload `{ __sel = "kind"; kind = K.kind; }` (the kind name is the internal key).
- Matching: `__identity` key absent → **throw**; `null` → `false`; record with
  `kind == null` → **throw** (kind-blind projection); record → `kind` equality.
- A node carrying a positional `type` but no entry does not match `kind` — use
  `attrs { type = "…"; }` for positional-type matching.

**`entityKind`** — removed. Use `kind <kind-value>`, or `attrs { type = "…"; }` for
positional typing.

### Product-coordinate selectors

Namespaced under `adapters.product`. Match cells within a gen-product slice by
coordinates given as registry entries; read the `__coords` projection.

```
adapters.product.coord   : dim-name -> registry-entry -> selector
adapters.product.inSlice : { <dim> = registry-entry; … } -> selector
```

**`coord dim e`** — validates `e` like `entity`; payload
`{ __sel = "coord"; dim; id_hash; name; }`. Matching: `__coords` absent → **throw**
(coordinate-blind); `dim` absent from the cell → `false`; else `__coords.${dim}.id_hash`
equality (a coordinate value without `id_hash` throws).

**`inSlice coords`** — construction-time sugar for the conjunction of one `coord` per
fixed dimension; `inSlice { }` is vacuously true.

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
  minted, Nix `==` on the reified value MINUS `__id` when unmintable, `name` equality
  while unmigrated;
- `entity`: `id_hash` only (display-only `name` excluded);
- `coord`: `(dim, id_hash)` (display-only `name` excluded);
- everything else (including `kind`, whose payload has no display field): structural `==`
  on the selector, which forces whatever the payload holds — see the caveat below.

Fig. 5 is a conjunction over identity AND closure, so a name-only relation ships one
conjunct: a program point is constant across a constructor's instances, and comparing it
alone declares behaviourally distinct values equal. The unmintable arm compares the VALUE
rather than a component list — an attribute selection is an indirection, so a
component-wise form is false even against itself and the relation would be empty rather
than finer. Its precision is an allocation artefact: separately-constructed equal-shaped
values compare unequal, which merges strictly less than Fig. 5 and never more.

That arm excludes `__id` and nothing else. `__id` is an accessor rather than
distinguishing content, and in this regime it IS the named refusal, so comparing the
value whole would force the refusal inside the decision it exists to permit. One
exclusion suffices: `__mint.minted` is the only other refusal-valued accessor, and the
tagged sum shields it — its minted and sealed arms live under different key names, and
Nix `==` decides on the name set before forcing any value.

**Caveat on the structural fall-through.** The last bullet is plain Nix `==` on two
selector records, so it forces every value reachable in their payloads. A selector whose
payload holds a throwing value — under any key name, `__id` included — aborts rather than
deciding. This is a property of structural equality over caller-supplied match
specifications, not of the identity regimes: an ordinary key carrying a throw aborts
identically, measured. The `entity` and `coord` branches are unaffected, comparing
`id_hash` and never the payload.

Raw `==` is finer than `selectorEq` exactly on the display-only `name`; dedup paths
(neededBy sets, dispatch rule-sets) use `selectorEq`.

## Adapters

Each adapter produces (or is fed into) a five-field context; `matches` never depends on
an adapter directly.

### `adapters.scope.mkContext`

```
{ node, get,
  project  ? (n: (n.decls or {}) // { inherit (n) type; }),
  entryFor ? (id: (node id).decls.__entry or null),
} -> context
```

Bridges gen-scope's accessor pair. `data id = (project (node id)) // { __identity = …; }`
— the `__identity` record (or `null`) is composed outside the projection and merged last
(a decl named `__identity` cannot shadow it). `__identity.kind` is copied from the
positional node `type`; `entryFor` defaults to the `decls.__entry` registration
convention. `__identity` is always present, so identity/kind selectors are never silently
inert through this adapter.

### `adapters.registry.mkContext`

```
{ nodes, data, parent,
  kind     ? null,                                                      # registry kind VALUE
  entryFor ? (id: let d = data id; in if d ? id_hash then d else null),
  kindFor  ? (_: kind),                                                 # id -> kindValue | kindName | null
} -> context
```

Flat node-list bridge. Derives `children`/`siblings`/`ancestors` from `nodes` + `parent`.
Kind projection cannot default from the datum (gen-schema instances carry no kind field):
pass the registry's `kind` value (validated + normalized to its name) or an explicit
`kindFor` for heterogeneous unions. Omitting both makes `sel.kind` throw kind-blind while
`sel.entity` still works. Default `entryFor` treats `data id` as the entry.

### `adapters.product.mkContext`

```
{ cellIds, coordsFor, dataFor ? (_: {}), parent ? (_: null) } -> context
```

`data id = (dataFor id) // { __coords = coordsFor id; __identity = null; }`. Flat by
default; when `parent` is supplied the registry-adapter derivations apply. Consumes
gen-product's `pgraph.nodes` (`cellIds`) + `pgraph.product.coordsOf` (`coordsFor`) without
importing gen-product.

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
{ __sel = "entity"; id_hash = <sha256>; name = <string|null>; }   # name: display/errors only
{ __sel = "kind";   kind    = <name>; }                           # internal key
{ __sel = "coord";  dim = <string>; id_hash = <sha256>; name = <string|null>; }

# __identity — reserved projection into `data id` (enriched adapters)
__identity = null;                                 # not entity-backed
__identity = { id_hash = <sha256>; kind = <name|null>; entry = <registry-entry>; };

# __coords — reserved projection into `data id` (product adapter)
__coords = { <dim-name> = <registry-entry>; … };
```

A malformed `entryFor`/coordinate value (no `id_hash`) surfaces a named throw at the first
`id_hash` access — never a silent `null`/mismatch — and does not block `kind` matching,
which reads only the positional kind.

## Laws

| Law | Statement                                                                                                                                                                                                                                                          |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| E1  | `entity e` matches iff `__identity` is a record with `.id_hash == e.id_hash`. Equal-identity entries share a match set; any identity-field difference never cross-matches.                                                                                         |
| E2  | `kind K` matches iff `__identity` is a record with non-null `.kind == K.kind`; `.kind == null` throws (kind-blind projection is loud).                                                                                                                             |
| E3  | `entity`/`kind` throw at construction on strings and non-conforming values; no selector is ever produced from a string.                                                                                                                                            |
| E4  | Matching `entity`/`kind` against a context whose `data id` lacks the `__identity` key throws (identity-blind contexts are loud).                                                                                                                                   |
| E5  | `__identity = null` yields `false` (non-entity nodes are quiet — structural recursion over mixed graphs needs no guards).                                                                                                                                          |
| E6  | Through the enriched adapters `__identity` is present for every node; `null` iff no entry; `id_hash`/`kind` coherent by construction; `__identity` overrides same-named projection keys; a malformed entry errors at `id_hash` access, `kind` matching unaffected. |
| E7  | `entity`/`kind`/`coord` selectors are function-free (Nix `==` total); `selectorEq` compares identity fields only (display `name` excluded).                                                                                                                        |
| E8  | Backward compatible: existing selectors, the five-accessor contract, and the graph adapter are byte-compatible; enrichment is additive (`data` output is a superset). Sole break: `sel.entityKind` is removed.                                                     |
| P1  | `coord dim e` matches iff `__coords` is projected, the cell has `dim`, and `__coords.${dim}.id_hash == e.id_hash`.                                                                                                                                                 |
| P2  | `inSlice coords` matches iff every fixed coordinate matches; `inSlice { }` is vacuously true; equal to the hand-written conjunction.                                                                                                                               |
| P3  | `__coords` absent → throw; dim absent from a cell → `false`; malformed coordinate value → throw.                                                                                                                                                                   |
| P4  | Selectors are static: they read only structural context attributes, never resolved values, and force only the node data a match inspects (`entity`/`kind` never force children).                                                                                   |
