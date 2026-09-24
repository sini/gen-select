{
  flake.testsError.evaluator-plant.test-nul-refused-reds-lix-only = {
    expr = builtins.fromJSON "\"\\u0000\"";
    expectedError.msg = "null bytes";
  };
}
