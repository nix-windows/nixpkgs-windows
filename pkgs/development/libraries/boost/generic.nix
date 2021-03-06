{ stdenv, lib, fetchurl, icu, expat, zlib, bzip2, python, fixDarwinDylibNames, libiconv
, which
, buildPackages
, toolset ? /**/ if stdenv.cc.isClang  then "clang"
            else null
, staticRuntime ? false # false for /MD, true for /MT
, static ? false
, enableRelease ? true
, enableDebug ? false
, enableSingleThreaded ? false
, enableMultiThreaded ? true
#, enableShared ? !(stdenv.hostPlatform.libc == "msvcrt") # problems for now
#, enableStatic ? !enableShared
, enablePython ? false
, enableNumpy ? false
#, taggedLayout ? ((enableRelease && enableDebug) || (enableSingleThreaded && enableMultiThreaded) || (enableShared && enableStatic))
, patches ? []
, mpi ? null

, winver ? if stdenv.is64bit then "0x0502" else "0x0501"

# Attributes inherit from specific versions
, version, src
, ...
}:


if stdenv.hostPlatform.isWindows then

# or it will silently produce empty result
assert staticRuntime -> static;

assert stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.20" && lib.versionOlder stdenv.cc.msvc.version "15" ->
  lib.versionAtLeast version "1.71";   # "v142" is supported since boost-1.71 ; might older version be compiled by VS2019 using "v141"?


let
  b2Args = lib.concatStringsSep " " [
              "--prefix=$ENV{out}"
              "-j$ENV{NIX_BUILD_CORES}"
              "address-model=${if stdenv.is64bit then "64" else "32"}"
              "variant=release"
              "threading=multi"
              "link=${if static then "static" else "shared"}"
              "runtime-link=${if staticRuntime then "static" else "shared"}"
              "toolset=${if stdenv.cc.isMSVC then "msvc" else if stdenv.cc.isMSVC then "gcc" else throw "???"}"
              "define=_WIN32_WINNT=${winver}"
           ];
