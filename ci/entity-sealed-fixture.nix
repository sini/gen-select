# den-hoag-l0y (β): the sealed-collision fixture both test planes read (./tests/entity-sealed.nix
# for the decided arms, ./tests-error.nix `entity-sealed` for the refusals by message). It lives
# outside ./tests because every file there is a test module.
#
# Two `host` kinds differ only at `note`, typed by nixpkgs `lib.types` (unmigrated, so the component
# is SEALED): they mint one mark, gen-schema's `kindEq` refuses the pair by name, and their instances
# at equal keys share one stamp. `kS1t` is a separately evaluated twin of `kS1`; `kA` is migrated
# (no sealed components).
{
  lib,
  genSelect,
  genSchema,
  genMerge,
}:
let
  sel = genSelect;
  M = genMerge;
  mkKind =
    decl: (genSchema.evalSchema { modules = [ { config.schema.host.options = decl; } ]; }).host;
  declA = {
    addr = M.mkOption { type = M.types.str; };
  };
  declS1 = declA // {
    note = M.mkOption {
      type = lib.types.lines;
      default = "";
    };
  };
  declS2 = declA // {
    note = M.mkOption {
      type = lib.types.commas;
      default = "";
    };
  };
  kA = mkKind declA;
  kS1 = mkKind declS1;
  kS2 = mkKind declS2;
  kS1t = mkKind declS1;
  c =
    (M.evalModuleTree {
      modules = [
        {
          options.hA = genSchema.mkInstanceRegistry kA { };
          options.hS1 = genSchema.mkInstanceRegistry kS1 { };
          options.hS1t = genSchema.mkInstanceRegistry kS1t { };
          options.hS2 = genSchema.mkInstanceRegistry kS2 { };
          config.hA.p.addr = "10.0.0.1";
          config.hS1.p.addr = "10.0.0.1";
          config.hS1.q.addr = "10.0.0.2";
          config.hS1t.p.addr = "10.0.0.1";
          config.hS2.p.addr = "10.0.0.1";
        }
      ];
    }).config;
  s1 = c.hS1.p;
  s1q = c.hS1.q;
  s1t = c.hS1t.p;
  s2 = c.hS2.p;
  a = c.hA.p;
  nodes = {
    inherit
      s1
      s1q
      s1t
      s2
      a
      ;
  };
  kinds = {
    s1 = kS1;
    s1q = kS1;
    s1t = kS1t;
    s2 = kS2;
    a = kA;
  };
  mkReg =
    extra:
    sel.adapters.registry.mkContext (
      {
        nodes = builtins.attrNames nodes;
        data = id: nodes.${id};
        parent = _: null;
      }
      // extra
    );
in
{
  inherit
    kA
    kS1
    kS2
    kS1t
    s1
    s1q
    s1t
    s2
    a
    nodes
    ;
  # kind-bearing registry context
  reg = mkReg { kindFor = id: kinds.${id}; };
  # kind-blind: the registry adapter given no kind
  blind = mkReg { };
  # the scope adapter, whose projected kind is a lazy refusal
  scope = sel.adapters.scope.mkContext {
    node = id: {
      inherit id;
      type = "host";
      parent = null;
      decls = { };
    };
    get = _: _: { };
    entryFor = id: nodes.${id};
  };
  # C-2: a hand-built context whose `__identity` record omits `kind` altogether
  noKindField = {
    data = id: {
      __identity = {
        inherit (nodes.${id}) id_hash;
        entry = nodes.${id};
      };
    };
    parent = _: null;
  };
  # E6: version skew stood in by hand. A node whose stamp equals `s1`'s but whose projected kind is
  # the migrated `kA` is what a gen-schema that omits the mark from the stamp produces.
  skew = sel.adapters.registry.mkContext {
    nodes = [ "skew" ];
    data = _: {
      inherit (s1) id_hash;
      name = "p";
    };
    parent = _: null;
    kind = kA;
  };
  # `true`/`false`/a value, or "REFUSED" when forcing it throws catchably
  tr =
    e:
    let
      r = builtins.tryEval (builtins.deepSeq e e);
    in
    if r.success then r.value else "REFUSED";
}
