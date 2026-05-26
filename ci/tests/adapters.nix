{ lib, selectLib, ... }:
let
  sel = selectLib;

  nodeMap = {
    "env:prod" = {
      id = "env:prod";
      type = "env";
      parent = null;
      decls = { env = "prod"; };
    };
    "host:web" = {
      id = "host:web";
      type = "host";
      parent = "env:prod";
      decls = { role = "frontend"; };
    };
    "user:tux" = {
      id = "user:tux";
      type = "user";
      parent = "host:web";
      decls = { shell = "/bin/zsh"; };
    };
  };
  mockScopeResult = {
    node = id: nodeMap.${id};
    get =
      id: attrName:
      if attrName == "children" then
        {
          "env:prod" = {
            "host:web" = nodeMap."host:web";
          };
          "host:web" = {
            "user:tux" = nodeMap."user:tux";
          };
          "user:tux" = { };
        }
        .${id}
      else
        throw "unexpected attr ${attrName}";
  };

  ctx = sel.adapters.scope.mkContext mockScopeResult;
in
{
  adapters = {
    test-scope-data = {
      expr = (ctx.data "host:web").role;
      expected = "frontend";
    };
    test-scope-parent = {
      expr = ctx.parent "host:web";
      expected = "env:prod";
    };
    test-scope-parent-root = {
      expr = ctx.parent "env:prod";
      expected = null;
    };
    test-scope-children = {
      expr = ctx.children "env:prod";
      expected = [ "host:web" ];
    };
    test-scope-children-leaf = {
      expr = ctx.children "user:tux";
      expected = [ ];
    };
    test-scope-ancestors = {
      expr = ctx.ancestors "user:tux";
      expected = [
        "host:web"
        "env:prod"
      ];
    };
    test-scope-ancestors-root = {
      expr = ctx.ancestors "env:prod";
      expected = [ ];
    };
    test-scope-siblings = {
      expr = ctx.siblings "host:web";
      expected = [ ];
    };
    test-scope-e2e-match = {
      expr = sel.matches (sel.attrs { role = "frontend"; }) "host:web" ctx;
      expected = true;
    };
    test-scope-e2e-within = {
      expr = sel.matches (sel.within (sel.attrs { env = "prod"; })) "user:tux" ctx;
      expected = true;
    };
    test-graph-mkPredicate = {
      expr = sel.adapters.graph.mkPredicate (sel.attrs { role = "frontend"; }) ctx "host:web";
      expected = true;
    };
    test-graph-mkPredicate-false = {
      expr = sel.adapters.graph.mkPredicate (sel.attrs { role = "backend"; }) ctx "host:web";
      expected = false;
    };
    test-graph-mkSelectPredicate = {
      expr = sel.adapters.graph.mkSelectPredicate (sel.attrs { role = "frontend"; }) ctx { id = "host:web"; };
      expected = true;
    };
    test-graph-mkSelectPredicate-false = {
      expr = sel.adapters.graph.mkSelectPredicate (sel.attrs { role = "backend"; }) ctx { id = "host:web"; };
      expected = false;
    };
  };
}
