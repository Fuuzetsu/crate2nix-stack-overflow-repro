{ system, vanillaPackages, rust-overlay, sourceInfo }:

let
  rustToolchain = pkgs:
    let
      rustChannel = (pkgs.rust-bin.fromRustupToolchainFile ../rust-toolchain).override {
        extensions = [
          "clippy"
          "rust-analysis"
          "rust-docs"
          "rust-src"
          "rustfmt"
        ];
      };
    in
    {
      rustc = rustChannel;
      cargo = rustChannel;
      rust-fmt = rustChannel;
      rust-std = rustChannel;
      clippy = rustChannel;
      rustPlatform = pkgs.makeRustPlatform {
        rustc = rustChannel;
        cargo = rustChannel;
      };
    };


  # Set of packages where all Rust tools come from the rustToolchain, determined
  # by the rust-toolchain file.
  rustToolchainPkgs = import (vanillaPackages.path) {
    inherit system;
    overlays = [
      (import rust-overlay)
      (self: _: rustToolchain self)
    ];
  };

  # We now import all our crate definitions, including our workspace crates.
  # Notice that we use the right set of packages (derived from rust-toolchain).
  cargoNix = import ./Cargo.nix {
    pkgs = rustToolchainPkgs;
  };

  # Build derivations for all our workspaces
  workspaceMembers = vanillaPackages.lib.mapAttrsToList
    (_: crate: crate.build)
    (cargoNix.workspaceMembers);

  # Given a single crate, create a wrapper with runtime dependencies if
  # necessary.
  workspaceCrates = builtins.listToAttrs
    (builtins.map
      (raw_crate:
        vanillaPackages.lib.nameValuePair raw_crate.crateName raw_crate
      )
      workspaceMembers);
in
{
  inherit rustToolchainPkgs workspaceCrates;

}
