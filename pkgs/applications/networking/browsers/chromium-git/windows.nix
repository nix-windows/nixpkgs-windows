{ stdenv, lib, fetchgit, fetchurl
, callPackage
, python2
, gn
, ninja
, llvmPackages_8
#, commandLineArgs ? ""
}:

let
  mkGnFlags =
    let
      # Serialize Nix types into GN types according to this document:
      # https://chromium.googlesource.com/chromium/src/+/master/tools/gn/docs/language.md
      mkGnString = value: "\"${lib.escape ["\"" "$" "\\"] value}\"";
      sanitize = value:
        if value == true then "true"
        else if value == false then "false"
        else if lib.isList value then "[${lib.concatMapStringsSep ", " sanitize value}]"
        else if lib.isInt value then toString value
        else if lib.isString value then mkGnString value
        else throw "Unsupported type for GN value `${value}'.";
      toFlag = key: value: "${key}=${sanitize value}";
    in attrs: lib.concatStringsSep " " (lib.attrValues (lib.mapAttrs toFlag attrs));


  gnFlags = mkGnFlags {
    is_debug = false;
    use_jumbo_build = true; # at least 2X compilation speedup

    proprietary_codecs = false;
    enable_nacl = false;
    is_component_build = true;
    is_clang = true;

    # Google API keys, see:
    #   http://www.chromium.org/developers/how-tos/api-keys
    # Note: These are for NixOS/nixpkgs use ONLY. For your own distribution,
    # please get your own set of keys.
    google_api_key = "AIzaSyDGi15Zwl11UNe6Y-5XW_upsfyw31qwZPI";
    google_default_client_id = "404761575300.apps.googleusercontent.com";
    google_default_client_secret = "9rIFQjfnkykEmqb6FfjJQD1D";
  };

  version = "73.0.3676.0"; # update feed https://github.com/chromium/chromium/releases
  deps = import (./sources- + version + ".nix") { inherit fetchgit; };
  src = stdenv.mkDerivation rec {
    name = "chromium-${version}-src";
    buildCommand = ''
    '' + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (path: src: ''
                            symtree_link($ENV{out}, '${src}' => '${path}') or die "symtree_link($ENV{out}, ${src}, ${path}): $!";
                          '') deps
    );
  };

