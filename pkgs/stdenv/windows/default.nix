{ lib
, localSystem, crossSystem, config, overlays
}:

assert crossSystem == null;

let
  inherit (localSystem) system;

  # bootstrap perl, binary distribution
  shell =
#   if system == "x86_64-windows" then /*"C:/Windows/System32/cmd.exe"*/
    "C:/Perl64/bin/perl.exe"
#   else if system == "i686-freebsd" || system == "x86_64-freebsd" then "/usr/local/bin/bash"
#   else "/bin/bash"
    ;

  path = [];

  # A function that builds a "native" stdenv (one that uses tools in
  # /usr etc.).
  makeStdenv =
    { cc, fetchurl, extraPath ? [], overrides ? (self: super: { }) }:

    import ../generic {
      buildPlatform = localSystem;
      hostPlatform = localSystem;
      targetPlatform = localSystem;

      preHook = "";
#       if system == "i686-freebsd" then prehookFreeBSD else
#       if system == "x86_64-freebsd" then prehookFreeBSD else
#       if system == "i686-openbsd" then prehookOpenBSD else
#       if system == "i686-netbsd" then prehookNetBSD else
#       if system == "i686-cygwin" then prehookCygwin else
#       if system == "x86_64-cygwin" then prehookCygwin else
#       prehookBase;

      extraNativeBuildInputs =
#       if system == "i686-cygwin" then extraNativeBuildInputsCygwin else
#       if system == "x86_64-cygwin" then extraNativeBuildInputsCygwin else
        [];

      initialPath = extraPath ++ path;

      fetchurlBoot = fetchurl;

      inherit shell cc overrides config;
    };

in

