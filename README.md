# gen-select — selector algebra for attributed graph positions

[![CI](https://github.com/sini/gen-select/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-select/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Pure pattern matching library for Nix. Selectors are `{ __sel = tag; ... }` attrsets matched by `matches` against an ID-based accessor context. Zero dependencies (Class A pure) — builtins only, no nixpkgs.lib and no gen-algebra; the intensional-equality check is inlined.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Quick Start](#quick-start)
- [Core API](#core-api)
- [Adapters](#adapters)
- [Demo Templates](#demo-templates)
- [Performance](#performance)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

gen-select provides a compositional selector algebra for querying positions in attributed graphs. Selectors express structural and data predicates — "nodes whose parent has attribute X", "nodes with a descendant matching Y" — without coupling to any particular graph representation.

The library has three layers:

1. **Constructors** — build selector values (`sel.star`, `sel.attrs`, `sel.and`, `sel.within`, etc.)
1. **Match engine** — `matches selector id ctx` evaluates a selector against an accessor-based context
1. **Adapters** — bridge selectors to gen-scope and gen-graph

Selectors are plain attrsets tagged with `__sel`. No special types, no evaluation order dependencies, no side effects.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record, search monad, either, intensional identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs) |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch) |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Relational rule dispatch STEP (stratified phases, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-rebuild](https://github.com/sini/gen-rebuild) | Pure-Nix incremental rebuilder (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | Pure-Nix vars/secrets (den-agnostic) |

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

gen-select declares no flake inputs, so it adds no transitive dependency — not even nixpkgs.

### Without flakes

```nix
let
  sel = (import ./path/to/gen-select).lib;
in
sel.matches (sel.attrs { role = "backend"; }) "api" myContext
# => true if myContext.data "api" has role = "backend"
```

## Core API

### Context shape

`matches` takes a context record with five accessor functions:

| Field | Type | Purpose |
|-------|------|---------|
| `data` | `id -> attrset` | attribute data for a node |
| `parent` | `id -> id \| null` | immediate parent |
| `children` | `id -> [id]` | direct children |
| `ancestors` | `id -> [id]` | ancestor chain (parent to root) |
| `siblings` | `id -> [id]` | sibling nodes (same parent, excluding self) |

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

| Constructor | Signature | Matches when |
|-------------|-----------|--------------|
| `sel.star` | `-> selector` | always |
| `sel.attrs a` | `attrset -> selector` | all k:v in `a` equal in `data id`; missing key = no match |
| `sel.and ss` | `[selector] -> selector` | all match; `sel.and [] = true` |
| `sel.any ss` | `[selector] -> selector` | any matches; `sel.any [] = false` |
| `sel.not s` | `selector -> selector` | does not match |
| `sel.has s` | `selector -> selector` | any child matches |
| `sel.within s` | `selector -> selector` | any ancestor matches |
| `sel.parentMatches s` | `selector -> selector` | immediate parent matches |
| `sel.child p c` | `sel -> sel -> selector` | sugar: `and [ c (parentMatches p) ]` |
| `sel.descendant a d` | `sel -> sel -> selector` | sugar: `and [ d (within a) ]` |
| `sel.when fn` | `fn -> selector` | `fn id ctx` returns true |

The `__sel` tags are: `"star"`, `"attrs"`, `"and"`, `"any"`, `"not"`, `"has"`, `"within"`, `"parentMatches"`, `"child"`, `"descendant"`, `"when"`.

Note: `child` and `descendant` are sugar — they expand to `and` compositions at construction time and carry no distinct `__sel` tag at runtime.

### sel.when and identity

`sel.when` wraps a bare lambda as a selector. By default, two `when` selectors cannot be compared for equality (lambdas are not comparable in Nix).

For equality support, pass an intensional function — a plain attrset carrying a `name`, a `closure`, and a `__functor`. gen-select is zero-dep, so you construct this record directly (no `mkIntensional` helper is bundled):

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

`selectorEq` compares two selectors. For `when` selectors, when both wrap intensional functions it compares them by program point (name equality) — a conservative check inlined from the former `gen-algebra.intensionalEq` (Palmer §2.3), so gen-select carries no dependency for it; otherwise it returns false. For all other selector types, it uses structural equality (`==`).

## Adapters

### adapters.scope — gen-scope bridge

```
adapters.scope.mkContext : { node, get } -> context
```

Builds a selector context from gen-scope's accessor pair. Maps scope accessors to the five context fields:

| Context field | Implementation |
|---------------|---------------|
| `data` | `id: (node id).decls` |
| `parent` | `id: (node id).parent` |
| `children` | `id: attrNames (get id "children")` |
| `ancestors` | walks `parent` chain, cycle-safe |
| `siblings` | children of parent, excluding self |

### adapters.graph — gen-graph bridge

```
adapters.graph.mkPredicate      : selector -> context -> (id -> bool)
adapters.graph.mkSelectPredicate : selector -> context -> (attrset -> bool)
```

`mkPredicate` curries `matches` into a predicate suitable for gen-graph traversal filters (e.g., `reachableWhere`).

`mkSelectPredicate` wraps `matches` for use with `graph.select`, expecting an attrset with an `id` field.

## Demo Templates

### CSS Selectors (`examples/css-selectors/`)

Maps CSS selector syntax concepts to gen-select combinators. Demonstrates `sel.attrs` as element/class selectors, `sel.descendant` and `sel.child` as CSS combinators, `sel.has` as `:has()`, and `sel.not` as `:not()`. Tests verify the mapping against a DOM-like tree context.

### SQL WHERE (`examples/sql-where/`)

Maps SQL WHERE clause concepts to gen-select. Demonstrates `sel.attrs` as column equality, `sel.and`/`sel.any` as AND/OR, `sel.not` as NOT, and `sel.when` for range predicates and LIKE patterns. Tests verify against a table-like flat context.

## Performance

gen-select evaluates selectors lazily through accessor functions. When wired to gen-scope:

- **O(1) data access** — each `ctx.data id` call hits gen-scope's memoized evaluation; repeated access for the same node evaluates once
- **Proportional to selector structure** — `matches` only inspects what the selector asks for; `sel.attrs { role = "x"; }` touches one field, not the full node
- **No Tier 2 materialization** — selectors never enumerate all nodes; the caller decides iteration scope
- **Structural combinators short-circuit** — `sel.and` stops at the first false; `sel.any` stops at the first true
- **Ancestor/child walks are bounded** — `within` and `has` traverse only the relevant subtree or chain, not the full graph

Memory consumption is proportional to what the selector inspects, not the total graph size.

## Testing

```bash
# CI test suite (core library)
cd ci && just ci

# CSS selectors demo
cd examples/css-selectors && just ci

# SQL WHERE demo
cd examples/sql-where && just ci
```

Or via nix-unit directly:

```bash
nix-unit --override-input gen-select . --flake ./ci
```

The core suite is **104 tests across 9 suites** (`constructors`, `match-basic`, `match-structural`, `composition`, `sugar`, `when`, `adapters`, `adapter-registry`, `purity`) and requires [nix-unit](https://github.com/nix-community/nix-unit).

## Theoretical Foundations

gen-select draws on both academic research and industrial standards. Each source falls into one of two categories: **Implements** (the library directly realizes constructs from the source) or **Informed by** (the source shaped design decisions without direct structural correspondence).

### Implements

| Source | Relationship |
|--------|-------------|
| **Palmer, Filardo & Wu (2024)** — *Intensional Functions* | `sel.when` wraps lambdas as selectors; `isIdentified` and `selectorEq` realize intensional identity and equality via program point (name) comparison ONLY — a further conservative approximation (Palmer 2024 Theorem 1 (closure consistency) / §2.3 conservative-equality model) |
| **CSS Selectors Level 4** — W3C | Structural selector vocabulary: `sel.has` as `:has()`, `sel.not` as `:not()`, `sel.child` and `sel.descendant` as CSS combinators |

### Informed by

| Source | Relationship |
|--------|-------------|
| **Neron, Tolmach, Visser & Wachsmuth (2015)** — *A Theory of Name Resolution* | The five-field accessor context (`data`, `parent`, `children`, `ancestors`, `siblings`) models the P-edge (parent/child/ancestor) traversal axes of a scope graph; does NOT implement the resolution calculus (no well-formedness, specificity, shadowing, or import edges) |
| **Arntzenius & Krishnaswami (2016)** — *Datafun: A Functional Datalog* | Monotone pattern matching over lattice-structured data informed the design of composable selector predicates that respect structural ordering |
| **Reynolds (1983)** — *Types, Abstraction, and Parametric Polymorphism* | Parametricity constraints on selector generality: selectors operate uniformly over any context satisfying the accessor interface, not over concrete representations |
| **Mokhov (2017)** — *Algebraic Graphs with Class* | Algebraic composition of graph predicates (overlay/connect as selector combinators) informed how `sel.and`/`sel.any` compose without coupling to graph representation |
| **XPath 3.1** — W3C | Axis-based navigation model (ancestor, child, descendant, sibling) informed the context accessor vocabulary and structural combinator naming |
