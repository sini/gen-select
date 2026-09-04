# Purity invariant (gen-prelude design §5). gen-select is nixpkgs-free — no nixpkgs.lib and
# no module-system tier — and its library dependency budget is EXACTLY ONE: gen-algebra.
#
# ★ THE INVARIANT NARROWED KNOWINGLY, AND THE TEST NARROWED WITH IT. This suite used to
# forbid `gen-algebra` outright, because gen-select vendored the identity-regime discipline
# rather than importing it. That copy was priced as one trivial line when the relation WAS
# one line; it became a ~40-line dispatch over a tagged sum, and four libraries holding four
# copies of one sum is how the four stop agreeing. The edge is now taken deliberately.
#
# ★ A BAN THAT JUST LOSES A TOKEN IS WEAKER THAN WHAT IT REPLACED, so the token ban is
# paired with a POSITIVE arm: the root flake's declared inputs must be EXACTLY
# [ "gen-algebra" ]. Dropping the token alone would let a SECOND library dependency in
# unnoticed, which is the thing the original invariant actually protected.
#
# Scope: lib/**.nix + the root flake.nix + default.nix (the library + its entries).
# NOT ci/ — the test harness legitimately uses nixpkgs.lib (including, here, to scan).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here
  # because `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # ★ THE STRIP'S PREMISE, asserted rather than assumed. `stripComments` cuts each line at a comment
  # marker, and that cut is sound only while the `#` it cuts at stands OUTSIDE a string literal.
  # Where it does not, live code is truncated to the end of that line and every cell below goes
  # blind on what was removed, with no signal at all — a green suite over source nothing scanned.
  #
  # The predicate asks the strip ITSELF where it cut: `stripComments` of a single line is exactly
  # the text before that line's cut. It then asks whether that text closed every double quote it
  # opened, an odd count meaning the cut stands inside a string. Deriving it from `stripComments`
  # rather than restating the cut rule is what keeps premise and strip from drifting apart when one
  # of them is edited, and it is why one block serves both strip families in this ecosystem.
  #
  # It is LINE-LOCAL and so cannot conclude about string content that spans lines — an indented
  # multi-line string block. Those files are declared as a list of their own by
  # `test-strip-premise-multiline-strings` rather than trusted in silence.
  countQuotes = s: (lib.length (lib.splitString "\"" s)) - 1;
  cutIsInString =
    line:
    let
      kept = stripComments line;
    in
    kept != line && lib.mod (countQuotes kept) 2 == 1;

  # premiseBreaches : [ { name; text; } ] -> [ "file:line" ]. A breach is reported at its line as
  # well as its file, because what it says is that one particular line's code was truncated.
  premiseBreaches =
    srcs:
    lib.concatMap (
      src:
      lib.concatLists (
        lib.imap1 (i: line: lib.optional (cutIsInString line) "${src.name}:${toString i}") (
          lib.splitString "\n" src.text
        )
      )
    ) srcs;

  # Recursively collect every .nix under a directory (covers lib/adapters/ too).
  # walk : string -> path -> [ { name; path; } ], `name` being `prefix` extended by the entry's
  # position in the tree. The label a red CI prints is the whole product of a failing cell, and a
  # `toString` of the path value renders the store copy the flake is evaluated from
  # (`/nix/store/<hash>-source/lib/default.nix`) — a file no reader can open in their own checkout,
  # whose hash moves on any unrelated edit. Same shape as gen-link's and gen-graph's, deliberately.
  walk =
    prefix: dir:
    lib.concatLists (
      lib.mapAttrsToList (
        entry: type:
        if type == "directory" then
          walk "${prefix}${entry}/" (dir + "/${entry}")
        else if lib.hasSuffix ".nix" entry then
          [
            {
              name = "${prefix}${entry}";
              path = dir + "/${entry}";
            }
          ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  # ★ THE READ AND THE STRIP ARE SEPARATE STAGES, one `readFile` per file feeding both. The premise
  # cell has to speak about the RAW text, which is only a value once the strip stops happening inside
  # the read; and `sources` is then a total per-element function of `rawSources` — the name passes
  # through, the code is the strip of the text — so pinning either one pins the other, and the cells
  # over each COMPOSE instead of hoping two independent reads of the same tree agree.
  raw =
    entries:
    map (e: {
      inherit (e) name;
      text = builtins.readFile e.path;
    }) entries;

  strip =
    entries:
    map (e: {
      inherit (e) name;
      code = stripComments e.text;
    }) entries;

  rawSources = raw (walk "lib/" libDir) ++ [
    {
      name = "flake.nix";
      text = builtins.readFile ../../flake.nix;
    }
    {
      name = "default.nix";
      text = builtins.readFile ../../default.nix;
    }
  ];

  sources = strip rawSources;

  # Tokens signalling a nixpkgs-lib tether or the module-system tier. `gen-algebra` is no
  # longer among them — it is the one declared dependency, and the arm below is what keeps
  # that a budget of ONE rather than an open door.
  forbidden = [
    "nixpkgs" # a nixpkgs flake input / reference
    "lib." # any nixpkgs lib call (lib.types, lib.genAttrs, …)
    "{ lib }" # the old `{ lib }` parameter signature
    "{ lib," # `{ lib, … }` parameter signature
    "evalModules" # module-system tier
    "mkOption" # module-system tier
  ];

  # The root flake's OWN declared inputs, read from the lock rather than from the flake
  # expression: the lock is what a consumer actually resolves, so a dependency that reached
  # a consumer could not hide from this arm.
  declaredInputs = builtins.attrNames (builtins.fromJSON (builtins.readFile ../../flake.lock))
    .nodes.root.inputs;

  # scan : [ { name; code; } ] -> [ "file: 'tok'" ]. Factored out of `violations` so the detector
  # cell below runs THE SAME call over the same source list with one entry appended, rather than a
  # second copy of the predicate that could drift from this one.
  scan =
    srcs:
    lib.concatMap (
      src:
      map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
    ) srcs;

  violations = scan sources;
in
{
  flake.tests.purity.test-library-source-is-nixpkgs-free = {
    expr = violations;
    expected = [ ];
  };

  # What the cell above is a statement ABOUT. Its `[ ]` is produced just as readily by a scan that
  # reads the wrong tree, or no tree, as by a library that is clean, and neither the detector cell
  # below nor a guard on the source list's SIZE can tell those apart — the first never touches
  # `sources`, and the second answers a question about how many rather than which. The library tree
  # is small and its membership is a deliberate surface, so it is written down. A new library file
  # then arrives as a RED that has to be read, rather than being absorbed silently.
  #
  # WHAT IT IS SILENT ON: content. A read handing every entry one fixed string satisfies this cell
  # exactly, and no cell here sees that; the membership half is what this one carries.
  flake.tests.purity.test-scan-subject-is-the-library-tree = {
    expr = map (s: s.name) sources;
    expected = [
      "lib/adapters/graph.nix"
      "lib/adapters/product.nix"
      "lib/adapters/registry.nix"
      "lib/adapters/scope.nix"
      "lib/constructors.nix"
      "lib/default.nix"
      "lib/match.nix"
      "flake.nix"
      "default.nix"
    ];
  };

  # The detector has teeth, and it grows them on the real subject: the scan runs over exactly the
  # source list the cell above asserts, with one synthetic entry appended. So the firing is proven by
  # the same call that reports the tree clean, and the expectation states both halves at once — the
  # library contributes nothing and the planted tether contributes precisely this.
  #
  # The expectation is the violation LIST, not merely that one was produced: a detector that fires on
  # the wrong token, or whose `file: 'tok'` message has decayed into something a reader cannot act on
  # off a red CI, is broken in the way that matters and a bare non-emptiness check would pass it. The
  # synthetic entry is never written to disk, and its label is bracketed so it cannot be read as one
  # of the repo-root-relative paths it now sits beside. Its trailing comment names `nixpkgs`, which
  # the strip removes — so this cell also fails if the strip stops running.
  flake.tests.purity.test-detector-catches-injected-violation = {
    expr = scan (
      sources
      ++ [
        {
          name = "<injected>";
          code = stripComments "  foo = lib.types.str; # comment mentioning nixpkgs is stripped";
        }
      ]
    );
    expected = [
      "<injected>: 'lib.'"
    ];
  };

  # THE DEPENDENCY BUDGET, pinned by contents rather than by count — a count is satisfied by
  # swapping one dependency for another, which is not the property.
  flake.tests.purity.test-library-declares-exactly-one-dependency = {
    expr = declaredInputs;
    expected = [ "gen-algebra" ];
  };

  # ★ THE PREMISE HOLDS OF THE TEXT THAT WAS ACTUALLY SCANNED. This is an absence claim over text
  # read from disk and it is NOT non-vacuous on its own: its expectation is `[ ]`, which an emptied
  # or constant subject satisfies exactly as a sound corpus does — a scan of nothing breaches no
  # premise. What arms it is the subject-pinning asserted over this same `rawSources` read, together
  # with the live control below for the predicate itself; green here means the premise holds of the
  # text those cells pin, and nothing more.
  flake.tests.purity.test-strip-premise-holds = {
    expr = premiseBreaches rawSources;
    expected = [ ];
  };

  # And the predicate is capable of saying no. Its subject is a literal written inside this cell
  # rather than anything on disk, so it is UNSEVERABLE from the tree and establishes exactly that the
  # test discriminates an in-string `#` from an ordinary trailing comment — it says nothing whatever
  # about what the cell above was pointed at, and it is NOT that cell's arming. Both directions ride
  # in one expectation: line 1 must be caught and line 2 must not, so a predicate stuck at either
  # constant reds here. The literal cuts under BOTH strip families in this ecosystem — its `#` is
  # whitespace-preceded, so a comment-start strip cuts there too and the control cannot go dead by
  # being pasted into a repository whose strip is the other one.
  flake.tests.purity.test-strip-premise-scan-is-live = {
    expr = premiseBreaches [
      {
        name = "<in-string-hash>";
        text = ''
          url = "a b # c";
          x = 1; # an ordinary trailing comment
        '';
      }
    ];
    expected = [ "<in-string-hash>:1" ];
  };

  # The declared surface: the files the line-local predicate cannot conclude about. An indented
  # multi-line string block carries string content across line boundaries, where a per-line quote
  # count cannot follow it, so those files are written down rather than trusted in silence. The first
  # file to grow one arrives as a red that has to be READ, exactly as a new library file arrives as a
  # red on a membership manifest.
  flake.tests.purity.test-strip-premise-multiline-strings = {
    expr = map (s: s.name) (lib.filter (s: genPrelude.hasInfix "''" s.text) rawSources);
    expected = [ ];
  };
}
