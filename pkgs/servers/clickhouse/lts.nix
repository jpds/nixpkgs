{ lib
, llvmPackages
, fetchFromGitHub
, fetchpatch
, cmake
, ninja
, python3
, perl
, nasm
, yasm
, nixosTests
, darwin
, findutils
, libiconv

, rustSupport ? true

, corrosion
, rustc
, cargo
, rustPlatform
}:

let
  inherit (llvmPackages) stdenv;
  mkDerivation = (
    if stdenv.isDarwin
    then darwin.apple_sdk_11_0.llvmPackages_16.stdenv
    else llvmPackages.stdenv).mkDerivation;
in mkDerivation rec {
  pname = "clickhouse";
  version = "24.8.4.13";

  src = fetchFromGitHub rec {
    owner = "ClickHouse";
    repo = "ClickHouse";
    rev = "v${version}-lts";
    fetchSubmodules = true;
    name = "clickhouse-${rev}.tar.gz";
    hash = "sha256-uU9gVdYuJs7I73Q+lSotPXQScJ9UHluLfaBtXTtCToU=";
    postFetch = ''
      # delete files that make the source too big
      rm -rf $out/contrib/llvm-project/llvm/test
      rm -rf $out/contrib/llvm-project/clang/test
      rm -rf $out/contrib/croaring/benchmarks

      # fix case insensitivity on macos https://github.com/NixOS/nixpkgs/issues/39308
      rm -rf $out/contrib/sysroot/linux-*
      rm -rf $out/contrib/liburing/man

      # compress to not exceed the 2GB output limit
      # try to make a deterministic tarball
      tar -I 'gzip -n' \
        --sort=name \
        --mtime=1970-01-01 \
        --owner=0 --group=0 \
        --numeric-owner --mode=go=rX,u+rw,a-s \
        --transform='s@^@source/@S' \
        -cf temp  -C "$out" .
      rm -r "$out"
      mv temp "$out"
    '';
   };

  cargoRoot = "rust/workspace";
  cargoDeps = if rustSupport then rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "tuikit-0.5.0" = "sha256-i5qEiQhN6FqC3teLr73ni2uu1ofZ5pMGz07VcEZPeO0=";
    };
  } else null;

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    ninja
    python3
    perl
    llvmPackages.lld
  ] ++ lib.optionals stdenv.isx86_64 [
    nasm
    yasm
  ] ++ lib.optionals stdenv.isDarwin [
    llvmPackages.bintools
    findutils
    darwin.bootstrap_cmds
  ] ++ lib.optionals rustSupport [
    rustc
    cargo
    rustPlatform.cargoSetupHook
  ];

  buildInputs = lib.optionals stdenv.isDarwin [ libiconv ];

  postPatch = ''
    patchShebangs src/ utils/

    substituteInPlace src/Storages/System/StorageSystemLicenses.sh \
      --replace 'git rev-parse --show-toplevel' '$src'
    substituteInPlace utils/check-style/check-duplicate-includes.sh \
      --replace 'git rev-parse --show-toplevel' '$src'
    substituteInPlace utils/check-style/check-ungrouped-includes.sh \
      --replace 'git rev-parse --show-toplevel' '$src'
    substituteInPlace utils/list-licenses/list-licenses.sh \
      --replace 'git rev-parse --show-toplevel' '$src'
    substituteInPlace utils/check-style/check-style \
      --replace 'git rev-parse --show-toplevel' '$src'
    substituteInPlace contrib/openssl-cmake/CMakeLists.txt \
      --replace '/usr/bin/env perl' '${perl}/bin/perl'
  '' + lib.optionalString stdenv.isDarwin ''
    sed -i 's|gfind|find|' cmake/tools.cmake
    sed -i 's|ggrep|grep|' cmake/tools.cmake
  '' + lib.optionalString rustSupport ''
    cargoSetupPostPatchHook() { true; }
  '' + lib.optionalString stdenv.isDarwin ''
    # Make sure Darwin invokes lld.ld64 not lld.
    substituteInPlace cmake/tools.cmake \
      --replace '--ld-path=''${LLD_PATH}' '-fuse-ld=lld'
  '';

  cmakeFlags = [
    "-DENABLE_TESTS=OFF"
    "-DCOMPILER_CACHE=disabled"
    "-DENABLE_EMBEDDED_COMPILER=ON"
  ];

  env = {
    NIX_CFLAGS_COMPILE =
      # undefined reference to '__sync_val_compare_and_swap_16'
      lib.optionalString stdenv.isx86_64 " -mcx16" +
      # Silence ``-Wimplicit-const-int-float-conversion` error in MemoryTracker.cpp and
      # ``-Wno-unneeded-internal-declaration` TreeOptimizer.cpp.
      lib.optionalString stdenv.isDarwin " -Wno-implicit-const-int-float-conversion -Wno-unneeded-internal-declaration";
  };

  # https://github.com/ClickHouse/ClickHouse/issues/49988
  hardeningDisable = [ "fortify" ];

  postInstall = ''
    rm -rf $out/share/clickhouse-test

    sed -i -e '\!<log>/var/log/clickhouse-server/clickhouse-server\.log</log>!d' \
      $out/etc/clickhouse-server/config.xml
    substituteInPlace $out/etc/clickhouse-server/config.xml \
      --replace "<errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>" "<console>1</console>"
    substituteInPlace $out/etc/clickhouse-server/config.xml \
      --replace "<level>trace</level>" "<level>warning</level>"
  '';

  # Builds in 7+h with 2 cores, and ~20m with a big-parallel builder.
  requiredSystemFeatures = [ "big-parallel" ];

  passthru.tests.clickhouse = nixosTests.clickhouse;

  meta = with lib; {
    homepage = "https://clickhouse.com";
    description = "Column-oriented database management system";
    license = licenses.asl20;
    maintainers = with maintainers; [ orivej mbalatsko ];

    # not supposed to work on 32-bit https://github.com/ClickHouse/ClickHouse/pull/23959#issuecomment-835343685
    platforms = lib.filter (x: (lib.systems.elaborate x).is64bit) (platforms.linux ++ platforms.darwin);
    broken = stdenv.buildPlatform != stdenv.hostPlatform;
  };
}
