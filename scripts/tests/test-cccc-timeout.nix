# Build only an offline regression check, not cccc-cli or its Cargo downloads.
# just test-cccc-timeout
let
  flake = builtins.getFlake (toString ../..);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  package = pkgs.callPackage ../../packages/cccc-cli.nix { };
  staging = package.cargoDeps.vendorStaging;
  helper = builtins.head staging.nativeBuildInputs;
in
assert package.cargoHash == "sha256-4MkN5D+jP74hmL/S47TwGkpIXXjM6OD/1hQPy8KkRSY=";
assert builtins.elem "https_proxy" staging.impureEnvVars;
assert staging.outputHash == package.cargoHash;
pkgs.runCommand "test-cccc-cargo-fetch-timeouts"
  {
    nativeBuildInputs = staging.nativeBuildInputs ++ [ pkgs.python3 ];
  }
  ''
    original="$(command -v fetch-cargo-vendor-util)"
    test "$original" = "${helper}/bin/fetch-cargo-vendor-util"
    ${staging.preBuild or ""}
    patched="$(command -v fetch-cargo-vendor-util)"
    test "$patched" != "$original"
    test -x "$patched"
    python3 - "$original" "$patched" <<'PY'
    import ast
    from pathlib import Path
    import sys

    def assignments(path):
        tree = ast.parse(Path(path).read_text())
        return {
            target.id: node.value
            for node in tree.body if isinstance(node, ast.Assign)
            for target in node.targets if isinstance(target, ast.Name)
        }

    original, patched = map(assignments, sys.argv[1:])
    for name in ("CONNECT_TIMEOUT", "READ_TIMEOUT"):
        assert ast.literal_eval(patched[name]) == 30, name
    for name in ("MAX_WORKERS", "RETRY_COUNT", "BACKOFF_FACTOR", "TIMEOUT"):
        assert ast.dump(original[name]) == ast.dump(patched[name]), name
    assert ast.dump(patched["TIMEOUT"]) == ast.dump(
        ast.parse("(CONNECT_TIMEOUT, READ_TIMEOUT)", mode="eval").body
    )
    print("cccc-cli fetcher: connect/read=30s; retry, concurrency and timeout wiring preserved")
    PY
    touch "$out"
  ''
