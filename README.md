# gen-select — selector algebra for attributed graph positions

[![CI](https://github.com/sini/gen-select/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-select/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Pure pattern matching library for Nix. Selectors are `{ __sel = tag; ... }` attrsets matched by `matches` against an ID-based accessor context. One dependency — gen-algebra, for the identity-regime discipline `selectorEq` reads. No nixpkgs.lib and no module-system tier; gen-algebra declares no inputs of its own, so a consumer gains a leaf and no closure.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Demo Templates](#demo-templates)
- [Performance](#performance)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

gen-select provides a compositional selector algebra for querying positions in attributed graphs. Selectors express structural and data predicates — "nodes whose parent has attribute X", "nodes with a descendant matching Y" — without coupling to any particular graph representation.

The library has three layers:

1. **Constructors** — build selector values (`sel.star`, `sel.attrs`, `sel.and`, `sel.within`, etc.)
2. **Match engine** — `matches selector id ctx` evaluates a selector against an accessor-based context
3. **Adapters** — bridge selectors to gen-scope and gen-graph

Selectors are plain attrsets tagged with `__sel`. No special types, no evaluation order dependencies, no side effects.

## Gen Ecosystem

| Library                                              | Role                                                                                                                   |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [gen-prelude](https://github.com/sini/gen-prelude)   | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils)                                          |
| [gen-algebra](https://github.com/sini/gen-algebra)   | Pure primitives (record, either, intensional identity)                                                                 |
| [gen-types](https://github.com/sini/gen-types)       | Clean-room MIT structural type checker (leaf/poly checkers; `verify: v → null\|err`)                                   |
| [gen-merge](https://github.com/sini/gen-merge)       | Byte-mode module merge engine (`evalModuleTree`, byte-identical to nixpkgs `lib.evalModules` over the priority subset) |
| [gen-schema](https://github.com/sini/gen-schema)     | Typed registries (kinds, instances, collections, refs); re-hosted on gen-merge                                         |
| [gen-aspects](https://github.com/sini/gen-aspects)   | Aspect type system (traits, classification, dispatch); re-hosted on gen-merge                                          |
| [gen-scope](https://github.com/sini/gen-scope)       | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes)                                    |
| [gen-graph](https://github.com/sini/gen-graph)       | Accessor-based graph query combinators (traversal, condensation, phaseOrder)                                           |
| [gen-select](https://github.com/sini/gen-select)     | **This lib** — Selector algebra (pattern matching over graph positions)                                                |
| [gen-bind](https://github.com/sini/gen-bind)         | Module binding (inject external args into NixOS modules)                                                               |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Relational rule dispatch STEP (stratified phases, conflict resolution)                                                 |
| [gen-memo](https://github.com/sini/gen-memo)         | The incremental plane — decides reuse, never evaluates (change propagation, AFFECTED set)                              |
| [gen-vars](https://github.com/sini/gen-vars)         | Pure-Nix vars/secrets (den-agnostic)                                                                                   |

## Quick Start

### As a flake input

```nix
{
  inputs.gen-select.url = "github:sini/gen-select";
  outputs = { gen-select, ... }:
    let
      sel = gen-select.lib;
    in {
      # sel.matches, sel.star, sel.attrs, sel.and, ...
    };
}
```

gen-select declares exactly one flake input, `gen-algebra`, which itself declares none — so a consumer gains that leaf and nothing behind it, and no nixpkgs. The zero-inputs claim this replaces was retired deliberately: it held while conservative equality was `a.name == b.name`, and the vendored copy of the identity-regime discipline stopped being worth its price once the relation became a dispatch over a tagged sum with a mint comparison on one arm. Four libraries holding four copies of one tagged sum is how the four stop agreeing, and gen-algebra is the one that AUTHORS the tag. The dependency budget is pinned at exactly one by `ci/tests/purity.nix`.

### Without flakes

```nix
let
  sel = (import ./path/to/gen-select).lib;
in
sel.matches (sel.attrs { role = "backend"; }) "api" myContext
# => true if myContext.data "api" has role = "backend"
```

## API Reference

### Context shape

`matches` takes a context record with five accessor functions:

| Field       | Type               | Purpose                                     |
| ----------- | ------------------ | ------------------------------------------- |
| `data`      | `id -> attrset`    | attribute data for a node                   |
| `parent`    | `id -> id \| null` | immediate parent                            |
| `children`  | `id -> [id]`       | direct children                             |
| `ancestors` | `id -> [id]`       | ancestor chain (parent to root)             |
| `siblings`  | `id -> [id]`       | sibling nodes (same parent, excluding self) |

The `id` is not stored in the context — it is the second argument to `matches`.

### matches

```
matches : selector -> id -> context -> bool
```

Evaluates a selector against the node identified by `id` in the given context. Dispatches on the `__sel` tag.

```nix
sel.matches (sel.attrs { type = "service"; }) "web" ctx
# => true if (ctx.data "web").type == "service"
```

### Constructors

| Constructor                                | Signature                                  | Matches when                                                                                                                                                         |
| ------------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sel.star`                                 | `-> selector`                              | always                                                                                                                                                               |
| `sel.attrs a`                              | `attrset -> selector`                      | all k:v in `a` equal in `data id`; missing key = no match                                                                                                            |
| `sel.entity K e`                           | `kind-value -> registry-entry -> selector` | the node's projected identity (`__identity.id_hash`) equals the entry's `id_hash`; at a sealed kind, the kinds are compared too (a sealed collision refuses by name) |
| `sel.kind K`                               | `kind-value -> selector`                   | the node's projected kind (`__identity.kind`) is `K` by minted identity                                                                                              |
| `sel.subkind K`                            | `kind-value -> selector`                   | the node's projected kind is `K`, or has `K` among its transitive ancestors, each decided as `sel.kind` decides                                                      |
| `sel.and ss`                               | `[selector] -> selector`                   | all match; `sel.and [] = true`                                                                                                                                       |
| `sel.anyOf ss`                             | `[selector] -> selector`                   | any matches; `sel.anyOf [] = false`                                                                                                                                  |
| `sel.not s`                                | `selector -> selector`                     | does not match                                                                                                                                                       |
| `sel.has s`                                | `selector -> selector`                     | any child matches                                                                                                                                                    |
| `sel.within s`                             | `selector -> selector`                     | any ancestor matches                                                                                                                                                 |
| `sel.parentMatches s`                      | `selector -> selector`                     | immediate parent matches                                                                                                                                             |
| `sel.child { parent; child; }`             | `{ parent; child; } -> selector`           | sugar: `and [ c (parentMatches p) ]`                                                                                                                                 |
| `sel.descendant { ancestor; descendant; }` | `{ ancestor; descendant; } -> selector`    | sugar: `and [ d (within a) ]`                                                                                                                                        |
| `sel.when fn`                              | `fn -> selector`                           | `fn id ctx` returns true                                                                                                                                             |

The distinct `__sel` tags are: `"star"`, `"attrs"`, `"entity"`, `"kind"`, `"subkind"`, `"and"`, `"any"`, `"not"`, `"has"`, `"within"`, `"parentMatches"`, `"when"` (and `"coord"` from the product adapter).

Note: `child` and `descendant` are sugar — they expand at construction time to `and` compositions and carry no distinct `__sel` tag at runtime. (`sel.entityKind` was removed — see [Identity-bearing selectors](#identity-bearing-selectors).)

### Identity-bearing selectors

`sel.entity` and `sel.kind` match by **entity identity** and **entity kind** rather than by attribute values or structural position. They take values carrying identity — a registry entry, a gen-schema kind value — never `"kind:name"` strings (the identity law: strings are internal keys and display rendering only).

```nix
sel.entity schema.host den.hosts.axon-01   # => { __sel = "entity"; id_hash = "<sha256>"; kind = { identity; name = "host"; sealed; }; name = "axon-01"; }
sel.kind   schema.user                     # => { __sel = "kind"; identity = <mark>; name = "user"; sealed = { }; }
sel.subkind schema.user                    # => { __sel = "subkind"; identity = <mark>; name = "user"; sealed = { }; }
```

- **`sel.entity <kind-value> <registry-entry>`** takes the entry's kind first and judges it at the first application, by the same provenance guard as `sel.kind`; the retired one-argument form `sel.entity entry` therefore refuses by name, catchably, when the selector is used. It then validates the entry structurally (`entry ? id_hash`); a string, or any value lacking `id_hash`, throws with an identity-law message. It stores `id_hash`, the kind's key (`{ identity; name; sealed; }`) and `name` (display/errors) — never the entry itself, whose methods would make Nix `==` on selectors throw. gen-schema mints `id_hash` over the kind's mark, and a mark is minted with a sealed marker at each sealed component, so two kinds that differ only at a sealed component (an unmigrated `lib.types` option, a refinement lambda) share a stamp. At an equal stamp whose kind has sealed components, the match and `selectorEq` therefore compare the two kinds as `sel.kind` does, and a sealed collision is **refused by name**. With no sealed components the stamp is the whole identity and no node kind is read. That shortcut trusts the caller's kind: an entry whose stamp gen-schema did not mint over that same kind (a hand-built mock, a fixture registry entry) is decided by the caller's kind alone.
- **`sel.kind <kind-value>`** takes a gen-schema kind value and validates its **provenance** with the same guard registries use: the value must carry the mint-backed mark gen-schema stamps at construction (`__mint.minted`). A string throws, and so does a hand-written `{ kind = …; options = …; }` — that shape used to be admitted, because the retired `? kind && ? options` test checked none of the provenance its own message named. It stores the kind's **minted identity** as its key (`{ identity; name; sealed; }`; `name` is display-only), and compares through `algebra.sealedCollisionEq`, the helper gen-schema's `kindEq` calls, so a sealed collision is refused by name. A `//` copy of a kind value (`k // { options = …; }`) keeps its mark while changing what it stands for; gen-schema's completion stamp `__kindSelf` tells it from the value its schema built, and the selector's key refuses it by name wherever it is compared, as `kindEq` does (`sel.kind`, `sel.subkind` and `sel.entity`'s kind; a kind carrying no completion stamp is refused by name, as `kindEq` refuses it; the node side, `projectedKindKey`, reads no stamp, so a node whose own kind is a `//` copy still matches, which is deferred). A kind carrying open-module content (an option `default`, `description` or other attribute beyond `type`, or a kind-level definition) has sealed components at those paths, so two separate constructions of one such declaration are refused too; one kind value against itself decides. ★ **That widens the kind-blind refusal:** a kind carrying open content now has sealed components, so `sel.entity` matched in a registry context built without `kind`/`kindFor` throws (kind-blind projection) at every equal stamp, including a node against its own entity; before gen-schema refused open content, such a kind had no sealed components and decided `true` there. Pass `kind` or `kindFor` to a registry context whose kinds declare a `default`, `description`, `apply`, `meta` or any kind-level definition.
- **`sel.subkind <kind-value>`** matches a node whose kind is the given kind or a subkind of it: a kind that reaches it through `inherits`, at any depth. `sel.kind` stays exact. The constructor admits the value through `sel.kind`'s guard and stores the same kind key under its own tag. The adapters project, beside the node's kind key, the kind's transitive ancestors as gen-schema publishes them (`__kindAncestors`, a map from mark to ancestor kind value), as the field `ancestors`; the selector never reads ancestors, so its payload is unchanged. The match decides the node's own kind as `sel.kind` does; otherwise it looks the selector's mark up in the node's ancestor map, and a hit is decided by `kindEq`. A miss is `false`. So a parent of the same name at another mark never matches, a type-only twin of the kind in the lineage is the kind (one identity), and an open-content twin is **refused by name**, never admitted by its mark alone. A projection carrying no ancestor map (a hand projection, or a kind from a gen-schema that does not publish `__kindAncestors`) is refused by name rather than read as having no ancestors.

Both match against a reserved `__identity` record the enriched adapters project alongside node data (shape below). The dispatch is loud where silence would hide a bug:

| `__identity` state                 | `sel.entity`                                                                                                                     | `sel.kind`                         |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| key **absent** from `data id`      | **throw** (identity-blind context)                                                                                               | **throw** (identity-blind context) |
| `null` (node is not entity-backed) | `false`                                                                                                                          | `false`                            |
| record with `kind` null or absent  | matches on `id_hash` for a kind with no sealed components; at an equal stamp of a sealed kind, **throw** (kind-blind projection) | **throw** (kind-blind projection)  |
| record                             | `id_hash` equality, then (sealed kinds only) `kind` by `kindEq`                                                                  | `kind` equality by `kindEq`        |

The throws convert a projection gap (the historical silent-never-match failure) into a named configuration error. A node carrying a positional `type` but no entry does **not** match `sel.kind` — positional-type matching remains `sel.attrs { type = "…"; }`.

`sel.entityKind` (a former string-based sugar) **was removed**; the migration path is `sel.kind <kind-value>`, or `sel.attrs { type = "…"; }` for bare positional typing.

The `__identity` record projected into `data id` by the enriched adapters:

```nix
__identity = null;                    # node is not entity-backed
__identity = {
  id_hash = "<sha256>";               # gen-schema content-addressed identity
  kind    = <kind-key> or null;       # { identity; name; sealed; } from the registry's kind/kindFor; the scope adapter refuses by name
  entry   = <registry-entry>;         # the full entry, for sel.when predicates & consumer interrogation
};
```

### sel.when and identity

`sel.when` wraps a bare lambda as a selector. By default, two `when` selectors cannot be compared for equality (lambdas are not comparable in Nix).

For equality support, pass an intensional function — a plain attrset carrying a `name`, a `closure`, and a `__functor`. gen-select bundles no `mkIntensional` helper — it depends on gen-algebra for the identity-regime discipline `selectorEq` reads, not for the constructor — so you either construct this record directly or build it with `gen-algebra.mkIntensional`, which is a four-argument encoder taking an injected mint and a registry before its constructor name and argument value — worth it where you want a derived identity, overkill where you just need the shape:

```nix
myPred = {
  name = "is-backend";
  closure = { };
  __functor = _: id: ctx: (ctx.data id).role == "backend";
};
sel.when myPred
```

### isIdentified and selectorEq

```
isIdentified : selector -> bool
selectorEq   : selector -> selector -> bool
```

`isIdentified` returns true when a `when` selector wraps an intensional function (has `name`, `__functor`, and `closure` fields).

`selectorEq` compares two selectors. For `when` selectors, when both wrap intensional functions it applies **conservative equality** (Palmer's own term, §2.3/§5.3), which dispatches on the wrapped value's identity REGIME rather than reading one field; otherwise it returns false. For `entity` selectors it compares `id_hash`, and for `coord` selectors `(dim, id_hash)` — the display-only `name` field is excluded, so two entries with equal `id_hash` but differing display names dedup as equal (raw `==` would wrongly distinguish them). `kind` and `subkind` selectors (each with its own tag) compare through gen-schema's `kindEq` relation (`algebra.sealedCollisionEq` over the minted identity and the sealed subjects; `name` excluded). Remaining selector types fall through to structural equality (`==`).

The three regimes are read off the wrapped value's `__mint` field, which is a **tagged sum** and is total — a reader that branched on field presence and then read `.minted` raw would abort uncatchably on a value that has no mintable identity:

| regime     | the value carries     | the relation                                                                     |
| ---------- | --------------------- | -------------------------------------------------------------------------------- |
| minted     | `__mint.minted`       | digest equality — the identity is total in the distinguishing content            |
| unmintable | `__mint`, no `minted` | Nix `==` on its declared subject where it carries one, else on the reified value |
| unmigrated | no `__mint`           | Nix `==` on the reified value — the name never decides                           |

A value built by gen-algebra's encoder (`mkIntensional`) is on the unmintable arm and carries a declared
comparison subject — its registry coordinate (`members`, `revision`), constructor and inert arguments —
so two `when` selectors over two constructions of one registered term compare equal and a different
argument, member set or revision compares unequal; the builder's lambda is never compared.

Palmer's Fig. 5 is a **conjunction** over identity *and* closure, and comparing `name` alone ships its first conjunct only: a program point is constant across a constructor's instances, so a name-only relation calls behaviourally distinct values equal — the coarsening direction §2.3 forbids. What replaces it is the regime dispatch rather than a second conjunct, because a minted identity is already total over the distinguishing content and needs none.

Where nothing is minted the decision compares **the value itself**, never a list of components: an attribute selection is an indirection, so a component-wise form is false even against itself and the relation would be *empty* rather than finer. The whole-value form takes the evaluator's cell fast path instead — two selectors reaching one value compare equal. Its precision is therefore an **allocation artefact**: two separately-constructed equal-shaped values compare unequal, so the relation merges strictly less than Fig. 5 and never more, which is the safe direction for a relation that merely merges work.

The compared subject is that value whole. No field of a type record refuses when forced — demanding an identity is gen-types' `idOf`, a function — and `__mint.minted` is shielded by the tagged sum, since its minted and sealed arms live under *different key names* and Nix `==` decides on the name set before forcing any value. The one path that does force a mint is a minted-against-minted comparison, which never reaches this arm.

### Adapters

The `adapters` attrset bridges selectors to concrete graph representations. Each adapter produces (or is fed into) a five-field context; `matches` never depends on any adapter directly.

#### adapters.scope — gen-scope bridge

```
adapters.scope.mkContext : {
  node,
  get,
  project  ? (n: (n.decls or {}) // { inherit (n) type; }),   # projection surfacing node type
  entryFor ? (id: let n = node id; in if n ? id_hash then n else null),  # id -> entry | null
} -> context
```

Builds a selector context from gen-scope's accessor pair. Maps scope accessors to the five context fields:

| Context field | Implementation                                   |
| ------------- | ------------------------------------------------ |
| `data`        | `id: (project (node id)) // { __identity = …; }` |
| `parent`      | `id: (node id).parent`                           |
| `children`    | `id: attrNames (get id "children")`              |
| `ancestors`   | walks `parent` chain, cycle-safe                 |
| `siblings`    | children of parent, excluding self               |

The enriched adapter composes a reserved `__identity` record (record or `null`) **outside** the projection and merges it last, so identity/kind selectors work through it and a user decl named `__identity` can never shadow it. `__identity.kind` is the key of the gen-schema kind value the node carries (`n.kindValue`, which gen-scope stamps on every node of a kind declared `mkKind { kindValue = schema.<kind>; }`), so `sel.kind` compares minted identities; a node carrying no value is a named refusal, and so is one carrying a value with no mint (a positional node `type` is a name, not a kind declaration, and is never projected as one). The carried value is the one gen-scope admitted: its evaluator refuses a node whose value contradicts its registered kind's, and in a scope whose registry declares no value, a node-carried value is that node's own declaration and is authoritative here; `entryFor` defaults to the node itself when it carries `id_hash` (else `null`); a framework whose identity lives under its own key supplies `entryFor`. `__identity` is always present through this adapter, so entity/kind selectors are never silently inert.

#### adapters.graph — gen-graph bridge

```
adapters.graph.mkPredicate      : selector -> context -> (id -> bool)
adapters.graph.mkSelectPredicate : selector -> context -> (attrset -> bool)
```

`mkPredicate` curries `matches` into a predicate suitable for gen-graph traversal filters (e.g., `reachableWhere`).

`mkSelectPredicate` wraps `matches` for use with `graph.select`, expecting an attrset with an `id` field.

#### adapters.registry — flat node-list bridge

```
adapters.registry.mkContext : {
  nodes, data, parent,
  kind     ? null,                                                      # the registry's kind VALUE
  entryFor ? (id: let d = data id; in if d ? id_hash then d else null), # id -> entry | null
  kindFor  ? (_: kind),                                                 # id -> kindValue | null
} -> context
```

Builds a selector context from a flat registry: an explicit `nodes` list plus `data` and `parent` accessors. The adapter derives the remaining three fields from `nodes` and `parent` — `children` and `siblings` by filtering `nodes` on `parent`, and `ancestors` by walking the `parent` chain (cycle-safe). Use this when nodes are held as a plain list rather than behind a gen-scope evaluator.

Identity enrichment is symmetric with the scope adapter, with one wrinkle: real gen-schema instances carry no kind field, so kind projection **cannot** default from the datum. Pass the registry's `kind` value (registries are per-kind by construction) — validated with the same guard as `sel.kind` and projected as its kind key (a `kindFor` returning a kind name is refused by name) — or an explicit per-id `kindFor` for heterogeneous unions. Omitting both projects `__identity.kind = null`, and any `sel.kind` match then throws (loud kind-blind projection) while `sel.entity` continues to work. The default `entryFor` suits the common case where `data id` **is** the entry.

#### adapters.product — gen-product bridge

```
adapters.product = {
  coord   : dim-name -> kind -> registry-entry -> selector;  # coord "host" schema.host den.hosts.axon-01
  inSlice : { <dim> = { kind; entry; }; … } -> selector;     # sugar: and (coord per fixed dimension)
  mkContext : {
    nodeIds,                  # [ nodeId ]        — gen-product's pgraph.nodes
    coordsFor,                # nodeId -> coords   — gen-product's product.coordsOf
    dataFor ? (_: {}),        # extra matchable cell data
    parent  ? (_: null),      # product lattices are flat by default
    inFlight ? [ ],           # accessors read under construction (discrete/monotone separation)
    kinds ? { },              # dim -> the kind value of that factor's coordinates
  } -> context;
};
```

Matches cells within a gen-product slice by **product coordinates** given as registry entries. A coordinate decides an entity identity at one position, so `coord dim kind e` takes the entry's kind exactly as `sel.entity` does (validated with the same guard, stored as its kind key) and decides as `sel.entity` decides: a cell matches when its `__coords.${dim}.id_hash` equals `e.id_hash` and, when `kind` has sealed components, the context's kind for `dim` is `kind` by `kindEq` — two kinds differing only at a sealed component are **refused by name**, as `sel.kind`, `sel.entity` and gen-schema's `kindEq` refuse them. A cell lacking the dimension is a legitimate heterogeneous union (`false`); a coordinate-blind context or a malformed coordinate value throws. The retired two-argument `coord dim e` is refused by name when the selector is used. `inSlice` expands at construction to the conjunction of one `coord` per fixed dimension, each kind beside its own entry (`inSlice { }` is vacuously true; the retired `{ <dim> = entry; }` value is refused by name). `mkContext` projects `__coords` (and `__identity = null` — cells are not entities), publishes `kinds` once per context as the context field `coordKinds`, and derives structure from `parent` when supplied. The adapter consumes gen-product's accessor shape without importing gen-product.

**`kinds` is required in effect for a factor whose kind has sealed components.** A dimension absent from `kinds` is kind-blind: a migrated kind (no sealed components) decides on the stamp and never reads it, but a sealed coordinate at an equal stamp is refused by name — on its own cell too — because an identity is demanded of a compared value with no subject in hand.

Two residues are stated rather than closed, and both are `sel.entity`'s too. A kind that is **not** its entry's kind but mints the entry's mark (`inSlice { host = { kind = k2; entry = s1; }; }` on `s2`'s cell, where `k2` sealed-collides with `s1`'s kind) is taken on the caller's word, because a gen-schema entry carries its stamp and not its kind; detecting it needs the entry to carry its kind, which is a gen-schema change. And a wrong kind at a *different* mark on a migrated selector is unchecked by the match, which reads no node kind there. A coordinate over a kind with sealed components holds that kind's sealed subjects, which may be functions, so `builtins.toJSON` of such a selector aborts (as it does for `sel.entity`); Nix `==` on two such selectors still decides.

## Demo Templates

### CSS Selectors (`examples/css-selectors/`)

Maps CSS selector syntax concepts to gen-select combinators. Demonstrates `sel.attrs` as element/class selectors, `sel.descendant` and `sel.child` as CSS combinators, `sel.has` as `:has()`, and `sel.not` as `:not()`. Tests verify the mapping against a DOM-like tree context.

### SQL WHERE (`examples/sql-where/`)

Maps SQL WHERE clause concepts to gen-select. Demonstrates `sel.attrs` as column equality, `sel.and`/`sel.anyOf` as AND/OR, `sel.not` as NOT, and `sel.when` for range predicates and LIKE patterns. Tests verify against a table-like flat context.

## Performance

gen-select evaluates selectors lazily through accessor functions. When wired to gen-scope:

- **O(1) data access** — each `ctx.data id` call hits gen-scope's memoized evaluation; repeated access for the same node evaluates once
- **Proportional to selector structure** — `matches` only inspects what the selector asks for; `sel.attrs { role = "x"; }` touches one field, not the full node
- **No Tier 2 materialization** — selectors never enumerate all nodes; the caller decides iteration scope
- **Structural combinators short-circuit** — `sel.and` stops at the first false; `sel.anyOf` stops at the first true
- **Ancestor/child walks are bounded** — `within` and `has` traverse only the relevant subtree or chain, not the full graph

Memory consumption is proportional to what the selector inspects, not the total graph size.

## Testing

```bash
# CI test suite (core library), guarded
nix develop ./ci --command ci
# the gates too; unguarded, blind to an untracked cell
nix flake check ./ci

# CSS selectors demo
cd examples/css-selectors && just ci

# SQL WHERE demo
cd examples/sql-where && just ci
```

`ci` refuses when anything under a declared read root is unknown to git — any extension or name,
`_`-prefixed included — and the remedy is `git add` or a move. The bare `nix-unit --flake ./ci#tests`
and `nix flake check ./ci` are unguarded: they read a git-filtered copy of the tree, so an untracked
cell is silently absent and the run stays green.

The core suite is **271 tests across 23 suites** (`nix-unit --flake ./ci#tests` ⇒ `271/271 successful`; the refusal-message plane `./ci#testsError` ⇒ `55/55`), driven by [nix-unit](https://github.com/nix-community/nix-unit). The twenty-second suite, `gen-ci-examples`, is gen-harness's examples guard (declared in `ci/tests/examples.nix`, `gen.ci.examples`): it holds that `examples/` directory names equal the declared names, and that every declared example forces under `deepSeq`. Alongside the original structural suites (`constructors`, `match-basic`, `match-structural`, `composition`, `sugar`, `when`, `adapters`, `adapter-registry`, `purity`) the identity-selector work adds `constructors-identity`, `match-identity`, `adapter-scope-identity`, `adapter-registry-identity`, `adapter-product`, `coord-sealed`, `subkind`, and `integration-scope`. The last is the acceptance test for the identity/kind routing surface: it drives `sel.kind`/`sel.entity` through a **real `gen-scope.eval` graph seeded from real gen-schema instances**, including the neededBy predicate shape. The `purity` suite is the Class-A invariant, and it now has two arms. It scans every `lib/**.nix` (plus the root `flake.nix`/`default.nix`) for forbidden tokens (`nixpkgs`, `lib.`, `evalModules`, `mkOption`) and fails CI if a nixpkgs or module-system tether creeps back in; and it pins the library's dependency budget at exactly one by asserting the root flake's declared inputs are `[ "gen-algebra" ]`, read from the lock. `gen-algebra` left the forbidden list when the edge was taken deliberately, and the budget arm is what keeps the narrowed invariant as strong as the one it replaced — dropping the token alone would have let a second dependency in unnoticed. Identity validation itself is still structural (`entry ? id_hash`, not a gen-schema import). A sixteenth suite, `entry`, holds the non-flake contract instead: `import ./. { }` must resolve its one dependency from `./ci/flake.lock` and match what the flake path builds.

## Theoretical Foundations

gen-select draws on both academic research and industrial standards. Each source falls into one of two categories: **Implements** (the library directly realizes constructs from the source) or **Informed by** (the source shaped design decisions without direct structural correspondence).

### Implements

| Source                                                                        | Relationship                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Palmer, Filardo & Wu (2024)** — *Intensional Functions*                     | `sel.when` wraps lambdas as selectors; `isIdentified` is the shape guard and `selectorEq` applies **conservative equality** (§2.3, §5.3), dispatching on the wrapped value's identity regime. Program-point (name) comparison survives in no regime: Fig. 5 is a conjunction, so a name-only relation ships one conjunct and coarsens. Neither regime realizes Theorem 1, which is a preservation theorem about 𝜆ITS reduction — gen is not 𝜆ITS and the theorem's soundness does not transfer |
| **CSS Selectors Level 4** — W3C                                               | Structural selector vocabulary: `sel.has` as `:has()`, `sel.not` as `:not()`, `sel.child` and `sel.descendant` as CSS combinators; §5.1 type (element-name) selector `E` lifted from element names to schema kinds as `sel.kind`                                                                                                                                                                                                                                                               |
| **Neron, Tolmach, Visser & Wachsmuth (2015)** — *A Theory of Name Resolution* | `sel.entity` is a declaration-identity predicate: `id_hash` plays the declaration-position role, so shadowing/homonym nodes (equal names, distinct declarations) never cross-match                                                                                                                                                                                                                                                                                                             |
| **gen-schema** — `mkIdentityModule` content-addressed identity                | `sel.entity` delegates identity to gen-schema: it performs no hashing, comparing the `id_hash` gen-schema defines. Equality is exactly gen-schema's instance-identity relation                                                                                                                                                                                                                                                                                                                 |
| **Imrich & Klavžar** — *Handbook of Product Graphs*                           | `coord`/`inSlice` are the vertex-membership predicate of the sub-product obtained by fixing the given coordinates; product graph vertices are coordinate tuples                                                                                                                                                                                                                                                                                                                                |

### Informed by

| Source                                                                        | Relationship                                                                                                                                                                                                                                                                |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Neron, Tolmach, Visser & Wachsmuth (2015)** — *A Theory of Name Resolution* | The five-field accessor context (`data`, `parent`, `children`, `ancestors`, `siblings`) models the P-edge (parent/child/ancestor) traversal axes of a scope graph; does NOT implement the resolution calculus (no well-formedness, specificity, shadowing, or import edges) |
| **Arntzenius & Krishnaswami (2016)** — *Datafun: A Functional Datalog*        | Monotone pattern matching over lattice-structured data informed the design of composable selector predicates that respect structural ordering                                                                                                                               |
| **Reynolds (1983)** — *Types, Abstraction, and Parametric Polymorphism*       | Parametricity constraints on selector generality: selectors operate uniformly over any context satisfying the accessor interface, not over concrete representations                                                                                                         |
| **Mokhov (2017)** — *Algebraic Graphs with Class*                             | Algebraic composition of graph predicates (overlay/connect as selector combinators) informed how `sel.and`/`sel.anyOf` compose without coupling to graph representation                                                                                                     |
| **XPath 3.1** — W3C                                                           | Axis-based navigation model (ancestor, child, descendant, sibling) informed the context accessor vocabulary and structural combinator naming                                                                                                                                |
