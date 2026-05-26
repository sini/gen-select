{ lib, selectLib, whereLib }:
let
  sel = selectLib;
  inherit (whereLib) compile;
  inherit (selectLib) matches;

  # Mock data: simple flat nodes
  nodeData = {
    web1 = { name = "web1"; type = "host"; env = "prod"; region = "us-east"; };
    web2 = { name = "web2"; type = "host"; env = "prod"; region = "eu-west"; };
    db1 = { name = "db1"; type = "database"; env = "staging"; region = "us-east"; };
    cache1 = { name = "cache1"; type = "cache"; env = "prod"; region = "us-east"; };
  };

  # Minimal context (no tree structure needed for SQL WHERE)
  ctx = {
    data = id: nodeData.${id};
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
  };
in
{
  where-match = {
    test-eq-match = {
      expr = matches (compile "env = 'prod'") "web1" ctx;
      expected = true;
    };

    test-eq-no-match = {
      expr = matches (compile "env = 'prod'") "db1" ctx;
      expected = false;
    };

    test-neq-match = {
      expr = matches (compile "env != 'prod'") "db1" ctx;
      expected = true;
    };

    test-neq-no-match = {
      expr = matches (compile "env != 'prod'") "web1" ctx;
      expected = false;
    };

    test-and-match = {
      expr = matches (compile "env = 'prod' AND region = 'us-east'") "web1" ctx;
      expected = true;
    };

    test-and-partial-no-match = {
      expr = matches (compile "env = 'prod' AND region = 'us-east'") "web2" ctx;
      expected = false;
    };

    test-or-match-first = {
      expr = matches (compile "type = 'host' OR type = 'cache'") "web1" ctx;
      expected = true;
    };

    test-or-match-second = {
      expr = matches (compile "type = 'host' OR type = 'cache'") "cache1" ctx;
      expected = true;
    };

    test-or-no-match = {
      expr = matches (compile "type = 'host' OR type = 'cache'") "db1" ctx;
      expected = false;
    };

    test-not-match = {
      expr = matches (compile "NOT type = 'database'") "web1" ctx;
      expected = true;
    };

    test-not-no-match = {
      expr = matches (compile "NOT type = 'database'") "db1" ctx;
      expected = false;
    };

    test-in-match = {
      expr = matches (compile "env IN ('prod', 'staging')") "web1" ctx;
      expected = true;
    };

    test-in-match-second = {
      expr = matches (compile "env IN ('prod', 'staging')") "db1" ctx;
      expected = true;
    };

    test-complex = {
      expr = matches (compile "env = 'prod' AND (type = 'host' OR type = 'cache')") "web1" ctx;
      expected = true;
    };

    test-complex-no-match = {
      expr = matches (compile "env = 'prod' AND (type = 'host' OR type = 'cache')") "db1" ctx;
      expected = false;
    };

    test-complex-cache = {
      expr = matches (compile "env = 'prod' AND (type = 'host' OR type = 'cache')") "cache1" ctx;
      expected = true;
    };
  };
}
