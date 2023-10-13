{
  description = "crate2nix-stack-overflow-repro";
  nixConfig.bash-prompt = "[nix-develop]$ ";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
    # Need recent rust-overlay for recent nixpkgs:
    # https://github.com/oxalica/rust-overlay/issues/121
    rust-overlay = {
      url = "github:oxalica/rust-overlay/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    crate2nix = {
      url = "github:kolloch/crate2nix";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , rust-overlay
    , flake-utils
    , flake-compat
    , crate2nix
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };

      rust = import ./nix/rust.nix {
        inherit system rust-overlay;
        inherit (inputs.self) sourceInfo;
        vanillaPackages = pkgs;
      };

      crate2nix = rust.rustToolchainPkgs.rustPlatform.buildRustPackage
        {
          pname = (pkgs.lib.importTOML "${inputs.crate2nix}/crate2nix/Cargo.toml").package.name;
          version = (pkgs.lib.importTOML "${inputs.crate2nix}/crate2nix/Cargo.toml").package.version;
          src = "${inputs.crate2nix}/crate2nix";
          doCheck = false;
          cargoLock = {
            lockFile = "${inputs.crate2nix}/crate2nix/Cargo.lock";
          };
          nativeBuildInputs = [ pkgs.makeWrapper ];
          patches = [ ./nix/crate2nix-sort-dependencies.patch ];
          postFixup = ''
            wrapProgram $out/bin/crate2nix \
                --prefix PATH : ${pkgs.lib.makeBinPath [ rust.rustToolchainPkgs.cargo pkgs.nix pkgs.nix-prefetch-git ]}
          '';
        };
      minNixVersion = "2.5";
    in
    assert pkgs.lib.asserts.assertMsg (! pkgs.lib.versionOlder builtins.nixVersion minNixVersion)
      "Minimum supported nix version for engine is ${minNixVersion} but trying to run with ${builtins.nixVersion}. Ask in #nix Slack channel if you need help upgrading.";
    {
      legacyPackages = pkgs;
      packages = flake-utils.lib.flattenTree
        (rust.workspaceCrates
          // {
          inherit crate2nix;
          # A whole set of crates, useful for building every crate in workspace in
          # CI and such.
          workspace-crates = pkgs.linkFarm "workspace-crates"
            (pkgs.lib.attrValues
              (pkgs.lib.mapAttrs
                (name: path: { inherit name path; })
                rust.workspaceCrates));
        }
        );

      apps = { };

      devShell = pkgs.mkShell {
        buildInputs = [
          # cargo, rustc
          rust.rustToolchainPkgs.rustc
        ];
        # Required by test-suite and in general let's set a uniform one.
        LANG = "C.UTF-8";
      };
    });
}
