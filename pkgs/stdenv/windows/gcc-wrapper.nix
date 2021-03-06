# https://wasm.in/threads/kollekcija-platform-sdk.17874/

{ stdenvNoCC, lib, /*buildPackages,*/ msysPacman, mingwPacman }:

let
  makeWrapper =
    assert stdenvNoCC.isShellPerl;
    stdenvNoCC.mkDerivation rec {
      name         = "makeWrapper";
      PATH         = "${mingwPacman.gcc}/mingw${if stdenvNoCC.is64bit then "64" else "32"}/bin"; # for cc1plus.exe to find dlls
      buildCommand = ''
        make_pathL("$ENV{out}/bin") or die $!;
        print("PATH=$ENV{PATH}\n");
        system('c++.exe',
               '-static',
               '-o', "$ENV{out}/bin/makeWrapper.exe",
               '-municode',
               '-Wl,-subsystem:console',
               '${lib.escapeWindowsArg "-DPATH=${PATH}"}',        # for cc1plus.exe to find dlls
               '${lib.escapeWindowsArg "-DCC=${PATH}/c++.exe"}',
               '${../../development/compilers/msvc/makeWrapper.cpp}');

      '';
    };
in
  # do we really need this gcc-wrapper here, ot is it enough to set PATH to "${mingwPacman.gcc}/bin;${mingwPacman.make}/bin;${mingwPacman.grep}/bin;${mingwPacman.gawk}/bin;${mingwPacman.sed}/bin;${mingwPacman.patch}/bin"
  stdenvNoCC.mkDerivation {
    name = "gcc-wrapper-${stdenvNoCC.buildPlatform.parsed.cpu.name}+${stdenvNoCC.hostPlatform.parsed.cpu.name}+${stdenvNoCC.targetPlatform.parsed.cpu.name}";
    buildCommand = ''
      make_pathL("$ENV{out}/bin") or die "make_pathL: $!";

      my $extraPath = join(';', "$ENV{out}/bin",
                                '${mingwPacman.gcc  }/mingw${if stdenvNoCC.is64bit then "64" else "32"}/bin', # for cc1plus.exe to find dlls
                           );
      print("extraPath=$extraPath\n");

      for my $name ('cc', 'gcc', 'c++', 'g++', 'ld', 'cpp', 'nm', 'as', 'ar', 'windres', 'objdump', 'objcopy', 'ranlib', 'dlltool',
                    'mingw32-make') {
        my $target;
        for my $path ('${mingwPacman.gcc  }/mingw${if stdenvNoCC.is64bit then "64" else "32"}/bin',
                      '${mingwPacman.make }/mingw${if stdenvNoCC.is64bit then "64" else "32"}/bin') {
          die unless $path;
          if (-f "$path/$name.exe") {
            $target = "$path/$name.exe";
            last;
          }
        }

        if ($target) {
          print("wrapping $target\n");
          system( "${makeWrapper}/bin/makeWrapper.exe", $target, "$ENV{out}/bin/$name.exe"
                , '--prefix', 'PATH',               ';', $extraPath,
              # , '--suffix', 'INCLUDE',            ';', '${mingwPacman.gcc}/mingw${if stdenvNoCC.is64bit then "64/x86_64" else "32/i686"}-w64-mingw32/include'   # needless?
              # , '--suffix', 'LIB',                ';', '${mingwPacman.gcc}/mingw${if stdenvNoCC.is64bit then "64/x86_64" else "32/i686"}-w64-mingw32/lib'       # needless?
                ) == 0 or die "makeWrapper failed: $!";
        } else {
          print "no target $name.exe on PATH\n";
        }
      }

      # HACK: so far msysPacman.* have no /bin/ and thus not on path
      uncsymlink('${msysPacman.patch}/usr/bin/patch.exe' => "$ENV{out}/bin/patch.exe");
      uncsymlink('${msysPacman.gawk }/usr/bin/gawk.exe'  => "$ENV{out}/bin/gawk.exe" );
      for my $f (glob('${msysPacman.gawk }/usr/bin/*.dll'),
                 glob('${msysPacman.patch}/usr/bin/*.dll')) {
        uncsymlink($f  => "$ENV{out}/bin/".basename($f) );
      }
    '';

    passthru = {
      isMSVC  = false;
      isClang = false;
      isGNU   = true;
      cc = mingwPacman.gcc;
#     makeWrapper = makeWrapper;
      redist = mingwPacman.gcc; # TODO: where `fixupPhase` hook will find runtimes dlls
#     INCLUDE = "${mingwPacman.gcc}/mingw${if stdenvNoCC.is64bit then "64/x86_64" else "32/i686"}-w64-mingw32/include";
#     LIB     = "${mingwPacman.gcc}/mingw${if stdenvNoCC.is64bit then "64/x86_64" else "32/i686"}-w64-mingw32/lib";
#     PATH    = "${mingwPacman.gcc}/mingw${if stdenvNoCC.is64bit then "64" else "32"}/bin";
    };
  }
