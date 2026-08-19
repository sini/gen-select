# gen-select — agent capability sheet

## Scope

Selector algebra for attributed graph positions: builds `{ __sel = tag; … }` predicate values and evaluates them against a caller-supplied five-accessor context (`matches selector id ctx`).

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| Building/evaluating the graph the selectors run over (scope graphs, attribute evaluation) | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Traversal, condensation, phase ordering, query combinators over accessor-graphs | `gen-graph` — "gen-graph: accessor-based graph query combinators" |
| Minting identity (`id_hash`), kinds, instances, registries | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system". gen-select only *reads* `id_hash`; `grep -rn "hashString\|toJSON\|builtins.hash" lib/` returns nothing |
| Constructing product graphs and coordinate tuples (`pgraph.nodes`, `product.coordsOf`) | `gen-product` — "gen-product — graph products as first-class operations over accessor-graphs (Cartesian / tensor / strong / lexicographic; cells, slices, fibers, projections, quotients, restriction, containment chains), lazy in and out". `lib/adapters/product.nix:1-8` states the adapter consumes that accessor shape with no gen-product import |
| Choosing a winner among rules whose selectors matched (guard→effect step, ordering, conflict resolution) | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)" |
| Constructing intensional functions (`mkIntensional`); gen-select bundles no helper and inlines only the one-line equality (`lib/constructors.nix:129-132`) | `gen-algebra` — "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either" |
| Aspect traits/classification | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)" |
| Type checking / `verify` | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem" |
| General utilities (gen-select is zero-dep, builtins-only; `flake.nix:4-6`) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem" |
| Channels / dataflow that *consume* selectors | `gen-pipe` — "gen-pipe — scoped channels + dataflow algebra (map/filter/fold/scan/route/join/tee) with B5 determinism, provenance, dedup, and class-aware contributions"; `gen/lib/mkGenLibs.nix:24-26` records its deps as `prelude+select+scope` |

## Exports

Entry: `inputs.gen-select.lib` (flake). Root `default.nix` and `import ./lib` are the same bare value — not a function, so it takes no dependency argument.

**Leaf selectors** — `lib/constructors.nix`

| Export | Signature |
|---|---|
| `star` | `selector` (a value, not a function) |
| `attrs` | `attrset -> selector` |
| `entity` | `registryEntry -> selector` (requires `? id_hash`; stores `id_hash` + display `name` only) |
| `kind` | `kindValue -> selector` (requires `? kind && ? options`; stores the kind *name*) |

**Combinators** — `lib/constructors.nix`

| Export | Signature |
|---|---|
| `and` / `any` | `[selector] -> selector` |
| `not` | `selector -> selector` |

**Structural** — `lib/constructors.nix`

| Export | Signature |
|---|---|
| `has` / `within` / `parentMatches` | `selector -> selector` (child / ancestor / immediate parent) |
| `child` | `parentSel -> childSel -> selector` (sugar: `and [ c (parentMatches p) ]`) |
| `descendant` | `ancSel -> descSel -> selector` (sugar: `and [ d (within a) ]`) |

**Escape hatch and equality** — `lib/constructors.nix`

| Export | Signature |
|---|---|
| `when` | `(id -> ctx -> bool) -> selector` |
| `isIdentified` | `selector -> bool` (true iff a `when` wrapping `{ name; closure; __functor; }`) |
| `selectorEq` | `selector -> selector -> bool` |

**Match engine** — `lib/match.nix`

| Export | Signature |
|---|---|
| `matches` | `selector -> id -> ctx -> bool` |

**Adapters** — `lib/adapters/`

| Export | Signature |
|---|---|
| `adapters.scope.mkContext` | `{ node, get, project ? …, entryFor ? … } -> ctx` |
| `adapters.registry.mkContext` | `{ nodes, data, parent, kind ? null, entryFor ? …, kindFor ? (_: kind) } -> ctx` |
| `adapters.product.mkContext` | `{ cellIds, coordsFor, dataFor ? (_: {}), parent ? (_: null) } -> ctx` |
| `adapters.product.coord` | `dim -> registryEntry -> selector` (tag `"coord"`) |
| `adapters.product.inSlice` | `{ <dim> = entry; … } -> selector` (sugar: `and` of one `coord` per dim) |
| `adapters.graph.mkPredicate` | `selector -> ctx -> id -> bool` |
| `adapters.graph.mkSelectPredicate` | `selector -> ctx -> data -> bool` (reads `data.id`) |

