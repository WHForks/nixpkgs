{
  pkgs,
  newScope,
  darwin,
  llvmPackages_16,
  overrideCC,
  overrideLibcxx,
}:

let
  swiftLlvmPackages = llvmPackages_16;

  self = rec {
    callPackage = newScope self;

    # Current versions of Swift on Darwin require macOS SDK 10.15 at least.
    # The Swift compiler propagates the 13.3 SDK and a 10.15 deployment target.
    # Packages that need a newer version can add it to their build inputs
    # to use it (as normal).

    # This SDK is included for compatibility with existing packages.
    apple_sdk = pkgs.darwin.apple_sdk_11_0;

    # Swift builds its own Clang for internal use. We wrap that clang with a
    # cc-wrapper derived from the clang configured below. Because cc-wrapper
    # applies a specific resource-root, the two versions are best matched, or
    # we'll often run into compilation errors.
    #
    # The following selects the correct Clang version, matching the version
    # used in Swift.
    inherit (swiftLlvmPackages) clang;

    # Overrides that create a useful environment for swift packages, allowing
    # packaging with `swiftPackages.callPackage`.
    inherit (clang) bintools;
    stdenv =
      let
        stdenv' = overrideCC pkgs.stdenv clang;
      in
      # Ensure that Swift’s internal clang uses the same libc++ and libc++abi as the
      # default clang’s stdenv. Using the default libc++ avoids issues (such as crashes)
      # that can happen when a Swift application dynamically links different versions
      # of libc++ and libc++abi than libraries it links are using.
      if stdenv'.cc.libcxx != null then overrideLibcxx stdenv' else stdenv';

    swift-unwrapped = callPackage ./compiler {
      inherit (darwin) DarwinTools sigtool;
    };

    swift = callPackage ./wrapper {
      swift = swift-unwrapped;
    };
  };
in
self