[

  ({}: rec {
    __raw = true;

    stdenv = makeStdenv {
      cc = null;
      fetchurl = null;
    };
    stdenvNoCC = stdenv;

    cc = let
      msvc = stdenvNoCC.mkDerivation rec {
        version = "14.16.27023";
        name = "msvc-${version}";
        preferLocalBuild = true;
        buildCommand = ''
          dircopy("C:/Program Files (x86)/Microsoft Visual Studio/Preview/Community/VC/Tools/MSVC/14.16.27023", $ENV{out}) or die "$!";
        '';
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "16v8qsjajvym39yc0crg59hmwds4m42sgf95nz5v02fiysv78zqw";
      };
      sdk = stdenvNoCC.mkDerivation rec {
        version = "10.0.17134.0";
        name = "sdk-${version}";
        preferLocalBuild = true;
        buildCommand = ''
          dircopy("C:/Program Files (x86)/~Windows Kits~~/10", $ENV{out}) or die "$!";

          # so far there is no `substituteInPlace`
          for my $filename (glob("$ENV{out}/DesignTime/CommonConfiguration/Neutral/*.props")) {
            open(my $in, $filename) or die $!;
            open(my $out, ">$filename.new") or die $!;
            for my $line (<$in>) {
              $line =~ s|\$\(Registry:HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots\@KitsRoot10\)|\$([MSBUILD]::GetDirectoryNameOfFileAbove('\$(MSBUILDTHISFILEDIRECTORY)', 'sdkmanifest.xml'))\\|g;
              $line =~ s|(\$\(Registry:[^)]+\))|<!-- $1 -->|g;
              print $out $line;
            }
            close($in);
            close($out);
            move("$filename.new", $filename) or die $!;
          }
        '';
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "134i0dlq6vmicbg5rdm9z854p1s3nsdb5lhbv1k2190rv2jmig11";
      };
      msbuild = stdenvNoCC.mkDerivation rec {
        version = "15.0";
        name = "msbuild-${version}";
        preferLocalBuild = true;
        buildCommand = ''
          use File::Copy::Recursive qw(dircopy);
          dircopy("C:/Program Files (x86)/Microsoft Visual Studio/Preview/Community/MSBuild", $ENV{out}) or die "$!";
        '';
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "1yqx3yvvamid5d9yza7ya84vdxg89zc7qvm2b5m9v8hsmymjrvg6";
      };
      vc = stdenvNoCC.mkDerivation rec { # needs to compile .vcprojx (for example Python3)
        name = "msbuild-${msvc.version}";
        preferLocalBuild = true;
        buildCommand = ''
          dircopy("C:/Program Files (x86)/~Microsoft Visual Studio~/Preview/Community/Common7/IDE/VC", $ENV{out}) or die "$!";

          # so far there is no `substituteInPlace`
          for my $filename (glob("$ENV{out}/VCTargets/*.props"), glob("$ENV{out}/VCTargets/*.targets")) {
            open(my $in, $filename) or die $!;
            open(my $out, ">$filename.new") or die $!;
            for my $line (<$in>) {
              $line =~ s|>(\$\(Registry:HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots\@KitsRoot10\))|>${sdk}/<!-- $1 -->|g;
              $line =~ s|>(\$\(Registry:HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\Microsoft SDKs\\Windows\\v10.0\@InstallationFolder\))|>${sdk}/<!-- $1 -->|g;
              $line =~ s|\$\(VCToolsInstallDir_150\)|${msvc}/|g;
              $line =~ s|>(\$\(Registry:[^)]+\))|><!-- $1 -->|g;
              print $out $line;
            }
            close($in);
            close($out);
            move("$filename.new", $filename) or die $!;
          }
        '';
      };
      cc-wrapper = stdenvNoCC.mkDerivation {
        name = "${msvc.name}+${sdk.name}+${msbuild.name}";
        preferLocalBuild = true;
        buildCommand = ''
          mkdir $ENV{out} or die;
          mkdir "$ENV{out}/bin" or die;

          my $INCLUDE='${msvc}/include;${sdk}/include/${sdk.version}/ucrt;${sdk}/include/${sdk.version}/shared;${sdk}/include/${sdk.version}/um;${sdk}/include/${sdk.version}/winrt;${sdk}/include/${sdk.version}/cppwinrt';
          my $LIB='${msvc}/lib/x64;${sdk}/lib/${sdk.version}/ucrt/x64;${sdk}/lib/${sdk.version}/um/x64';

          # set the environment to compile makeWrapper when there is no wrappers yet
          $ENV{INCLUDE} = $INCLUDE;
          $ENV{LIB}     = $LIB;
          $ENV{PATH}    = "${msvc}/bin/HostX64/x64;$ENV{PATH}";
          system("cl /EHsc /Fe:$ENV{out}/bin/makeWrapper.exe ${./makeWrapper.cpp}") == 0 or die "cl: $!";

          for my $name ('cl', 'ml64', 'lib', 'link', 'nmake', 'mc', 'mt', 'rc', 'dumpbin', 'csc', 'msbuild') {
            $target = "${msvc}/bin/HostX64/x64/$name.exe"                   if -f "${msvc}/bin/HostX64/x64/$name.exe";
            $target = "${sdk}/bin/${sdk.version}/x64/$name.exe"             if -f "${sdk}/bin/${sdk.version}/x64/$name.exe";
            $target = "${sdk}/bin/x64/$name.exe"                            if -f "${sdk}/bin/x64/$name.exe";
            $target = "${msbuild}/${msbuild.version}/bin/Roslyn/$name.exe"  if -f "${msbuild}/${msbuild.version}/bin/Roslyn/$name.exe";
            $target = "${msbuild}/${msbuild.version}/bin/$name.exe"         if -f "${msbuild}/${msbuild.version}/bin/$name.exe";
            dir unless $target;

            system("$ENV{out}/bin/makeWrapper.exe", $target, "$ENV{out}/bin/$name.exe",
                   '--prefix', 'PATH',             ';', '${msvc}/bin/HostX64/x64;${sdk}/bin/${sdk.version}/x64;${sdk}/bin/x64;${msbuild}/${msbuild.version}/bin/Roslyn;${msbuild}/${msbuild.version}/bin',
                   '--set',    'INCLUDE',               $INCLUDE,
                   '--set',    'LIB',                   $LIB,
                   '--set',    'LIBPATH',               '${msvc}/lib/x64;${msvc}/lib/x86/store/references;${sdk}/UnionMetadata/${sdk.version};${sdk}/References/${sdk.version}',
                   '--set',    'WindowsLibPath',        '${sdk}/UnionMetadata/${sdk.version};${sdk}/References/${sdk.version}',
                   '--set',    'WindowsSDKLibVersion',  '${sdk.version}',
                   '--set',    'WindowsSDKVersion',     '${sdk.version}',
                   '--set',    'WindowsSdkVerBinPath',  '${sdk}/bin/${sdk.version}',
                   '--set',    'WindowsSdkBinPath',     '${sdk}/bin',
                   '--set',    'WindowsSdkDir',         '${sdk}',
                   '--set',    'VCToolsVersion',        '${msvc.version}',
                   '--set',    'VCToolsInstallDir',     '${msvc}',
                   '--set',    'VCToolsRedistDir',      '${msvc}',
                   '--set',    'VCTargetsPath',         '${vc}/VCTargets',
                   '--set',    'UCRTVersion',           '${sdk.version}',
                   '--set',    'UniversalCRTSdkDir',    '${sdk}/'
                  ) == 0 or die "makeWrapper failed: $!";

            # just for debugging, better use .exe-wrappers as they do not need to be prefixed with 'call'
            open(my $fh, ">$ENV{out}/bin/_$name.bat");
            print $fh "\@echo off\n";
            print $fh "PATH"                     ."=${msvc}/bin/HostX64/x64;${sdk}/bin/${sdk.version}/x64;${sdk}/bin/x64;${msbuild}/${msbuild.version}/bin/Roslyn;${msbuild}/${msbuild.version}/bin;%PATH%\n";
            print $fh "set INCLUDE"              ."=$INCLUDE\n";
            print $fh "set LIB"                  ."=$LIB\n";
            print $fh "set LIBPATH"              ."=${msvc}/lib/x64;${msvc}/lib/x86/store/references;${sdk}/UnionMetadata/${sdk.version};${sdk}/References/${sdk.version}\n";
            print $fh "set WindowsLibPath"       ."=${sdk}/UnionMetadata/${sdk.version};${sdk}/References/${sdk.version}\n";
            print $fh "set WindowsSDKLibVersion" ."=${sdk.version}\n";
            print $fh "set WindowsSDKVersion"    ."=${sdk.version}\n";
            print $fh "set WindowsSdkVerBinPath" ."=${sdk}/bin/${sdk.version}\n";
            print $fh "set WindowsSdkBinPath"    ."=${sdk}/bin\n";
            print $fh "set WindowsSdkDir"        ."=${sdk}\n";
            print $fh "set VCToolsVersion"       ."=${msvc.version}\n";
            print $fh "set VCToolsInstallDir"    ."=${msvc}\n";
            print $fh "set VCToolsRedistDir"     ."=${msvc}\n";
            print $fh "set VCTargetsPath"        ."=${vc}/VCTargets\n";
            print $fh "set UCRTVersion"          ."=${sdk.version}\n";
            print $fh "set UniversalCRTSdkDir"   ."=${sdk}/\n";
            print $fh "$target %*\n";
            close($fh);
          }
        '';
        passthru = {
          targetPrefix = "";
          isClang = false;
          isGNU = false;
          inherit msvc sdk msbuild vc;
        };
      };
    in
      cc-wrapper;
#      else
#        let
#          nativePrefix = { # switch
#            "i686-solaris" = "/usr/gnu";
#            "x86_64-solaris" = "/opt/local/gcc47";
##           "x86_64-windows" = "/mingw64";
##           "x86_64-windows" = "/c/LLVM";
#          }.${system} /*or "/usr"*/;
#        in
#        import ../../build-support/cc-wrapper {
#          name = "cc-native";
#          nativeTools = true;
#          nativeLibc = true;
#          inherit nativePrefix;
#          bintools = import ../../build-support/bintools-wrapper {
#            name = "bintools";
#            inherit stdenvNoCC nativePrefix;
#            nativeTools = true;
#            nativeLibc = true;
#          };
#          inherit stdenvNoCC;
#        };

    fetchurl = import ../../build-support/fetchurl {
      inherit lib stdenvNoCC;
      # Curl should be in /usr/bin or so.
      curl = null;
    };

  })

   # First build a stdenv based only on tools outside the store.
   (prevStage: {
     inherit config overlays;
     stdenv = makeStdenv {
       inherit (prevStage) cc fetchurl;
     } // { inherit (prevStage) fetchurl; };
   })

   # Using that, build a stdenv that adds the ‘xz’ command (which most systems
   # don't have, so we mustn't rely on the native environment providing it).
#  (prevStage: {
#    inherit config overlays;
#    stdenv = makeStdenv {
#      inherit (prevStage.stdenv) cc fetchurl;
#      extraPath = [ prevStage.xz ];
#      overrides = self: super: { inherit (prevStage) xz; };
#    };
#  })

]
