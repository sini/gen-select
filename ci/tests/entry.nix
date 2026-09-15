# THE STANDALONE ENTRY'S OWN DEFAULTS — the cells no other cell in this repository can be.
#
# Every other cell here takes `genSelect` from `ci/flake.nix`, which builds it with `import ../lib`
# from ci's own flake INPUTS, so the root shim is never evaluated and its `ci/flake.lock`-backed
# defaults are never forced. That is precisely where this library's non-flake contract lives:
# `import ./. { }` must produce the same library the flake path does, resolving its one dependency
# from `./ci/flake.lock` with no argument supplied and no search path consulted.
#
# ★★ THE CALL IS ARITY-DISPATCHED, NOT `import ../.. { }`. A dependency-free library publishes its
# root as a bare VALUE rather than a function, so the literal application is wrong at those roots by
# design; `if builtins.isFunction v then v { } else v` is the one form total over the roster, and it
# is the same construct the shim's own `dep` uses.
#
# ★★★ THREE CELLS, ONE ORACLE, AND THE FIRST TWO ARE HERMETIC. The obligation is per DEPENDENCY
# PATH, not per library — this library happens to wire exactly one, but the split still matters: a
# cell that reds when the one dependency is unreachable measures the same thing whether it is one
# path or several, and nothing here should carry a coverage figure only a comment states.
#   1. `…-defaults-to-its-own-node` — the WIRED dependency resolves to a node of ITS OWN repository.
#      `expr` and `expected` are both `mapAttrs` over the shim's own formal-to-path map, so the
#      domain is whatever the root wires and never a hand-written list.
#   2. `…-is-the-libs-own-formals` — the DENOMINATOR, taken independently of that map, so an empty
#      map cannot read as a pass.
#   3. `…-forces-every-dependency` — the FORCING half, and the only non-hermetic cell in this file.
#
# ★★ AND FOUR CELLS BELOW THEM, CLOSING THREE INVARIANTS THE THREE ABOVE REST ON: the shim's `wire`
# default (with its control), the `follows` walk — declared ONCE, in `default.nix`, and READ here
# rather than transcribed, so the control over a hermetic fixture lock is the whole oracle for that
# rule — and channel 2 of the shim's three, the `inputs` override bag.
#
# ★★ THE DOMAIN IS THE WIRED SET, NOT THE DECLARED SET — AND IT IS THE `deps` HALF OF THE RECORD
# THE SHIM'S BODY HANDS TO `wire`, NOT THE ATTRSET `./lib` RECEIVES. The two coincide only while
# `wire`'s own default is `{ deps, resolve }: import ./lib deps`, which is a property of ONE LINE OF
# TEXT and is held by `…-the-wire-default-is-the-librarys-own-application` below and by nothing
# else. `paths` reads the `deps` handed to `wire`, so a formal that is declared and never threaded
# into it is invisible to every cell over it. That is a domain statement rather than a gap — the
# shim's declared formals are read by the DENOMINATOR cell against `../../lib`'s own, which is where
# a stray formal surfaces.
#
# ★★★ THE THIRD CELL IS NOT HERMETIC, AND THAT IS ITS WHOLE POINT. Forcing the default IS
# `builtins.fetchTree`, so it reaches the network — the accepted price of measuring the thing at
# all, and the reason it sits apart from the suites that must not. It remains PURE: `fetchTree` on a
# locked node is narHash-addressed, with no channel and no `<…>`.
{ genSelect, ... }:
let
  entry = import ../..;
  dispatched = if builtins.isFunction entry then entry { } else entry;

  # ★★ THE SEAM-CLOSING ARGUMENT SET, BOUND RATHER THAN WRITTEN AT THE APPLICATION. `dep` stops the
  # resolver at the path instead of fetching it, and replacing `wire` publishes the whole record the
  # body hands TO `wire` — whose `deps` half is the attrset `./lib` receives only while `wire`'s own
  # default is `{ deps, resolve }: import ./lib deps`, a text property the cell at the foot of this
  # file is what holds, and whose `resolve` half is the shim's own `follows` rule, which is why
  # nothing below transcribes that rule. So this application is hermetic by CONSTRUCTION and not by
  # luck. It is bound because an argument set written as a literal at `import ../..` is the
  # bare-application shape this domain's structural cells refuse.
  pathArgs = {
    dep = segs: segs;
    wire = args: args;
  };
  seam = import ../.. pathArgs;
  paths = seam.deps;

  # ★★★ THE SHIM'S OWN RESOLVER, READ RATHER THAN RETRANSCRIBED. `default.nix` holds the ONE
  # declaration of the `follows` rule in this library and publishes it in the record its body hands
  # to `wire`; this is that binding and not a copy of it. So the fixture control below drives the
  # expression the shim itself resolves with, and `…-defaults-to-its-own-node` resolves the shim's
  # declared paths by the shim's own rule rather than by a second copy that can agree with its own
  # expectation while both are wrong.
  shimResolve = seam.resolve;

  # ★ THE ci LOCK, READ AS PURE DATA — and the rule that walks it is NOT TRANSCRIBED HERE:
  # `shimResolve` above IS `default.nix`'s binding. A direct edge IS the node key; a `follows` value
  # is a PATH resolved segment by segment from this lock's own root. Never `lock.nodes.<label>` — a
  # last-segment shortcut reads a DIFFERENT node, and a ci lock routinely carries several same-named
  # ones. Reading the lock is pure data; nothing here fetches.
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);

  # ★★ THE RESOLVER IS BOUND OVER ITS LOCK, AND THAT IS WHAT MAKES ITS CONTROL EXPRESSIBLE AT ALL. A
  # `repoOf` closed over THIS lock has no free parameter, so a control could only re-assert the main
  # arm's own value; taking the lock as an argument is what puts the control AT AN INPUT THE MAIN ARM
  # DOES NOT USE. `shimResolve` takes its lock the same way and for the same reason — which is why
  # `default.nix` publishes the LOCK-PARAMETERISED rule rather than its own applied `fetch`. The
  # `lock` formal here deliberately shadows the binding above.
  #
  # ★★★ AND THE CONTROL IS NOT CEREMONY, IT IS THE ENTIRE ORACLE FOR THIS RULE — which this library
  # declares EXACTLY ONCE, in `default.nix`, so *this rule* now names one expression and not two. A
  # cell reading `locked.repo` off a shortcut-indexed node can pass while the shortcut and the real
  # path walk land on different nodes, because `locked.repo` is frequently identical under both —
  # only a hermetic fixture built to disagree by construction can tell the two rules apart, and it is
  # what drives the SHIM's own binding below rather than a second copy of it.
  repoOf = lock: segs: lock.nodes.${shimResolve lock segs}.locked.repo;

  # ★ THE FIXTURE LOCK, AND IT IS TWO CLAIMS IN ONE SHAPE. `root → a` is a DIRECT edge, where the
  # value IS the node key; `a-node → b` is a `follows` PATH resolved from the lock's own root — so
  # both branches of `following` are exercised. Walking `[ "a" "b" ]` lands on `the-walked-node`;
  # indexing the last segment lands on the unrelated node keyed `b`. The two rules disagree BY
  # CONSTRUCTION, which is what makes the control total over every library rather than over the ones
  # whose own lock happens to disagree. It is a literal: nothing here reads a file or fetches.
  followsFixture = {
    root = "root";
    nodes = {
      root.inputs = {
        a = "a-node";
        elsewhere = "the-walked-node";
      };
      a-node.inputs.b = [ "elsewhere" ];
      the-walked-node.locked.repo = "gen-walked";
      b.locked.repo = "gen-indexed";
    };
  };

  # ★★ THE SHIM'S `wire` DEFAULT, COUNTED AS TEXT. `[[:space:]]` spans the newline a formatter may
  # put anywhere inside the default, and COMMENTS ARE STRIPPED FIRST — load-bearing here rather than
  # prophylactic, because the shim's own prose quotes this default, so an unstripped scan keeps
  # reading 1 on a file whose CODE has been rewired. Bound once and read by BOTH cells below: two
  # literals spelled the same are two predicates, and the control would then guard only its own copy.
  wireNeedle = ''wire[[:space:]]*\?[[:space:]]*[{][[:space:]]*deps[[:space:]]*,[[:space:]]*resolve[[:space:]]*[}][[:space:]]*:[[:space:]]*import[[:space:]]+\./lib[[:space:]]+deps[[:space:]]*,'';
  countWire =
    text:
    builtins.length (
      builtins.filter builtins.isList (
        builtins.split wireNeedle (
          builtins.concatStringsSep "" (builtins.filter builtins.isString (builtins.split "#[^\n]*" text))
        )
      )
    );
