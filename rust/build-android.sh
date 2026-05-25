#!/bin/bash

TARGET="$1"

if [ "$TARGET" = "" ]; then
    echo "missing argument TARGET"
    echo "Usage: $0 TARGET"
    exit 1
fi

NDK_TARGET=$TARGET

# rustup spells the armv7 Android target `armv7-linux-androideabi`, the NDK
# spells it `armv7a-linux-androideabi`. Map either rustup spelling to the NDK
# clang wrapper name.
case "$TARGET" in
    arm-linux-androideabi)    NDK_TARGET="armv7a-linux-androideabi" ;;
    armv7-linux-androideabi)  NDK_TARGET="armv7a-linux-androideabi" ;;
esac

API_VERSION="21"

# NDK location: prefer NDK > ANDROID_NDK_ROOT > ANDROID_HOME/ndk/<NDK_VERSION>.
# The nix devshell sets ANDROID_NDK_ROOT directly; CI sets NDK.
if [ -z "$NDK" ]; then
  if [ -n "$ANDROID_NDK_ROOT" ]; then
    NDK="$ANDROID_NDK_ROOT"
  else
    NDK_VERSION="${NDK_VERSION:-26.1.10909125}"
    NDK="$ANDROID_HOME/ndk/$NDK_VERSION"
  fi
fi

# Detect the NDK host triple. NDK r26+ ships Apple-Silicon-native binaries as
# `darwin-arm64`; older NDKs (and some r26 layouts) only ship `darwin-x86_64`,
# which still works on Apple Silicon via Rosetta. Fall back gracefully.
case "$(uname -s)" in
  Darwin)
    if [ -d "$NDK/toolchains/llvm/prebuilt/darwin-arm64" ] && [ "$(uname -m)" = "arm64" ]; then
      NDK_HOST="darwin-arm64"
    else
      NDK_HOST="darwin-x86_64"
    fi
    ;;
  Linux)
    NDK_HOST="linux-x86_64"
    ;;
  *)
    echo "unsupported host: $(uname -s)" >&2
    exit 1
    ;;
esac

TOOLS="$NDK/toolchains/llvm/prebuilt/$NDK_HOST"

if [ ! -x "$TOOLS/bin/llvm-ar" ]; then
    echo "ERROR: NDK toolchain not found at $TOOLS" >&2
    echo "       Set NDK or ANDROID_NDK_ROOT to a valid NDK install." >&2
    exit 1
fi

AR=$TOOLS/bin/llvm-ar \
CXX=$TOOLS/bin/${NDK_TARGET}${API_VERSION}-clang++ \
CC=$TOOLS/bin/${NDK_TARGET}${API_VERSION}-clang \
RANLIB=$TOOLS/bin/llvm-ranlib \
CXXFLAGS="--target=$NDK_TARGET" \
cargo build --target $TARGET --release $EXTRA_ARGS
