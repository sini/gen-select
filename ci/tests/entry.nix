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
# ★★★ AND THREE ARMED PAIRS AT THE HEAD OF THE FILE, OVER THE SHIM'S TEXT AND ITS SIGNATURE — the
# two things no cell above can reach, because every one of them either closes the dependency channel
# or stops its force at WHNF.
#   · `…-no-dependency-is-built-past-its-own-entry` — a direct reach into a dependency's own `lib/`,
#     bypassing `dep`. A lazy, unforced one is a pure TEXT defect, which is exactly the class a
#     forcing cell cannot see.
#   · `…-the-entry-application-is-total` — the shim's DECLARED formal set against `entryArgs`. A
#     formal declared and never threaded into `deps` is in `functionArgs` and in no `paths` key, so
#     this is the one cell in the file that sees it.
#   · `…-the-entry-is-never-applied-to-a-literal` — the STRUCTURAL half, read off this file's own
#     text, so the property survives tomorrow's edit rather than describing today's.
# Each carries its own control, exercising the SAME operand at an input the main arm does not use.
#
# ★★ THE DOMAIN IS THE WIRED SET, NOT THE DECLARED SET — AND IT IS THE `deps` HALF OF THE RECORD
# THE SHIM'S BODY HANDS TO `wire`, NOT THE ATTRSET `./lib` RECEIVES. The two coincide only while
# `wire`'s own default is `{ deps, resolve }: import ./lib deps`, which is a property of ONE LINE OF
# TEXT and is held by `…-the-wire-default-is-the-librarys-own-application` below and by nothing
# else. `paths` reads the `deps` handed to `wire`, so a formal that is declared and never threaded
# into it is invisible to every cell over it. That is a domain statement rather than a gap — the
# shim's DECLARED formals are read by `…-the-entry-application-is-total` against `entryArgs`, which
# is where a stray formal surfaces. The DENOMINATOR cell is a different pair for a different reason:
# it compares the WIRED set against `../../lib`'s own formals and never sees one.
#
# ★★★ THE THIRD CELL IS NOT HERMETIC, AND THAT IS ITS WHOLE POINT. Forcing the default IS
# `builtins.fetchTree`, so it reaches the network — the accepted price of measuring the thing at
# all, and the reason it sits apart from the suites that must not. It remains PURE: `fetchTree` on a
# locked node is narHash-addressed, with no channel and no `<…>`.
{
  genSelect,
  algebra,
  lib,
  ...
}:
let
  entry = import ../..;
  dispatched = if builtins.isFunction entry then entry { } else entry;

  # ★ ONE binding, read by BOTH cells. Duplicating the literal makes the control guard its own copy
  # and nothing else — measured: main copy broken ⇒ 2/2 exit 0 on a tree carrying a real member.
  needle = ''}/lib"[[:space:]]*\{'';

  # The same construction `ci/tests/purity.nix` uses, over the same file, for the same stated reason.
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # ★★ THE SHIM'S DECLARED ARGUMENT SET, BOUND ONCE AND TOTAL BY CONSTRUCTION — the `expected` half
  # of `…-the-entry-application-is-total`, and the only thing in this file that names the shim's
  # DECLARED formals rather than its WIRED ones. The dependency member comes from the SAME binding
  # `ci/flake.nix` builds its `lib` output from, so this set is what an offline application of the
  # root would actually take; the seam members are closed the way that application would close them.
  #
  # ★ STATED CEILING, because it is the difference between this library and the siblings that carry
  # a standalone-application cell: nothing in this file APPLIES this set, so its VALUES are read by
  # no cell and only its key set is oracled. That is enough for the class it exists to catch — a
  # formal the shim declares and never threads into `deps` appears in `functionArgs` and not here,
  # and reds — and it is less than a sibling holding the same set through a live application.
  #
  # ★ THE `throw`s ARE NOT THE GUARD, they are what would make non-hermeticity IMPOSSIBLE rather
  # than merely detected for such an application: a shim carrying `...` would swallow these keys
  # unread and unreported. The guard is the cell pair below.
  entryArgs = {
    inherit algebra;
    inputs = { };
    src = segs: throw "the entry cell must not fetch: ${builtins.concatStringsSep "." segs}";
    dep = segs: throw "the entry cell must not build: ${builtins.concatStringsSep "." segs}";
    wire = { deps, resolve }: import ../../lib deps;
  };

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
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);

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

  # ★★ THE READER IS BOUND, NOT ITS READING, AND THAT IS THE FIRST CONJUNCT OF THE ARMING RULE
  # RATHER THAN THE WHOLE OF IT. A bound READING (`shimFormals = builtins.attrNames
  # (builtins.functionArgs (import ../..))`) has no free parameter, so its control has nowhere else
  # to exercise it and can only re-assert the main arm's own value: MEASURED, that shape reads
  # `10/10 successful, exit 0` under the very tamper it exists to catch. Binding the READER is what
  # makes the control's DIFFERENT INPUT expressible at all.
  formalsOf = f: builtins.attrNames (builtins.functionArgs f);

  # ★ THE SECOND NEEDLE, bound once and read by both arms below for the same reason `needle` is.
  # `[[:space:]]*` spans the newline a formatter may put between `../..` and `{`. It does not match
  # `formalsOf (import ../..)` (a `)` follows, not a `{`) nor a path one segment longer (a `/`
  # follows), so the one thing it counts is an entry application to a literal.
  entryNeedle = ''\.\./\.\.[[:space:]]*\{'';
  countEntry =
    text: builtins.length (builtins.filter builtins.isList (builtins.split entryNeedle text));
in
{
  # ★ THE CELLS BELOW CANNOT SEE THIS CLASS, and the reason is the property that makes them
  # hermetic: they supply or close the dependency channel, so the shim's `fetch`-backed DEFAULT —
  # which is where the divergence lives — is never forced, and the FORCING cell stops at WHNF. This
  # cell reads the CONSTRUCTION instead of the outcome, which is strictly wider: a direct reach into
  # a dependency's own `lib/` that is lazy and never forced is a pure TEXT defect, and no forcing
  # cell can see one.
  #
  # ★★ COMMENTS ARE STRIPPED FIRST, AND THAT IS LOAD-BEARING RATHER THAN TIDY. `ci/tests/purity.nix`
  # states the same property for the same reason and over this same file: the house convention for a
  # FIXED member is a comment explaining why not `/lib`, and a raw scan reds on that comment while
  # the file is correct. The strip is PROPHYLACTIC — it stops the next correctly-written comment from
  # reddening a correct file.
  #
  # ★ `[[:space:]]*` spans the newline a formatter may put between `/lib"` and `{` — measured: a
  # line-anchored form misses exactly that.
  #
  # ★★ THE NEEDLE IS BOUND ONCE AND BOTH CELLS READ THAT BINDING. Two literals spelled the same are
  # TWO PREDICATES, and the control would then guard only its own copy.
  flake.tests.entry.test-no-dependency-is-built-past-its-own-entry =
    let
      parts = builtins.split needle (stripComments (builtins.readFile ../../default.nix));
    in
    {
      expr = {
        count = builtins.length (builtins.filter builtins.isList parts);
        reaches = map builtins.head (
          builtins.filter (m: m != null) (
            map (p: builtins.match ''.*"(gen-[a-z-]+)"[[:space:]]*]$'' p) (
              builtins.filter builtins.isString parts
            )
          )
        );
      };
      expected = {
        count = 0;
        reaches = [ ];
      };
    };

  # ★★ THE DETECTOR IS SHOWN ABLE TO FIRE, IN THE SAME RUN, ON THE SAME PREDICATE. Without it,
  # `count = 0` is equally consistent with a needle that cannot match.
  flake.tests.entry.test-control-the-entry-shape-check-discriminates = {
    expr = builtins.length (
      builtins.filter builtins.isList (
        builtins.split needle (stripComments ''
          {
            graph ? import "''${fetch "gen-graph"}/lib"
              { inherit prelude; },
          }: null
        '')
      )
    );
    expected = 1;
  };

  # ★★★ THE SHIM'S DECLARED FORMAL SET, AND IT IS THE ONE CELL IN THIS FILE OVER THE DECLARED SET
  # RATHER THAN THE WIRED ONE. Every cell built on `paths` reads the `deps` half of the record the
  # body hands `wire`, so a formal that is DECLARED and never threaded into `deps` is invisible to
  # all of them — it is in `functionArgs` and in no `paths` key. This is where it surfaces.
  #
  # ★★ THE OBLIGATION IS TOTAL — every formal the shim DECLARES. "Harmless" is not a property of a
  # formal but of its DEFAULT EXPRESSION, which changes without notice.
  #
  # ★ IT IS HERMETIC, MEASURED: `builtins.functionArgs` does not force defaults. Reading a signature
  # never reaches the network.
  #
  # ★ EQUALITY, NOT CONTAINMENT: a key the shim does not declare would be accepted, unread and
  # unreported under `...`, so containment would pass a stale key forever. Equality reds on it,
  # loudly, naming it.
  flake.tests.entry.test-the-entry-application-is-total = {
    expr = formalsOf (import ../..);
    expected = builtins.attrNames entryArgs;
  };

  # ★★★ AN ARMED PAIR IS A CONJUNCTION: the two arms SHARE the operand (`formalsOf`), AND the control
  # exercises that operand AT AN INPUT THE MAIN ARM DOES NOT USE. Either half alone detects nothing.
  #
  # ★ THE FIXTURE NAMES `a` AND `b`, which are the formals of a lambda THIS CELL WRITES and no shim
  # supplies. That is the different input, not an exception to "no formal OF THE SHIM is hardcoded":
  # a control written to avoid every literal name would have to reach for the shim's own formals,
  # which puts it at the main arm's input and makes it blind.
  flake.tests.entry.test-control-the-formals-reader-discriminates = {
    expr = formalsOf (
      {
        a,
        b ? null,
      }:
      null
    );
    expected = [
      "a"
      "b"
    ];
  };

  # ★★ THE STRUCTURAL CELL — the one the semantic instrument above cannot replace, because the edit
  # that reintroduces the defect is the same edit that removes the semantic instrument. It reads THIS
  # file's own text and refuses the bare application outright, so the property survives tomorrow's
  # edit instead of describing today's. It is also what makes `pathArgs` and `entryArgs` BINDINGS
  # rather than literals written at the application.
  #
  # ★★ COMMENTS ARE STRIPPED FIRST, AND ACROSS THIS DOMAIN THAT IS LIVE RATHER THAN PROPHYLACTIC.
  flake.tests.entry.test-the-entry-is-never-applied-to-a-literal = {
    expr = countEntry (stripComments (builtins.readFile ./entry.nix));
    expected = 0;
  };

  # ★★ THE FIXTURE IS ASSEMBLED, AND THAT IS THE MECHANISM RATHER THAN A FLOURISH. The cell above
  # reads THIS FILE, unlike `needle`'s cell which reads the shim — so a fixture written as a plain
  # literal would appear in the very text the main arm scans and red it.
  flake.tests.entry.test-control-the-literal-application-check-discriminates = {
    expr = countEntry ("  entry = import ../" + ".. { };");
    expected = 1;
  };

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