in stdenv.mkDerivation rec {
  name = "chromium-${version}";
  inherit src;

  nativeBuildInputs = [ gn ninja (python2.withPackages (p: [ p.pywin32 ])) ];

  # introduce files missing in git repos
  postPatch = ''
    symtree_link ('.', '${llvmPackages_8.llvm}' => 'src\third_party\llvm-build\Release+Asserts');

    # ensure these pathes are writable (not symlinks to nix store)
    symtree_reify('.', 'src\build\config\gclient_args.gni'       );
    symtree_reify('.', 'src\build\util\LASTCHANGE'               );
    symtree_reify('.', 'src\build\util\LASTCHANGE.committime'    );
    symtree_reify('.', 'src\gpu\config\gpu_lists_version.h'      );
    symtree_reify('.', 'src\skia\ext\skia_commit_hash.h'         );
    symtree_reify('.', 'src\build\toolchain\win\rc\win\rc.exe'   );
    symtree_reify('.', 'src\third_party\node\win\node.exe'       );
    symtree_reify('.', 'src\third_party\node\node_modules.tar.gz');

    writeFile('src\build\config\gclient_args.gni', qq[
    build_with_chromium = true
    checkout_android = false
    checkout_android_native_support = false
    checkout_nacl = false
    checkout_oculus_sdk = false
    ]) or die $!;
    writeFile('src\build\util\LASTCHANGE',            'LASTCHANGE=${deps."src".rev}-refs/heads/master@{#0}') or die $!;
    writeFile('src\build\util\LASTCHANGE.committime', '1555555555') or die $!;
    writeFile('src\gpu\config\gpu_lists_version.h', qq[
    /* Generated by lastchange.py, do not edit.*/
    #ifndef GPU_CONFIG_GPU_LISTS_VERSION_H_
    #define GPU_CONFIG_GPU_LISTS_VERSION_H_
    #define GPU_LISTS_VERSION "${deps."src".rev}"
    #endif  // GPU_CONFIG_GPU_LISTS_VERSION_H_
    ]) or die $!;
    writeFile('src\skia\ext\skia_commit_hash.h', qq[
    /* Generated by lastchange.py, do not edit.*/
    #ifndef SKIA_EXT_SKIA_COMMIT_HASH_H_
    #define SKIA_EXT_SKIA_COMMIT_HASH_H_
    #define SKIA_COMMIT_HASH "${deps."src/third_party/skia".rev}-"
    #endif  // SKIA_EXT_SKIA_COMMIT_HASH_H_
    ]) or die $!;

    readFile('src\build\toolchain\win\rc\win\rc.exe.sha1'   ) =~ s/\s//gr eq "ba51d69039ffb88310b72b6568efa9f0de148f8f" or die;
    readFile('src\third_party\node\win\node.exe.sha1'       ) =~ s/\s//gr eq "b8a7c3e2e5f3e88a3e9c132bec496b917d1f2fd8" or die;
    readFile('src\third_party\node\node_modules.tar.gz.sha1') =~ s/\s//gr eq "c0e0f34498afb3f363cc37cd2e9c1a020cb020d9" or die;

    copyL('${fetchurl { url  = "https://commondatastorage.googleapis.com/chromium-browser-clang/rc/ba51d69039ffb88310b72b6568efa9f0de148f8f";
                        sha1 = "ba51d69039ffb88310b72b6568efa9f0de148f8f"; }}',
          'src\build\toolchain\win\rc\win\rc.exe') or die $!;

    # (todo use from pkgs?)
    copyL('${fetchurl { url  = "https://nodejs.org/dist/v8.9.1/win-x64/node.exe";
                             # "https://commondatastorage.googleapis.com/chromium-nodejs/8.9.1/b8a7c3e2e5f3e88a3e9c132bec496b917d1f2fd8"
                        sha1 = "b8a7c3e2e5f3e88a3e9c132bec496b917d1f2fd8"; }}',
          'src\third_party\node\win\node.exe') or die $!;

    system('7z x ${fetchurl { url  = "https://commondatastorage.googleapis.com/chromium-nodejs/c0e0f34498afb3f363cc37cd2e9c1a020cb020d9";
                              sha1 = "c0e0f34498afb3f363cc37cd2e9c1a020cb020d9"; }} -so | 7z x -aoa -si -ttar -osrc\third_party\node') == 0 or die $!;
  '';

  DEPOT_TOOLS_WIN_TOOLCHAIN = "0";
  GYP_MSVS_OVERRIDE_PATH    = "${stdenv.cc}";
  WINDOWSSDKDIR             = "${stdenv.cc.sdk}";
  WINDIR                    = "C:\\Windows"; # to get msvcp140.dll and other redistributables (todo: try to use stdenv.cc.redist)

  configurePhase = ''
    chdir('src');
    system('gn.exe gen --args=${lib.escapeWindowsArg gnFlags} out/Release') == 0 or die;
  '';

  buildPhase = ''
    system('ninja.exe -C out/Release chrome') == 0 or die;
  '';

  installPhase = ''
    make_pathL("$ENV{out}/bin/locales", "$ENV{out}/bin/swiftshader");
    for my $in (glob("out/Release/*")) {
      copyL($in, "$ENV{out}/bin/".basename($in)) if $in =~ /\.(bin|dat|dll|pak|pdb|manifest)$/ || basename($in) =~ /^chrome(_proxy|)\.exe$/;
    }
    for my $in (glob("out/Release/swiftshader/*")) {
      copyL($in, "$ENV{out}/bin/swiftshader/".basename($in)) if $in =~ /\.(dll|pdb)$/;
    }
    for my $in (glob("out/Release/locales/*")) {
      copyL($in, "$ENV{out}/bin/locales/".basename($in)) if $in =~ /\.(pak)$/;
    }
  '';
}
