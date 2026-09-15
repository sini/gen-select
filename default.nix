# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# THREE CHANNELS, ONE PRECEDENCE, AND NONE OF THEM IS A PROBE. A named formal per dependency wins;
# the `inputs` bag is next, tested by attrset membership so a supplied-but-throwing value throws as
# ITSELF rather than falling back; the default is resolved from `./ci/flake.lock`, read as local
# data. There is NO `...`: an argument this root does not declare is a loud error, not a silent drop.
#
# THE PIN SOURCE IS `ci/flake.lock`, NOT THE ROOT `flake.lock`. The root lock stays the flake path's
# lock and is no longer read by Nix code, which is what lets one rule hold across the roster: a root
# lock exists only where the root flake declares inputs, while `ci/flake.lock` exists everywhere —
# including at the libraries that declare no inputs at all and so could hold no shim under the old
# rule. gen-algebra is a root input of the ci lock, so the path below is one segment long.
#
# `src` AND `dep` ARE FORMALS, NOT `let` BINDINGS, AND THAT IS THE INJECTABLE RESOLVER SEAM — the
# one channel a cell can close. `src` is the only expression here that fetches; everything else
# reads the lock as data. A caller supplying `src = segs: throw "…"` therefore makes fetching
# IMPOSSIBLE for that application rather than merely absent, which is what `ci/tests/entry.nix`
# rests on. A `dep` bound in the `let` below would close over the `let`'s `src`, so the override
# would silently do nothing and the shim would fetch anyway, at rc 0.
#
# The `let` is OUTSIDE the lambda because a formal's default is evaluated in the FORMAL scope, which
# does not see a `let` in the body.
let
  lock = builtins.fromJSON (builtins.readFile ./ci/flake.lock);
  # A direct edge IS the node key; a `follows` value is a PATH resolved segment by segment from this
  # lock's own root. Never by indexing `lock.nodes.<label>` — a last-segment shortcut reads a
  # different node. IT TAKES ITS LOCK AS AN ARGUMENT SO THAT THE ENTRY CELL CAN DRIVE THIS EXACT
  # BINDING ON A FIXTURE WHERE THE TWO RULES DISAGREE BY CONSTRUCTION; a resolver closed over this
  # library's own lock could only ever be compared against a second copy of itself. This is the ONE
  # declaration of the rule in this library — `ci/tests/entry.nix` reads this binding through the
  # record the body hands `wire`, instead of transcribing the fold a second time.
  resolve =
    lock:
    let
      following =
        node: inp:
        let
          v = (lock.nodes.${node}.inputs or { }).${inp};
        in
        if builtins.isString v then v else builtins.foldl' following lock.root v;
    in
    segs: builtins.foldl' following lock.root segs;
  fetch = resolve lock;
in
{
  inputs ? { },
  src ? segs: "${builtins.fetchTree lock.nodes.${fetch segs}.locked}",
  # Arity dispatch, because a dependency's root is a function at a shim'd library and a bare value
  # at a leaf, and neither `import p` nor `import p { }` is total over both.
  dep ?
    segs:
    let
      v = import (src segs);
    in
    if builtins.isFunction v then v { } else v,
  # `wire` IS THE THIRD SEAM, AND IT IS THE ONLY WAY ANYTHING LEAVES THIS FILE. Nix publishes
  # WHETHER a formal has a default and never WHAT it is, and a formal is an INPUT channel that
  # cannot carry a value outward at all — so the only place a formal NAME and its resolved PATH are
  # both in scope is this file's argument TO `wire`, and `resolve` leaves by that same argument
  # rather than by a fourth formal. What `./lib` actually receives is a different question: `wire`
  # RECEIVES `{ deps, resolve }`, and passes on whatever it chooses to — here `deps` and nothing
  # else, but only because the default below reads `{ deps, resolve }: import ./lib deps,`. A cell
  # injecting `dep = segs: segs` alongside `wire = args: args` reads this shim's own formal-to-path
  # map AND its own resolver directly, with nothing fetched, no path restated and no fold
  # transcribed. The record destructures with no `...`, so a drifted body shape is loud at the
  # default; adding `wire` was a widening and breaks no caller for the same reason — there is no
  # `...` here, and no caller passes a name this root does not declare.
  wire ? { deps, resolve }: import ./lib deps,
  algebra ? inputs.gen-algebra or (dep [ "gen-algebra" ]),
}:
# THE BODY IS EAGER, AND THAT IS WHAT MAKES THE ENTRY CELL TOTAL RATHER THAN PARTIAL. `forced` forces
# every wired dependency to WHNF before `./lib` sees it, so a default that cannot resolve is loud AT
# THE BOUNDARY rather than wherever a consumer first reaches an attribute. Without it a force of this
# root reaches none of its dependency paths: the body's own return value is already an attrset shell
# in WHNF (`import ./lib deps` resolves to `lib/default.nix`'s outer `{ ... }`), so `builtins.seq` of
# it never enters the lambda that binds `algebra`, and `builtins.deepSeq` on the flake's exported
# surface cannot make up the difference either — it does not enter a lambda, and the standalone path
# is not wrapped in it at all. With the eager body a WHNF force of the root reaches `algebra`,
# whatever the published surface's shape.
#
# THE FORCE STOPS AT WHNF DELIBERATELY: `builtins.seq` of an attrset does not force its members, so
# this reaches the dependency's root VALUE and never a member of it. A library that deliberately
# refuses to build some member is therefore not an exception to it.
let
  deps = { inherit algebra; };
  forced = builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) deps) null;
in
builtins.seq forced (wire {
  inherit deps resolve;
})