in stdenv.mkDerivation {
  name = "boost-${if static then "lib" else "dll"}-${if staticRuntime then "mt" else "md"}-${version}";

  inherit src;
# src = ./boost_1_67_0;

  enableParallelBuilding = true;

# buildInputs = [ /*expat zlib bzip2 libiconv*/ ]
#   ++ optional (stdenv.hostPlatform == stdenv.buildPlatform) icu
#   ++ optional enablePython python
#   ++ optional enableNumpy python.pkgs.numpy
#   ;


  configurePhase = stdenv.lib.optionalString (stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.10" && lib.versionOlder stdenv.cc.msvc.version "14.20") ''
    $ENV{PATH} = "$ENV{PATH};${stdenv.cc.redist}/${if stdenv.is64bit then "x64" else "x86"}/Microsoft.VC141.DebugCRT";     # vcruntime140d.dll and msvcp140d.dll for /MDd builds to work
    $ENV{PATH} = "$ENV{PATH};${stdenv.cc.redist}/${if stdenv.is64bit then "x64" else "x86"}/Microsoft.UniversalCRT.Debug"; # ucrtbased.dll                       for /MDd builds to work
  '' + stdenv.lib.optionalString (stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.20" && lib.versionOlder stdenv.cc.msvc.version "14.30") ''
    $ENV{PATH} = "$ENV{PATH};${stdenv.cc.redist}/${if stdenv.is64bit then "x64" else "x86"}/Microsoft.VC142.DebugCRT";     # vcruntime140d.dll and msvcp140d.dll for /MDd builds to work
    $ENV{PATH} = "$ENV{PATH};${stdenv.cc.redist}/${if stdenv.is64bit then "x64" else "x86"}/Microsoft.UniversalCRT.Debug"; # ucrtbased.dll                       for /MDd builds to work
  '' + ''
    system("bootstrap.bat ${if stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "8" && lib.versionOlder stdenv.cc.msvc.version "9" then
                              "vc8"
                            else if stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.10" && lib.versionOlder stdenv.cc.msvc.version "14.20" then
                              "vc141"
                            else if stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.20" && lib.versionOlder stdenv.cc.msvc.version "15" then
                              "vc142"
                            else
                              throw "???"}");
    writeFile("project-config.jam", qq[
    import option ;
    using msvc : ${if stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "8" && lib.versionOlder stdenv.cc.msvc.version "9" then
                     "8.0"
                   else if stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.10" && lib.versionOlder stdenv.cc.msvc.version "14.20" then
                     "14.1"
                   else if stdenv.cc.isMSVC && lib.versionAtLeast stdenv.cc.msvc.version "14.20" && lib.versionOlder stdenv.cc.msvc.version "15" then
                     "14.2"
                   else
                     throw "???"} : : <setup>${stdenv.cc}/VC/vcvarsall.bat ;
    option.set keep-going : false ;
    ]);
  '';

  buildPhase = ''
    $ENV{ProgramFiles} = $ENV{TEMP};                        # let jam not crash
    print("EXEC: b2 ${b2Args}\n");
    die "b2: $!" if system("b2 ${b2Args}");
  '';

  installPhase = ''
    print("EXEC: b2 ${b2Args} install\n");
    die $! if system("b2 ${b2Args} install");
    renameL("$ENV{out}/include/boost-".('${version}' =~ s/^(\d+)\.(\d+).*/$1_$2/r)."/boost", "$ENV{out}/include/boost") or die $!;
    rmdirL("$ENV{out}/include/boost-".('${version}' =~ s/^(\d+)\.(\d+).*/$1_$2/r))                                      or die $!;
  '' + stdenv.lib.optionalString (!static) ''
    mkdirL("$ENV{out}/bin") or die $!;
    for my $dll (glob("$ENV{out}/lib/*.dll")) {
      renameL($dll, "$ENV{out}/bin/".basename($dll)) or die $!;
    }
  '';

  passthru.static        = static;
  passthru.staticRuntime = staticRuntime;
}

else
  throw "xxx"
/*
# We must build at least one type of libraries
assert enableShared || enableStatic;

# Python isn't supported when cross-compiling
assert enablePython -> stdenv.hostPlatform == stdenv.buildPlatform;
assert enableNumpy -> enablePython;

with stdenv.lib;
let

  variant = concatStringsSep ","
    (optional enableRelease "release" ++
     optional enableDebug "debug");

  threading = concatStringsSep ","
    (optional enableSingleThreaded "single" ++
     optional enableMultiThreaded "multi");

  link = concatStringsSep ","
    (optional enableShared "shared" ++
     optional enableStatic "static");

  runtime-link = if enableShared then "shared" else "static";

  # To avoid library name collisions
  layout = if taggedLayout then "tagged" else "system";

  # Versions of b2 before 1.65 have job limits; specifically:
  #   - Versions before 1.58 support up to 64 jobs[0]
  #   - Versions before 1.65 support up to 256 jobs[1]
  #
  # [0]: https://github.com/boostorg/build/commit/0ef40cb86728f1cd804830fef89a6d39153ff632
  # [1]: https://github.com/boostorg/build/commit/316e26ca718afc65d6170029284521392524e4f8
  jobs =
    if versionOlder version "1.58" then
      "$(($NIX_BUILD_CORES<=64 ? $NIX_BUILD_CORES : 64))"
    else if versionOlder version "1.65" then
      "$(($NIX_BUILD_CORES<=256 ? $NIX_BUILD_CORES : 256))"
    else
      "$NIX_BUILD_CORES";

  b2Args = concatStringsSep " " ([
    "--includedir=$dev/include"
    "--libdir=$out/lib"
    "-j${jobs}"
    "--layout=${layout}"
    "variant=${variant}"
    "threading=${threading}"
    "link=${link}"
    "-sEXPAT_INCLUDE=${expat.dev}/include"
    "-sEXPAT_LIBPATH=${expat.out}/lib"

    # TODO: make this unconditional
  ] ++ optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    "address-model=${toString stdenv.hostPlatform.parsed.cpu.bits}"
    "architecture=${toString stdenv.hostPlatform.parsed.cpu.family}"
    "binary-format=${toString stdenv.hostPlatform.parsed.kernel.execFormat.name}"
    "target-os=${toString stdenv.hostPlatform.parsed.kernel.name}"

    # adapted from table in boost manual
    # https://www.boost.org/doc/libs/1_66_0/libs/context/doc/html/context/architectures.html
    "abi=${if stdenv.hostPlatform.parsed.cpu.family == "arm" then "aapcs"
           else if stdenv.hostPlatform.isWindows then "ms"
           else if stdenv.hostPlatform.isMips then "o32"
           else "sysv"}"
  ] ++ optional (link != "static") "runtime-link=${runtime-link}"
    ++ optional (variant == "release") "debug-symbols=off"
    ++ optional (toolset != null) "toolset=${toolset}"
    ++ optional (!enablePython) "--without-python"
    ++ optional (mpi != null || stdenv.hostPlatform != stdenv.buildPlatform) "--user-config=user-config.jam"
    ++ optionals (stdenv.hostPlatform.libc == "msvcrt") [
    "threadapi=win32"
  ]);

in

stdenv.mkDerivation {
  name = "boost-${version}";

  inherit src;

  patchFlags = "";

  patches = patches
    ++ optional stdenv.isDarwin ./darwin-no-system-python.patch;

  meta = {
    homepage = http://boost.org/;
    description = "Collection of C++ libraries";
    license = stdenv.lib.licenses.boost;

    platforms = (if versionOlder version "1.59" then remove "aarch64-linux" else id) (platforms.unix ++ platforms.windows);
    maintainers = with maintainers; [ peti wkennington ];
  };

  preConfigure = ''
    if test -f tools/build/src/tools/clang-darwin.jam ; then
        substituteInPlace tools/build/src/tools/clang-darwin.jam \
          --replace '@rpath/$(<[1]:D=)' "$out/lib/\$(<[1]:D=)";
    fi;
  '' + optionalString (mpi != null) ''
    cat << EOF >> user-config.jam
    using mpi : ${mpi}/bin/mpiCC ;
    EOF
  '' + optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    cat << EOF >> user-config.jam
    using gcc : cross : ${stdenv.cc.targetPrefix}c++ ;
    EOF
  '';

  NIX_CFLAGS_LINK = stdenv.lib.optionalString stdenv.isDarwin
                      "-headerpad_max_install_names";

  enableParallelBuilding = true;

  nativeBuildInputs = [ which ];
  depsBuildBuild = [ buildPackages.stdenv.cc ];
  buildInputs = [ expat zlib bzip2 libiconv ]
    ++ optional (stdenv.hostPlatform == stdenv.buildPlatform) icu
    ++ optional stdenv.isDarwin fixDarwinDylibNames
    ++ optional enablePython python
    ++ optional enableNumpy python.pkgs.numpy;

  configureScript = "./bootstrap.sh";
  configurePlatforms = [];
  configureFlags = [
    "--includedir=$(dev)/include"
    "--libdir=$(out)/lib"
  ] ++ optional enablePython "--with-python=${python.interpreter}"
    ++ [ (if stdenv.hostPlatform == stdenv.buildPlatform then "--with-icu=${icu.dev}" else "--without-icu") ]
    ++ optional (toolset != null) "--with-toolset=${toolset}";

  buildPhase = ''
    ./b2 ${b2Args}
  '';

  installPhase = ''
    # boostbook is needed by some applications
    mkdir -p $dev/share/boostbook
    cp -a tools/boostbook/{xsl,dtd} $dev/share/boostbook/

    # Let boost install everything else
    ./b2 ${b2Args} install
  '';

  postFixup = ''
    # Make boost header paths relative so that they are not runtime dependencies
    cd "$dev" && find include \( -name '*.hpp' -or -name '*.h' -or -name '*.ipp' \) \
      -exec sed '1s/^\xef\xbb\xbf//;1i#line 1 "{}"' -i '{}' \;
  '' + optionalString (stdenv.hostPlatform.libc == "msvcrt") ''
    $RANLIB "$out/lib/"*.a
  '';

  outputs = [ "out" "dev" ];
  setOutputFlags = false;
}
*/