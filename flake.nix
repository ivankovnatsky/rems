{
  description = "rems - A command-line tool for interacting with macOS Reminders";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        generated = pkgs.swiftpm2nix.helpers ./nix/generated;

        remsPackage = pkgs.stdenv.mkDerivation {
          pname = "rems";
          version = "0-unstable";

          src = ./.;

          nativeBuildInputs = [
            pkgs.swift
            pkgs.swiftpm
          ];

          # Remove @retroactive annotations that require Swift 6.x
          postPatch = ''
            substituteInPlace Sources/RemsLibrary/EKReminder+Encodable.swift \
              --replace-fail '@retroactive Encodable' 'Encodable'
            substituteInPlace Sources/RemsLibrary/NaturalLanguage.swift \
              --replace-fail '@retroactive ExpressibleByArgument' 'ExpressibleByArgument'
          '';

          configurePhase = generated.configure;

          swiftpmFlags = [ "--product rems" ];

          installPhase = ''
            binPath="$(swiftpmBinPath)"
            mkdir -p $out/bin
            cp $binPath/rems $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "A command-line tool for interacting with macOS Reminders";
            homepage = "https://github.com/ivankovnatsky/rems";
            license = licenses.mit;
            platforms = platforms.darwin;
            mainProgram = "rems";
          };
        };
      in
      {
        packages = {
          rems = remsPackage;
          default = remsPackage;
        };
      }
    );
}
