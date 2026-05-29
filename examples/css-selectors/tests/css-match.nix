{
  lib,
  genSelect,
  cssLib,
}:
let
  sel = genSelect;
  inherit (cssLib) parse;
  inherit (genSelect) matches;

  # Mock graph context: a simple tree
  #   root
  #   +-- web   (class=service, env=prod)
  #   |   +-- api  (class=service, env=prod)
  #   +-- db    (class=database, env=staging)
  nodeData = {
    root = {
      name = "root";
      type = "cluster";
    };
    web = {
      name = "web";
      class = "service";
      env = "prod";
    };
    api = {
      name = "api";
      class = "service";
      env = "prod";
    };
    db = {
      name = "db";
      class = "database";
      env = "staging";
    };
  };

  parentMap = {
    root = null;
    web = "root";
    api = "web";
    db = "root";
  };

  childMap = {
    root = [
      "web"
      "db"
    ];
    web = [ "api" ];
    api = [ ];
    db = [ ];
  };

  ancestorsOf =
    id:
    let
      p = parentMap.${id};
    in
    if p == null then [ ] else [ p ] ++ ancestorsOf p;

  ctx = {
    data = id: nodeData.${id};
    parent = id: parentMap.${id};
    children = id: childMap.${id};
    ancestors = ancestorsOf;
  };
in
{
  css-match = {
    test-star-matches-all = {
      expr = matches (parse "*") "web" ctx;
      expected = true;
    };

    test-name-matches = {
      expr = matches (parse "web") "web" ctx;
      expected = true;
    };

    test-name-no-match = {
      expr = matches (parse "web") "db" ctx;
      expected = false;
    };

    test-class-matches = {
      expr = matches (parse ".service") "web" ctx;
      expected = true;
    };

    test-class-no-match = {
      expr = matches (parse ".service") "db" ctx;
      expected = false;
    };

    test-id-matches = {
      expr = matches (parse "#api") "api" ctx;
      expected = true;
    };

    test-attr-eq-matches = {
      expr = matches (parse "[env=prod]") "web" ctx;
      expected = true;
    };

    test-attr-eq-no-match = {
      expr = matches (parse "[env=prod]") "db" ctx;
      expected = false;
    };

    test-attr-exists-matches = {
      expr = matches (parse "[env]") "web" ctx;
      expected = true;
    };

    test-attr-exists-no-match = {
      expr = matches (parse "[env]") "root" ctx;
      expected = false;
    };

    test-not-matches = {
      expr = matches (parse ":not(.database)") "web" ctx;
      expected = true;
    };

    test-not-no-match = {
      expr = matches (parse ":not(.database)") "db" ctx;
      expected = false;
    };

    test-has-matches = {
      expr = matches (parse ":has(.service)") "root" ctx;
      expected = true;
    };

    test-has-no-match = {
      expr = matches (parse ":has(.service)") "db" ctx;
      expected = false;
    };

    test-within-matches = {
      expr = matches (parse ":within(root)") "api" ctx;
      expected = true;
    };

    test-within-no-match = {
      expr = matches (parse ":within(.service)") "root" ctx;
      expected = false;
    };

    test-child-combinator = {
      expr = matches (parse "root > .service") "web" ctx;
      expected = true;
    };

    test-child-combinator-not-grandchild = {
      expr = matches (parse "root > .service") "api" ctx;
      expected = false;
    };

    test-descendant-combinator = {
      expr = matches (parse "root .service") "api" ctx;
      expected = true;
    };

    test-or-matches-first = {
      expr = matches (parse ".service, .database") "web" ctx;
      expected = true;
    };

    test-or-matches-second = {
      expr = matches (parse ".service, .database") "db" ctx;
      expected = true;
    };

    test-or-no-match = {
      expr = matches (parse ".service, .database") "root" ctx;
      expected = false;
    };
  };
}