**Context contract** (consumed, not exported). Every `ctx` supplies five accessors: `data : id -> attrset`, `parent : id -> id|null`, `children : id -> [id]`, `ancestors : id -> [id]`, `siblings : id -> [id]`. `data` may project reserved `__identity` (`{ id_hash; kind; entry; }` or `null`) and `__coords`.

**Runtime tags** dispatched by `matches`: `star`, `attrs`, `entity`, `kind`, `and`, `any`, `not`, `has`, `within`, `parentMatches`, `coord`, `when` (`lib/match.nix:7-98`). No tag for `child`/`descendant`/`inSlice`.

## Entry points by task

| Task | Reach for |
|---|---|
| Match a selector against one node | `matches sel id ctx` |
| Match on node attribute values | `attrs { k = v; }` |
| Match one specific entity | `entity <registry-entry>` (needs an identity-projecting context) |
| Match all entities of a kind | `kind <kind-value>` (needs a kind-bearing projection) |
| Match by position in the tree | `has` / `within` / `parentMatches` / `child` / `descendant` |
| Arbitrary predicate | `when fn`; pass an intensional record if the selector must be comparable |
| Dedup selectors / compare rule sets | `selectorEq` — `==` is finer (it distinguishes display `name`); `selectorEq` is the dedup relation |
| Bridge a gen-scope node tree | `adapters.scope.mkContext` |
| Bridge a gen-schema per-kind registry | `adapters.registry.mkContext` (pass `kind`) |
| Bridge a gen-product cell lattice | `adapters.product.mkContext` + `coord` / `inSlice` |
| Hand a selector to a gen-graph query | `adapters.graph.mkPredicate` / `mkSelectPredicate` |

## Measured traps

Each row verified in this run by evaluating the expression against `import ./lib` (bare `sel`; `blindCtx` = a context whose `data` projects no `__identity`; `entry = { id_hash = "abc"; name = "n1"; }`; `kindV = { kind = "user"; options = {}; }`).

| Trap | Evidence |
|---|---|
| `entity`/`kind` against an identity-blind context **throw**, they do not return false | `lib/match.nix:46-47,62-63`; both `tryEval` runs ⇒ `success = false`. Positive control, same matcher, identity-projecting ctx: `matches (entity entry)` ⇒ `true` |
| `kind` throws on a kind-blind projection *even when* `__identity` is present and `entity` matching works on that same context | `lib/match.nix:66-67`; `kind` ⇒ threw, `entity` on the identical ctx ⇒ `true` |
| `registry.mkContext` called without `kind`/`kindFor` projects `kind = null`, so every later `sel.kind` throws | `lib/adapters/registry.nix:11-27` + `lib/match.nix:67`; ctx built with only `{ nodes; data; parent; }` ⇒ `sel.kind` threw |
| `coord` is **not** a top-level export — it lives on `adapters.product` — although `matches` dispatches the `"coord"` tag | `lib/match.nix:71`, `lib/adapters/product.nix:10-27`; `sel ? coord` ⇒ `false`, `sel.adapters.product ? coord` ⇒ `true` |
| Product cells are never entity-backed: `__identity` is hardcoded `null`, so `entity`/`kind` are **silently false** there (no throw) | `lib/adapters/product.nix:50`; `matches (entity entry) "c1" productCtx` ⇒ `false`, positive control `matches (coord "host" entry) "c1" productCtx` ⇒ `true` |
| A cell missing the coordinate dimension ⇒ `false` (not a throw) | `lib/match.nix:82-84`; missing-dim ⇒ `false`. The sibling branch — a coordinate value lacking `id_hash` ⇒ throw — is read from `lib/match.nix:89-92`, not exercised in this run |
| `and []` ⇒ true, `any []` ⇒ false, `inSlice {}` ⇒ true (it is `and []`) | `lib/match.nix:17-21`, `lib/adapters/product.nix:33`; observed `true` / `false` / `true` |
| `attrs` treats a missing key as no-match, never an error | `lib/match.nix:15`; `matches (attrs { nope = 1; })` ⇒ `false` |
| `scope.mkContext` default projection lets node `type` **override** a decl key named `type` | `lib/adapters/scope.nix:11`; `(ctx.data "x").type` ⇒ `"NODETYPE"` with `decls.type = "DECLTYPE"`. Test: `test-scope-type-wins-over-decl` (`ci/tests/adapters.nix`) |
| `child`/`descendant` carry no distinct tag — both are `and` at runtime | `lib/constructors.nix:82-94`; `(child star star).__sel` and `(descendant star star).__sel` ⇒ `"and"` |
| `selectorEq` on two `when`s wrapping the **same bare lambda** ⇒ `false` (intensional record required) | `lib/constructors.nix:117-125`; observed `false` |
| `selectorEq` is coarser than `==`: entity/coord display `name` is excluded | `lib/constructors.nix:126-129`; two entries, equal `id_hash`, differing `name` ⇒ `selectorEq` `true`, `==` `false` |
| Argument order differs between the engine and the graph adapter | `matches selector id ctx` (`lib/match.nix:3`) vs `mkPredicate selector ctx id` and `mkSelectPredicate selector ctx data` (`lib/adapters/graph.nix:3-8`); all three evaluated `true` on `star` |
| Constructors reject name strings at construction time | `lib/constructors.nix:22-25,41-44`; `entity "axon-01"` and `kind "user"` both threw |
| An unknown `__sel` tag throws rather than returning false | `lib/match.nix:97-98`; `matches { __sel = "bogus"; }` threw |

