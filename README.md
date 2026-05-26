# gen-select — selector algebra for attributed graph positions

Pure pattern matching library for Nix. Selectors are `{ __sel = tag; ... }` attrsets matched by `matches` against an ID-based accessor context. Depends on gen pure tier only.

## Overview

gen-select provides a compositional selector algebra for querying positions in attributed graphs. Selectors express structural and data predicates — "nodes whose parent has attribute X", "nodes with a descendant matching Y" — without coupling to any particular graph representation.

The library has three layers:

1. **Constructors** — build selector values (`sel.star`, `sel.attrs`, `sel.and`, `sel.within`, etc.)
2. **Match engine** — `matches selector id ctx` evaluates a selector against an accessor-based context
3. **Adapters** — bridge selectors to gen-scope and gen-graph

Selectors are plain attrsets tagged with `__sel`. No special types, no evaluation order dependencies, no side effects.

## Quick Start

### As a flake input

```nix
{
  inputs.gen-select.url = "github:sini/gen-select";
  outputs = { gen-select, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      sel = gen-select.lib;
    in {
      # sel.matches, sel.star, sel.attrs, sel.and, ...
    };
}
```

### Without flakes

```nix
let
  lib = (import <nixpkgs> {}).lib;
  sel = import ./path/to/gen-select { inherit lib; };
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
| `sel.or ss` | `[selector] -> selector` | any matches; `sel.or [] = false` |
| `sel.not s` | `selector -> selector` | does not match |
| `sel.has s` | `selector -> selector` | any child matches |
| `sel.within s` | `selector -> selector` | any ancestor matches |
| `sel.parentMatches s` | `selector -> selector` | immediate parent matches |
| `sel.child p c` | `sel -> sel -> selector` | sugar: `and [ c (parentMatches p) ]` |
| `sel.descendant a d` | `sel -> sel -> selector` | sugar: `and [ d (within a) ]` |
| `sel.when fn` | `fn -> selector` | `fn id ctx` returns true |

The `__sel` tags are: `"star"`, `"attrs"`, `"and"`, `"or"`, `"not"`, `"has"`, `"within"`, `"parentMatches"`, `"child"`, `"descendant"`, `"when"`.

Note: `child` and `descendant` are sugar — they expand to `and` compositions at construction time and carry no distinct `__sel` tag at runtime.

### sel.when and identity

`sel.when` wraps a bare lambda as a selector. By default, two `when` selectors cannot be compared for equality (lambdas are not comparable in Nix).

For equality support, pass an intensional function (created via `gen.pure.mkIntensional`):

```nix
myPred = gen.pure.mkIntensional {
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

`selectorEq` compares two selectors. For `when` selectors, it delegates to `genPure.intensionalEq` when both are intensional; otherwise returns false. For all other selector types, it uses structural equality (`==`).

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

### CSS Selectors (`templates/css-selectors/`)

Maps CSS selector syntax concepts to gen-select combinators. Demonstrates `sel.attrs` as element/class selectors, `sel.descendant` and `sel.child` as CSS combinators, `sel.has` as `:has()`, and `sel.not` as `:not()`. Tests verify the mapping against a DOM-like tree context.

### SQL WHERE (`templates/sql-where/`)

Maps SQL WHERE clause concepts to gen-select. Demonstrates `sel.attrs` as column equality, `sel.and`/`sel.or` as AND/OR, `sel.not` as NOT, and `sel.when` for range predicates and LIKE patterns. Tests verify against a table-like flat context.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-algebra](https://github.com/sini/gen-algebra) | Core — intensional functions, pure utilities |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries — kinds, instances, collections, refs |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect types — traits, classification, dispatch |
| [gen-graph](https://github.com/sini/gen-graph) | Graph queries — accessor-based combinators, traversal, fixpoint |
| [gen-scope](https://github.com/sini/gen-scope) | Scope graphs — construction, evaluation, resolution |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra — pattern matching for attributed graph positions |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding — inject external args into NixOS modules |

## Performance

gen-select evaluates selectors lazily through accessor functions. When wired to gen-scope:

- **O(1) data access** — each `ctx.data id` call hits gen-scope's memoized evaluation; repeated access for the same node evaluates once
- **Proportional to selector structure** — `matches` only inspects what the selector asks for; `sel.attrs { role = "x"; }` touches one field, not the full node
- **No Tier 2 materialization** — selectors never enumerate all nodes; the caller decides iteration scope
- **Structural combinators short-circuit** — `sel.and` stops at the first false; `sel.or` stops at the first true
- **Ancestor/child walks are bounded** — `within` and `has` traverse only the relevant subtree or chain, not the full graph

Memory consumption is proportional to what the selector inspects, not the total graph size.

## Testing

```bash
# CI test suite (core library)
cd templates/ci && just ci

# CSS selectors demo
cd templates/css-selectors && just ci

# SQL WHERE demo
cd templates/sql-where && just ci
```

Or via nix-unit directly:

```bash
nix-unit --override-input gen-select . --flake ./templates/ci
```

## References

| Source | Relevance |
|--------|-----------|
| **Palmer & Watts (2011)** — *Computability of Selector Functions* | Theoretical foundation for selector expressiveness bounds |
| **Arntzenius & Krishnaswami (2016)** — *Datafun: A Functional Datalog* | Monotone pattern matching over lattice-structured data |
| **Reynolds (1983)** — *Types, Abstraction, and Parametric Polymorphism* | Parametricity constraints on selector generality |
| **CSS Selectors Level 4** — W3C | `:has()`, `:not()`, combinators — structural selector vocabulary |
| **XPath 3.1** — W3C | Axis-based navigation (ancestor, child, descendant, sibling) |
| **Neron et al. (2015)** — *A Theory of Name Resolution* | Scope graph traversal as selector context model |
| **Mokhov (2017)** — *Algebraic Graphs with Class* | Algebraic composition of graph predicates |

## License

MIT
