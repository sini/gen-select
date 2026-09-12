{
  description = "gen-select: selector algebra for attributed graph positions";

  # ONE dependency: gen-algebra, for the identity-regime discipline `selectorEq` reads.
  # The zero-inputs claim this replaces was retired deliberately — see `lib/default.nix`
  # for why the vendored copy stopped being worth its price. gen-algebra declares no inputs
  # itself, so a consumer of gen-select gains a leaf and no transitive closure; no
  # nixpkgs.lib enters either way.
  inputs = {
    gen-algebra.url = "github:sini/gen-algebra";
  };

  outputs =
    { gen-algebra, ... }:
    {
      # `nix flake check` forces the WHNF of every top-level output and nothing deeper, so this root's
      # green quantified over the `lib` SPINE alone: a member of the published surface could throw and
      # the check still exited 0 (measured — den-hoag-z1ta6). Hanging the force on that spine is what
      # makes the green mean "the surface evaluates", and a library needs no new output name for it.
      # The depth is each member's WHNF and no deeper: a retirement tombstone is a published `throw`
      # by design (gen-scope's `buildNodes`), so a deep force is red on a healthy tree.
      lib =
        let
          surface = import ./lib { algebra = gen-algebra.lib; };
        in
        builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) surface) surface;
    };
}