## Theory

Claimed in `README.md:300-322`, which splits its sources into **Implements** and **Informed by**, and restated in code comments.

**Implements**

- **Palmer, Filardo & Wu (2024), *Intensional Functions*** — `when`/`isIdentified`/`selectorEq` realize intensional identity and equality by program point (name) comparison only; README cites Theorem 1 (closure consistency) and §2.3 conservative equality. Inlined at `lib/constructors.nix:120-123`.
- **W3C CSS Selectors Level 4** — structural vocabulary: `has` = `:has()`, `not` = `:not()`, `child`/`descendant` = CSS combinators; §5.1 type selector `E` lifted from element names to schema kinds as `kind` (`lib/constructors.nix:33-38`).
- **Neron, Tolmach, Visser & Wachsmuth (2015), *A Theory of Name Resolution*** — `entity` is a declaration-identity predicate, `id_hash` playing the declaration-position role (`lib/constructors.nix:11-19`).
- **gen-schema `mkIdentityModule` content-addressed identity** — `sel.entity` delegates identity to gen-schema and performs no hashing of its own.
- **Imrich & Klavžar, *Handbook of Product Graphs*** — `coord`/`inSlice` are the vertex-membership predicate of the sub-product fixing the given coordinates (`lib/adapters/product.nix:1-7`, `lib/match.nix:71-73`).

**Informed by** (README's own label; no result claimed): Neron et al. (2015) again, for the five-accessor context as the P-edge traversal axes of a scope graph — README states it does **not** implement the resolution calculus (no well-formedness, specificity, shadowing, or import edges); Arntzenius & Krishnaswami (2016) *Datafun*; Reynolds (1983) *Types, Abstraction, and Parametric Polymorphism*; Mokhov (2017) *Algebraic Graphs with Class*; W3C XPath 3.1.

**Checked invariant**: zero dependencies (builtins only, no nixpkgs.lib, no gen-algebra) is enforced by `ci/tests/purity.nix` over `lib/**.nix` + root `flake.nix` + `default.nix`.

## Drift check

```sh
nix eval --json .#lib --apply 'l: { top = builtins.attrNames l; adapters = builtins.mapAttrs (_: a: builtins.attrNames a) l.adapters; }'
```

Current output (verbatim):

```json
{"adapters":{"graph":["mkPredicate","mkSelectPredicate"],"product":["coord","inSlice","mkContext"],"registry":["mkContext"],"scope":["mkContext"]},"top":["adapters","and","any","attrs","child","descendant","entity","has","isIdentified","kind","matches","not","parentMatches","selectorEq","star","when","within"]}
```

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml:13,18`):

```sh
nix flake check ./ci
```