in
{
  # The two entry paths are ONE library. `genSelect` is built from ci's flake inputs, `dispatched`
  # from the same `ci/flake.lock` read as data — so this compares the two suppliers of one
  # construction rather than an expression with itself, and NOT the root against `flake.lib`: under
  # L3 those are the same expression, and a cell built that way cannot fail. Raw `dispatched ==
  # genSelect` is not the alternative either — `./lib`'s surface carries function-valued members, and
  # Nix `==` THROWS rather than reading false the moment it descends into comparing two functions.
  # `attrNames` compares only the published SURFACE SHAPE the two suppliers agree on, which is both
  # comparable and the thing actually worth asserting here.
  flake.tests.entry.test-the-defaulted-entry-publishes-the-flake-surface = {
    expr = builtins.attrNames dispatched;
    expected = builtins.attrNames genSelect;
  };

  # ★★ THE WIRED DEPENDENCY RESOLVES, AND RESOLVES TO A NODE OF ITS OWN REPOSITORY. The shim states
  # its intent as a PATH; this resolves that path through the same lock by the same rule and asks
  # which repository the node it lands on belongs to. A path repointed at a live-but-wrong dependency
  # — the failure a surface comparison and a whole-seam seal both pass — reds here, naming the formal
  # and the repository it reached.
  #
  # ★ STATED CEILING: `locked.repo` is neither `owner` nor node identity. A same-named repository
  # under another owner passes, and so does a path repointed at a DIFFERENT NODE of the right
  # repository — the shim's declared path is the only statement of intent, so there is no independent
  # `expected` to compare a resolved node against. Recorded open rather than repaired.
  flake.tests.entry.test-every-wired-dependency-defaults-to-its-own-node = {
    expr = builtins.mapAttrs (_: repoOf lock) paths;
    expected = builtins.mapAttrs (formal: _: "gen-" + formal) paths;
  };

  # ★★★ THE DISCRIMINATING HALF OF THE CELL ABOVE — and for the `follows` rule it is the whole
  # oracle, not a supplement to one, because the rule has ONE declaration and `repoOf` is built over
  # it. The two arms SHARE `repoOf`, hence share `shimResolve`, hence share `default.nix`'s own
  # fold; this one exercises it AT AN INPUT THE MAIN ARM DOES NOT USE, a hand-written lock whose
  # path walk and whose last-segment shortcut land on different nodes by construction. Replace the
  # fold in `default.nix` with the shortcut and this reds; the cell above cannot be relied on to —
  # it reads `locked.repo`, which the two rules can agree on even while disagreeing on the NODE.
  flake.tests.entry.test-control-the-follows-resolver-discriminates = {
    expr = repoOf followsFixture [
      "a"
      "b"
    ];
    expected = "gen-walked";
  };

  # ★★ THE DENOMINATOR, TAKEN INDEPENDENTLY — without it the cell above is vacuous over an empty map.
  # `paths` is what the root WIRES; `functionArgs (import ../../lib)` is what the library REQUIRES,
  # read from a different file by a different builtin. A dependency dropped from the shim's body reds
  # here even though every surviving path still resolves.
  flake.tests.entry.test-the-wired-dependency-set-is-the-libs-own-formals = {
    expr = builtins.attrNames paths;
    expected = builtins.attrNames (builtins.functionArgs (import ../../lib));
  };

  # ★★★ THE DEFAULTS THEMSELVES, FORCED. `builtins.seq` of the dispatched root runs the shim's eager
  # body, which forces every wired dependency to WHNF before `./lib` sees it — so this reaches a
  # nonexistent node, an unresolvable follows path or a throwing root at the BOUNDARY, rather than
  # wherever a consumer first happens to reach it.
  #
  # ★ THE FORCE STOPS AT WHNF, DELIBERATELY: `seq` of an attrset does not force its members, so this
  # never reaches into the dependency's own surface and a member it deliberately refuses to build is
  # not an exception to it.
  flake.tests.entry.test-the-defaulted-entry-forces-every-dependency = {
    expr = builtins.seq dispatched "forced";
    expected = "forced";
  };

  # ★★★ THE SHIM'S OWN `wire` DEFAULT, AND IT IS WHAT EVERY HERMETIC CELL ABOVE RESTS ON. `paths` is
  # the `deps` half of the record the shim's body hands to `wire` — it is the attrset `./lib`
  # RECEIVES only while `wire`'s own default is `{ deps, resolve }: import ./lib deps`, and no cell
  # above reads that default: the two hermetic cells REPLACE `wire` with `args: args`, the forcing
  # cell stops at WHNF of whatever `wire` returned, and the surface cell compares `attrNames`, which
  # `./lib`'s structure fixes independently of its arguments.
  #
  # ★★ THE READING IS IRREDUCIBLY TEXTUAL, AND THAT IS THE SEAM'S OWN REASON FOR EXISTING: Nix
  # publishes WHETHER a formal has a default and never WHAT it is, so there is no semantic
  # construction to compare against.
  flake.tests.entry.test-the-wire-default-is-the-librarys-own-application = {
    expr = countWire (builtins.readFile ../../default.nix);
    expected = 1;
  };

  # ★★★ THE DISCRIMINATING HALF, IN THREE ARMS BECAUSE THE PREDICATE HAS THREE WAYS TO BE DEAD. Both
  # cells read the one `countWire` binding, and this one exercises it AT AN INPUT THE MAIN ARM DOES
  # NOT USE — assembled fixtures, never `../../default.nix`. `exact` proves it can count the real
  # default at all; `rewired` proves it refuses the one-token corruption the main arm exists to
  # catch; `commented` proves the comment strip is LIVE, and that arm is the sharp one — the same
  # text unstripped reads 1, which is precisely the false green a scan of a self-documenting shim
  # would otherwise return.
  flake.tests.entry.test-control-the-wire-default-check-discriminates = {
    expr = {
      exact = countWire "wire ? { deps, resolve }: import ./lib deps,";
      rewired = countWire ''wire ? { deps, resolve }: import ./lib (deps // { x = throw "no"; }),'';
      commented = countWire ''
        # wire ? { deps, resolve }: import ./lib deps,
        wire ? { deps, resolve }: import ./lib (deps // { }),
      '';
    };
    expected = {
      exact = 1;
      rewired = 0;
      commented = 0;
    };
  };

  # ★★★ CHANNEL 2 — THE `inputs` OVERRIDE BAG. The shim declares three channels and one precedence:
  # a named formal wins, the bag is next, tested by attrset membership, and the ci lock is the
  # default. Every cell above exercises the LOCK, so a formal transcribed as `x ? dep [ … ]` instead
  # of `x ? inputs.gen-x or (dep [ … ])` leaves its override silently ignored.
  #
  # ★★ TOTAL OVER THE WIRED SET BY CONSTRUCTION. `expr` and `expected` are both derived from
  # `paths`, so the domain is whatever the root wires and never a hand-written list, and the
  # denominator is taken independently by `…-is-the-libs-own-formals`, so an empty map cannot read as
  # a pass. The sentinels are DISTINCT per formal, so a bag key wired to the wrong formal reds too.
  # It is hermetic: `pathArgs` closes `dep`, and with every formal overridden no default is reached.
  flake.tests.entry.test-the-inputs-bag-overrides-every-wired-default =
    let
      overrides = builtins.mapAttrs (formal: _: "the ${formal} override, from the inputs bag") paths;
      bag = builtins.listToAttrs (
        map (formal: {
          name = "gen-" + formal;
          value = overrides.${formal};
        }) (builtins.attrNames paths)
      );
    in
    {
      expr = (import ../.. (pathArgs // { inputs = bag; })).deps;
      expected = overrides;
    };
}
