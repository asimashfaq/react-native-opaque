{
  description = "react-native-opaque build environment (pinned rust + Android NDK)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        rustToolchain = pkgs.rust-bin.stable."1.85.0".default.override {
          targets = [
            "aarch64-apple-ios"
            "aarch64-apple-ios-sim"
            "x86_64-apple-ios"
            "aarch64-linux-android"
            "armv7-linux-androideabi"
            "i686-linux-android"
            "x86_64-linux-android"
          ];
        };

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "34" ];
          ndkVersions = [ "26.1.10909125" ];
          includeNDK = true;
          includeEmulator = false;
          includeSystemImages = false;
        };

      in {
        # mkShellNoCC avoids importing the C/C++ stdenv. That stdenv would set
        # `SDKROOT` to a macOS SDK and `NIX_CFLAGS_COMPILE` with `-isystem`
        # entries, both of which leak into iOS cross-compile via `cc-rs` even
        # when CXX points to host /usr/bin/clang++. We don't need a nix C
        # compiler here: iOS uses host Xcode, Android uses the NDK clang we
        # pull in via `androidsdk`.
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            rustToolchain
            pkgs.cmake
            pkgs.gnumake
            androidComposition.androidsdk
          ];

          shellHook = ''
            export ANDROID_SDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk"
            export ANDROID_HOME="$ANDROID_SDK_ROOT"
            export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/26.1.10909125"
            export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
            export NDK="$ANDROID_NDK_ROOT"

            echo "rust:        $(rustc --version)"
            echo "NDK_ROOT:    $ANDROID_NDK_ROOT"
          '';
        };
      });
}
