# `adapters.program.bodies` (den-hoag-mr6xf): solving the emitted rules equals evaluating the
# selector. Two arms, and the second is the one that discriminates a Kleene-unsound compile:
#   · 2-valued — each leaf's truth read by `matches` at every context of a 7-bit family, asserted
#     to the program, and the head's flag compared with `matches` on the whole selector;
#   · 3-valued — a..d asserted true/false/undefined, the head's verdict compared with a Kleene
#     reference. Pruning `a ∧ ¬a` passes the first arm and fails this one.
#   · class sweep — the tag set `matches` dispatches on, read from `lib/match.nix`'s own source, is
#     every tag built here, so a connective added to `matches` cannot fall through `bodies`' leaf
#     arm unnoticed.
{
  genSelect,
  genProgram,
  genSchema,
  genMerge,
  ...
}:
let
  sel = genSelect;
  inherit (sel.adapters.program) bodies;

  a = sel.attrs { a = true; };
  b = sel.attrs { b = true; };
  c = sel.attrs { c = true; };
  d = sel.attrs { d = true; };
  hasE = sel.has (sel.attrs { e = true; });
  inF = sel.within (sel.attrs { f = true; });
  pG = sel.parentMatches (sel.attrs { g = true; });
  atomOf =
    s: if s.__sel == "attrs" then builtins.head (builtins.attrNames s.a) else builtins.toJSON s;
  leaves = [
    a
    b
    c
    d
    hasE
    inF
    pG
  ];

  # Leaves a..d only, so the 3-valued arm can assert every leaf.
  boolean = {
    leaf = a;
    notLeaf = sel.not a;
    star = sel.star;
    notStar = sel.not sel.star;
    andEmpty = sel.and [ ];
    anyEmpty = sel.anyOf [ ];
    notAnyEmpty = sel.not (sel.anyOf [ ]);
    conj = sel.and [
      a
      (sel.not b)
    ];
    disj = sel.anyOf [
      a
      b
    ];
    notAnd = sel.not (
      sel.and [
        a
        b
      ]
    );
    notAny = sel.not (
      sel.anyOf [
        a
        (sel.not b)
      ]
    );
    nestedDisj = sel.and [
      (sel.anyOf [
        a
        b
      ])
      (sel.anyOf [
        c
        (sel.not d)
      ])
    ];
    deep = sel.not (
      sel.anyOf [
        (sel.and [
          a
          (sel.not (
            sel.anyOf [
              b
              c
            ]
          ))
        ])
        (sel.not d)
      ]
    );
    contradiction = sel.and [
      a
      (sel.not a)
    ];
    excludedMiddle = sel.anyOf [
      a
      (sel.not a)
    ];
    doubleNeg = sel.not (
      sel.not (
        sel.and [
          a
          b
        ]
      )
    );
  };
  corpus = boolean // {
    structural = sel.anyOf [
      (sel.and [
        hasE
        (sel.not inF)
      ])
      (sel.not pG)
    ];
    sugar = sel.child {
      parent = sel.attrs { g = true; };
      child = sel.not a;
    };
    mixed = sel.and [
      (sel.not hasE)
      (sel.anyOf [
        c
        inF
      ])
      (sel.not (
        sel.and [
          d
          pG
        ]
      ))
    ];
  };

  head = "selected";
  solve =
    interpretation: s:
    genProgram.model {
      prior = null;
      program = genProgram.program [ ] (
        map (
          bd:
          bd
          // {
            inherit head;
            relata = [ ];
          }
        ) (bodies atomOf s)
      );
      inherit interpretation;
      complete = true;
    };

  # Node `n` under `p` under `r`, with child `k`: n carries a..d, k carries e, r f, p g.
  bits =
    n:
    if n == 0 then
      [ [ ] ]
    else
      builtins.concatMap (t: map (r: [ t ] ++ r) (bits (n - 1))) [
        true
        false
      ];
  ctxOf = v: {
    data =
      id:
      {
        n = {
          a = builtins.elemAt v 0;
          b = builtins.elemAt v 1;
          c = builtins.elemAt v 2;
          d = builtins.elemAt v 3;
        };
        k.e = builtins.elemAt v 4;
        r.f = builtins.elemAt v 5;
        p.g = builtins.elemAt v 6;
      }
      .${id};
    parent =
      id:
      {
        n = "p";
        p = "r";
        r = null;
        k = "n";
      }
      .${id};
    children =
      id:
      {
        n = [ "k" ];
        p = [ "n" ];
        r = [ "p" ];
        k = [ ];
      }
      .${id};
    ancestors =
      id:
      {
        n = [
          "p"
          "r"
        ];
        p = [ "r" ];
        r = [ ];
        k = [
          "n"
          "p"
          "r"
        ];
      }
      .${id};
    siblings = _: [ ];
  };
  twoValued = builtins.concatMap (
    s:
    map (
      v:
      let
        ctx = ctxOf v;
        r =
          (solve (map (l: {
            atom = atomOf l;
            verdict = if sel.matches l "n" ctx then "true" else "false";
          }) leaves) s).resolve
            head;
      in
      r.flag == "T" && r.included == sel.matches s "n" ctx
    ) (bits 7)
  ) (builtins.attrValues corpus);

  kNot =
    x:
    if x == "true" then
      "false"
    else if x == "false" then
      "true"
    else
      "undefined";
  kAll =
    xs:
    if builtins.elem "false" xs then
      "false"
    else if builtins.elem "undefined" xs then
      "undefined"
    else
      "true";
  kleene =
    val: s:
    if s.__sel == "star" then
      "true"
    else if s.__sel == "not" then
      kNot (kleene val s.selector)
    else if s.__sel == "and" then
      kAll (map (kleene val) s.selectors)
    else if s.__sel == "any" then
      kNot (kAll (map (x: kNot (kleene val x)) s.selectors))
    else
      val.${atomOf s};
  tri =
    n:
    if n == 0 then
      [ [ ] ]
    else
      builtins.concatMap (t: map (r: [ t ] ++ r) (tri (n - 1))) [
        "true"
        "false"
        "undefined"
      ];
  threeValued = builtins.concatMap (
    s:
    map (
      t:
      let
        val = {
          a = builtins.elemAt t 0;
          b = builtins.elemAt t 1;
          c = builtins.elemAt t 2;
          d = builtins.elemAt t 3;
        };
      in
      (solve (map (k: {
        atom = k;
        verdict = val.${k};
      }) (builtins.attrNames val)) s).verdict
        head == kleene val s
    ) (tri 4)
  ) (builtins.attrValues boolean);

  count = xs: builtins.length (builtins.filter (x: !x) xs);

  # Every dispatched tag, built by its own constructor (a real gen-schema kind for the identity
  # arms), plus the sugar that expands to them.
  K =
    (genSchema.evalSchema { } [
      { config.schema.user.options.uid = genMerge.mkOption { type = genMerge.types.int; }; }
    ]).user;
  entry = {
    id_hash = "h1";
    name = "e1";
  };
  built = {
    star = sel.star;
    attrs = sel.attrs { x = 1; };
    and = sel.and [ sel.star ];
    any = sel.anyOf [ sel.star ];
    not = sel.not sel.star;
    has = sel.has sel.star;
    within = sel.within sel.star;
    parentMatches = sel.parentMatches sel.star;
    entity = sel.entity K entry;
    kind = sel.kind K;
    subkind = sel.subkind K;
    coord = sel.adapters.product.coord "d" K entry;
    when = sel.when (_: _: true);
  };
  sugar = {
    child = sel.child {
      parent = sel.star;
      child = sel.attrs { y = 1; };
    };
    descendant = sel.descendant {
      ancestor = sel.star;
      descendant = sel.attrs { y = 1; };
    };
    inSlice = sel.adapters.product.inSlice {
      d = {
        kind = K;
        inherit entry;
      };
    };
  };
  tagsIn = text: builtins.filter builtins.isList (builtins.split "tag == \"([a-zA-Z]+)\"" text);
  dispatched = map builtins.head (tagsIn (builtins.readFile ../../lib/match.nix));
  compiles = s: (builtins.tryEval (builtins.deepSeq (bodies (s: s.__sel) s) true)).success;

  # The README's composition: each compound sub-selector compiled to a head the caller declares,
  # named as a leaf above it, against the direct compile, three-valued over a0..b2. Control in the
  # same run: the composition with one disjunct of x0 dropped.
  declsOf =
    h: s:
    map (
      bd:
      bd
      // {
        head = h;
        relata = [ ];
      }
    ) (bodies atomOf s);
  idx = [
    "0"
    "1"
    "2"
  ];
  pair =
    i:
    sel.anyOf [
      (sel.attrs { "a${i}" = true; })
      (sel.attrs { "b${i}" = true; })
    ];
  direct = declsOf head (sel.and (map pair idx));
  composed =
    builtins.concatMap (i: declsOf "x${i}" (pair i)) idx
    ++ declsOf head (sel.and (map (i: sel.attrs { "x${i}" = true; }) idx));
  broken = builtins.filter (bd: !(bd.head == "x0" && builtins.elem "b0" bd.pos)) composed;
  pairAtoms = builtins.concatMap (i: [
    "a${i}"
    "b${i}"
  ]) idx;
  verdictOf =
    decls: t:
    (genProgram.model {
      prior = null;
      program = genProgram.program [ ] decls;
      interpretation = builtins.genList (j: {
        atom = builtins.elemAt pairAtoms j;
        verdict = builtins.elemAt t j;
      }) 6;
      complete = true;
    }).verdict
      head;
  agree = decls: map (t: verdictOf direct t == verdictOf decls t) (tri 6);
