{ lib, genSelect, ... }:
let
  sel = genSelect;

  nodeMap = {
    root = {
      type = "env";
      tier = "prod";
    };
    "host:a" = {
      type = "host";
      role = "web";
    };
    "host:b" = {
      type = "host";
      role = "db";
    };
    "host:c" = {
      type = "host";
      role = "web";
    };
  };

  nodes = builtins.attrNames nodeMap;
  data = id: nodeMap.${id} or { };
  parent = id: if lib.hasPrefix "host:" id then "root" else null;

  ctx = sel.adapters.registry.mkContext { inherit nodes data parent; };
in
{
  flake.tests.adapter-registry = {
    test-data-passthrough = {
      expr = ctx.data "host:a";
      expected = {
        type = "host";
        role = "web";
      };
    };
    test-parent-passthrough = {
      expr = ctx.parent "host:a";
      expected = "root";
    };
    test-parent-null = {
      expr = ctx.parent "root";
      expected = null;
    };
    test-children = {
      expr = builtins.sort builtins.lessThan (ctx.children "root");
      expected = [
        "host:a"
        "host:b"
        "host:c"
      ];
    };
    test-children-leaf = {
      expr = ctx.children "host:a";
      expected = [ ];
    };
    test-ancestors = {
      expr = ctx.ancestors "host:a";
      expected = [ "root" ];
    };
    test-ancestors-root = {
      expr = ctx.ancestors "root";
      expected = [ ];
    };
    test-siblings = {
      expr = builtins.sort builtins.lessThan (ctx.siblings "host:a");
      expected = [
        "host:b"
        "host:c"
      ];
    };
    test-siblings-root = {
      expr = ctx.siblings "root";
      expected = [ ];
    };
    test-matches-attrs = {
      expr = sel.matches (sel.attrs { type = "host"; }) "host:a" ctx;
      expected = true;
    };
    test-matches-within = {
      expr = sel.matches (sel.within (sel.attrs { type = "env"; })) "host:b" ctx;
      expected = true;
    };
    test-matches-has = {
      expr = sel.matches (sel.has (sel.attrs { role = "web"; })) "root" ctx;
      expected = true;
    };
  };
}
