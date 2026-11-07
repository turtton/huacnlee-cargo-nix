{
  runCommand,
  stdenv,
  rustc,
  git,
  jq,
  cargo-huacnlee,
}:
runCommand "cargo-huacnlee-smoke"
  {
    nativeBuildInputs = [
      cargo-huacnlee
      rustc
      stdenv.cc
      git
      jq
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export CARGO_HOME="$HOME/.cargo"
    export RUSTC="${rustc}/bin/rustc"
    export RUSTDOC="${rustc}/bin/rustdoc"
    export RUSTC_WRAPPER=""
    export RUSTC_WORKSPACE_WRAPPER=""
    mkdir -p "$HOME" project/src

    cargo --version | grep -F 'huacnlee/cargo ${cargo-huacnlee.version}'

    cat > project/Cargo.toml <<'EOF'
    [package]
    name = "cache-smoke"
    version = "0.1.0"
    edition = "2024"
    EOF
    cat > project/src/lib.rs <<'EOF'
    pub fn answer() -> u32 { 42 }

    #[test]
    fn answer_is_42() { assert_eq!(answer(), 42); }
    EOF
    cat > project/src/main.rs <<'EOF'
    fn main() { println!("{}", cache_smoke::answer()); }
    EOF
    printf '/target/\n' > project/.gitignore

    git -C project init --initial-branch=main
    git -C project config user.name 'Cargo smoke test'
    git -C project config user.email 'cargo-smoke@example.invalid'
    git -C project add .
    git -C project commit -m 'Create smoke project'

    (
      cd project
      cargo build --offline --message-format=json > "$TMPDIR/first-build.json"
      test "$(./target/debug/cache-smoke)" = 42
    )
    jq -e 'select(.reason == "compiler-artifact" and .target.kind == ["lib"]) | .fresh == false' \
      "$TMPDIR/first-build.json"

    git -C project worktree add --detach ../second HEAD
    (
      cd second
      cargo build --offline --message-format=json > "$TMPDIR/second-build.json"
      test "$(./target/debug/cache-smoke)" = 42
      cargo check --offline
      cargo test --offline
    )
    jq -e 'select(.reason == "compiler-artifact" and .target.kind == ["lib"]) | .fresh == true' \
      "$TMPDIR/second-build.json"
    test -d "$CARGO_HOME/targets"
    test ! -e "$CARGO_HOME/.fork-update"
    touch "$out"
  ''
