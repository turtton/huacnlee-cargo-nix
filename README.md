# huacnlee-cargo-nix

Nix packages for [huacnlee/cargo](https://huacnlee.github.io/cargo/), a Cargo
fork that shares build artifacts across Git worktrees and projects and cleans
up old build artifacts automatically.

This flake repackages the upstream **prebuilt release binaries**; it does not
build Cargo from source. The initial version, `0.102.0-9`, uses the same pinned
release and packaging approach as the trial in
[turtton/evorch](https://github.com/turtton/evorch/commit/f54ed965).

## Use

```sh
nix run github:turtton/huacnlee-cargo-nix -- --version
nix shell github:turtton/huacnlee-cargo-nix
nix build github:turtton/huacnlee-cargo-nix
```

The executable is named `cargo`. Provide your own Rust toolchain, through
rustup, fenix, rust-overlay, or another package. The flake does not select or
replace `rustc`, rustfmt, Clippy, or rust-analyzer.

Add the input to your system flake:

```nix
inputs.cargo-huacnlee = {
  url = "github:turtton/huacnlee-cargo-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then add the package to a Home Manager configuration that receives `inputs`:

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.cargo-huacnlee.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

Alternatively, use the overlay:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.cargo-huacnlee.overlays.default ];
  environment.systemPackages = [ pkgs.cargo-huacnlee ];
}
```

The overlay adds `cargo-huacnlee`; it leaves `pkgs.cargo` and `rustPlatform`
unchanged. A project development shell that already provides another Cargo
can still take precedence. Check `command -v cargo` and `cargo --version` in
the shell where you intend to use it. A `~/.cargo/bin/cargo` earlier in `PATH`
also takes precedence. When combining packages that both provide `bin/cargo`,
resolve that collision explicitly, for example with `lib.hiPrio` on this
package in the profile.

## Behavior

- The wrapper sets `CARGO_FORK_AUTO_UPDATE=0`, even when the caller sets it to
  another value. Updates are controlled through Nix rather than Cargo's
  background updater. Installation does not modify `~/.cargo/bin`.
- Linux binaries have their ELF interpreter and library paths patched for
  NixOS. macOS binaries are packaged from the matching upstream archive.
- The fork fixes build intermediates under `~/.cargo/targets` and final
  outputs under `./target`. It ignores `CARGO_TARGET_DIR`, `--target-dir`, and
  the corresponding Cargo configuration settings. It also deletes old build
  artifacts according to its cache policy. See the [upstream
  README](https://github.com/huacnlee/cargo#what-changes) for details.
- An existing `RUSTC_WRAPPER` or `build.rustc-wrapper` configuration is kept.
  evorch's trial disables sccache in its fork development shell; this package
  leaves that choice to the consuming shell or configuration.

## Platforms and checks

Release assets are defined for `x86_64-linux`, `aarch64-linux`,
`x86_64-darwin`, and `aarch64-darwin`. Platform entries describe available
packages; they do not imply that every platform has been tested locally.
The `x86_64-linux` package and smoke check were tested locally. CI is configured
to run the same checks natively on all four platforms; consult the
[CI results](https://github.com/turtton/huacnlee-cargo-nix/actions) for their status.

```sh
nix flake check
nix build
nix fmt -- --check ./*.nix
```

The smoke check uses an isolated home and an explicit Nix Rust compiler. It
builds, checks, and tests a crate without network dependencies, then verifies
that a second Git worktree reuses the library artifact from the first one.

## Update the release

1. Review the upstream release and its changes.
2. Update `version`, target triples, and the archive hashes together in
   `hashes.json`. Get the hashes from the release's `SHA256SUMS` and confirm
   them against the downloaded archives. Convert a hex digest to SRI with
   `nix hash convert --hash-algo sha256 --to sri HEX_DIGEST`.
3. Run `nix flake check` and `nix build` on the platforms you can execute.
4. Commit the change. Consumers update their flake lock to use the new
   revision.

`flake.lock` pins nixpkgs; `hashes.json` independently pins the Cargo release
archives. A hash from the same upstream release checks archive integrity but
does not independently authenticate the release or prove it matches the
published source.

## License

The Nix packaging and documentation are [MIT licensed](LICENSE). Cargo and
the upstream fork retain their upstream licenses, primarily MIT OR
Apache-2.0, and the licenses of their bundled dependencies.
