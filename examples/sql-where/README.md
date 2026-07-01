# sql-where

A tiny SQL `WHERE`-clause front-end for [`gen-select`](https://github.com/sini/gen-select).

It parses a familiar `WHERE` string into a `gen-select` selector, so nodes can be
filtered with SQL-ish predicates instead of hand-built selector trees:

```nix
compile "env = 'prod' AND (type = 'host' OR type = 'cache')"
# => sel.and [ (sel.attrs { env = "prod"; }) (sel.any [ (sel.attrs { type = "host"; }) (sel.attrs { type = "cache"; }) ]) ]
```

The compiled selector is evaluated with `genSelect.matches selector nodeId ctx`.

## What it shows

- Building `gen-select` selectors programmatically from an external surface syntax.
- The selector constructors used: `attrs`, `not`, `and`, `any`.
- Matching a selector against node data via a minimal accessor `ctx`
  (`data`, `parent`, `children`, `ancestors`).

## Supported grammar

- Comparisons: `key = 'value'`, `key != 'value'`
- Membership: `key IN ('a', 'b', ...)`
- Boolean: `AND`, `OR`, `NOT` (with `(` `)` grouping)

## Layout

- `lib/where.nix` — tokenizer + recursive-descent parser producing a `gen-select` selector.
- `tests/where-parse.nix` — asserts the shape of compiled selectors.
- `tests/where-match.nix` — asserts match results against mock node data.

## Running the tests

```sh
nix run nixpkgs#nix-unit -- --flake .#tests
# or, from the dev shell:
nix develop -c just ci
```
