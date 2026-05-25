IOS_TARGETS := aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
ANDROID_TARGETS := aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android

# Use Xcode's clang for iOS cross-compile. The nix devshell injects
# `SDKROOT`, `NIX_CFLAGS_COMPILE` (with macOS libcxx includes),
# `MACOSX_DEPLOYMENT_TARGET=14.0`, and friends. Those collide with
# `--target=*-apple-ios` (clang refuses to mix `-miphoneos-version-min`
# with `-mmacos-version-min`, refuses the macOS sysroot for iOS, etc.).
#
# `env -u` strips every nix C/C++-toolchain breadcrumb before invoking cargo,
# and `cc-rs` then picks the host /usr/bin/clang via `CC_*` / `CXX_*`.
HOST_CXX := /usr/bin/clang++
HOST_CC  := /usr/bin/clang
IOS_ENV := env \
  -u SDKROOT \
  -u MACOSX_DEPLOYMENT_TARGET \
  -u NIX_CFLAGS_COMPILE \
  -u NIX_CFLAGS_COMPILE_FOR_BUILD \
  -u NIX_CFLAGS_LINK \
  -u NIX_LDFLAGS \
  -u NIX_LDFLAGS_FOR_BUILD \
  -u NIX_CC \
  -u NIX_CC_FOR_BUILD \
  -u NIX_BINTOOLS \
  -u NIX_BINTOOLS_FOR_BUILD \
  -u NIX_HARDENING_ENABLE \
  -u NIX_DONT_SET_RPATH \
  -u NIX_DONT_SET_RPATH_FOR_BUILD \
  -u NIX_NO_SELF_RPATH \
  -u NIX_IGNORE_LD_THROUGH_GCC \
  -u NIX_ENFORCE_NO_NATIVE \
  -u NIX_APPLE_SDK_VERSION \
  -u NIX_CC_WRAPPER_TARGET_BUILD_arm64_apple_darwin \
  -u NIX_CC_WRAPPER_TARGET_HOST_arm64_apple_darwin \
  -u NIX_BINTOOLS_WRAPPER_TARGET_BUILD_arm64_apple_darwin \
  -u NIX_BINTOOLS_WRAPPER_TARGET_HOST_arm64_apple_darwin \
  CC_aarch64_apple_ios=$(HOST_CC) \
  CXX_aarch64_apple_ios=$(HOST_CXX) \
  CC_aarch64_apple_ios_sim=$(HOST_CC) \
  CXX_aarch64_apple_ios_sim=$(HOST_CXX) \
  CC_x86_64_apple_ios=$(HOST_CC) \
  CXX_x86_64_apple_ios=$(HOST_CXX)

.PHONY: all ios android clean check

all: ios android

check:
	cd rust && cargo check --release

ios:
	@for t in $(IOS_TARGETS); do \
		echo "==> iOS target $$t"; \
		(cd rust && $(IOS_ENV) cargo build --target $$t --release) || exit 1; \
	done

android:
	@if [ -z "$$NDK" ] && [ -z "$$ANDROID_NDK_ROOT" ]; then \
		echo "ERROR: \$$NDK or \$$ANDROID_NDK_ROOT must be set (enter nix develop first)"; \
		exit 1; \
	fi
	@for t in $(ANDROID_TARGETS); do \
		echo "==> Android target $$t"; \
		(cd rust && ./build-android.sh $$t) || exit 1; \
	done

clean:
	cd rust && cargo clean