in
{
  flake.tests.adapter-program = {
    # The regex's live control reads two arms off a planted string; a non-selector in the same run
    # does not compile.
    test-every-dispatched-tag-compiles = {
      expr = {
        control = builtins.length (tagsIn ''if tag == "p" then 1 else if tag == "q" then 2'');
        dispatched = builtins.length dispatched;
        uncovered = builtins.filter (t: !(built ? ${t}) || built.${t}.__sel != t) dispatched;
        failing = builtins.filter (n: !compiles (built // sugar).${n}) (
          builtins.attrNames (built // sugar)
        );
        negative = compiles { x = 1; };
      };
      expected = {
        control = 2;
        dispatched = 13;
        uncovered = [ ];
        failing = [ ];
        negative = false;
      };
    };
    # 19 selectors × 128 contexts.
    test-two-valued-equals-matches = {
      expr = {
        cells = builtins.length twoValued;
        failed = count twoValued;
      };
      expected = {
        cells = 2432;
        failed = 0;
      };
    };
    # 16 selectors × 81 assignments.
    test-three-valued-equals-kleene = {
      expr = {
        cells = builtins.length threeValued;
        failed = count threeValued;
      };
      expected = {
        cells = 1296;
        failed = 0;
      };
    };
    # No literal set is simplified: `a ∧ ¬a` keeps its body, so it is UNDEFINED at an undefined `a`.
    test-contradiction-keeps-its-body = {
      expr = bodies atomOf boolean.contradiction;
      expected = [
        {
          pos = [ "a" ];
          neg = [ "a" ];
        }
      ];
    };
    test-empty-disjunction-has-no-body = {
      expr = bodies atomOf (sel.anyOf [ ]);
      expected = [ ];
    };
    # (a1 ∨ b1) ∧ … ∧ (an ∨ bn): no DNF over these atoms is smaller than 2^n.
    test-size-is-the-dnf = {
      expr =
        map
          (
            n:
            builtins.length (
              bodies atomOf (
                sel.and (
                  builtins.genList (
                    i:
                    sel.anyOf [
                      (sel.attrs { "a${toString i}" = true; })
                      (sel.attrs { "b${toString i}" = true; })
                    ]
                  ) n
                )
              )
            )
          )
          [
            1
            2
            3
            4
            5
          ];
      expected = [
        2
        4
        8
        16
        32
      ];
    };
    test-composition-is-linear-and-equal = {
      expr = {
        direct = builtins.length direct;
        composed = builtins.length composed;
        cells = builtins.length (agree composed);
        failed = count (agree composed);
        controlFails = count (agree broken) > 0;
      };
      expected = {
        direct = 8;
        composed = 7;
        cells = 729;
        failed = 0;
        controlFails = true;
      };
    };
    # The compile refuses nothing for want of a stratification: `h :- not h` is solved, and the
    # stable-model oracle refuses the PROGRAM (ADR-0020).
    test-negative-self-loop-is-adjudicated = {
      expr =
        let
          m = solve [ ] (sel.not (sel.attrs { selected = true; }));
        in
        {
          flag = (m.resolve head).flag;
          inherit (m.adjudication) outcome;
        };
      expected = {
        flag = "U";
        outcome = "refused";
      };
    };
  };
}
