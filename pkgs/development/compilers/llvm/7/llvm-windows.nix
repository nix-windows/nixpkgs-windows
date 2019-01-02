{ stdenv
, lib
, fetch, fetchGit
, cmake
, python
, ninja
, libffi
#, libbfd
#, libpfm
, libxml2
#, ncurses
, version
, zlib
, debugVersion ? false
#, enableManpages ? false
#, enableSharedLibraries ? true
, enableWasm ? true
#, enablePFM ? !stdenv.isDarwin
, buildType
}:

let
  buildTargets = { llvm  = [ "llc" "lld" "lli" "llvm-lib" "llvm-ar" /* more?*/ ];
                   clang = [ "clang" ];
                   lld   = [ "lld" ];
                   lldb  = [ "lldb" ];
                   all   = [ "all" ];
                 }.${buildType};
in stdenv.mkDerivation rec {
  name = "llvm-${buildType}-${version}";

  src = if version == "7.0.1" then
  let
    llvm_src              = fetch "llvm"              "16s196wqzdw4pmri15hadzqgdi926zln3an2viwyq0kini6zr3d3";
    lld_src               = fetch "lld"               "0ca0qygrk87lhjk6cpv1wbmdfnficqqjsda3k7b013idvnralsc8";
    lldb_src              = fetch "lldb"              "10k9lyk3i72j9hca523r9pz79qp7d8q7jqnjy0i3saj1bgknpd3n";
    clang_src             = fetch "cfe"               "067lwggnbg0w1dfrps790r5l6k8n5zwhlsw7zb6zvmfpwpfn4nx4";
    clang-tools-extra_src = fetch "clang-tools-extra" "1v9vc7id1761qm7mywlknsp810232iwyz8rd4y5km4h7pg9cg4sc";
    compiler-rt_src       = fetch "compiler-rt"       "065ybd8fsc4h2hikbdyricj6pyv4r7r7kpcikhb2y5zf370xybkq";
    libunwind_src         = fetch "libunwind"         "04jrifbpl1czdqavgfjbyp8dfyn6ac5w2nlxrbdpk4px3ncm5j49";
    libcxxabi_src         = fetch "libcxxabi"         "1n6yx0949l9bprh75dffchahn8wplkm79ffk4f2ap9vw2lx90s41";
    libcxx_src            = fetch "libcxx"            "1wdrxg365ig0kngx52pd0n820sncp24blb0zpalc579iidhh4002";
    openmp_src            = fetch "openmp"            "030dkg5cypd7j9hq0mcqb5gs31lxwmzfq52j81l7v9ldcy5bf5mz";
  in stdenv.mkDerivation {
    name = "${name}-src";
    buildCommand = ''
      unpackFile '${llvm_src             }';
      unpackFile '${lld_src              }';
      unpackFile '${lldb_src             }';
      unpackFile '${clang_src            }';
      unpackFile '${clang-tools-extra_src}';
      unpackFile '${compiler-rt_src      }';
      unpackFile '${libunwind_src        }';
      unpackFile '${libcxxabi_src        }';
      unpackFile '${libcxx_src           }';
      unpackFile '${openmp_src           }';

      # 1: lldb-${version}.src/tools/lldb/test/testcases is a directory symlink to '..\packages\Python\lldbsuite\test'
      #    7z wrongly unpacks it as a file symlink (https://sourceforge.net/p/sevenzip/bugs/2174/)
      # 2: Perl's unlink() is unable to delete symlink
      system('del       lldb-${version}.src\test\testcases'                                                                           ) == 0 or die "unlink: $!";
      system('mklink /D lldb-${version}.src\test\testcases ..\packages\Python\lldbsuite\test'                                         ) == 0 or die "mklink: $!";

      # https://sourceforge.net/p/sevenzip/bugs/2174/ workaround
      system('del       libcxx-${version}.src\test\std\input.output\filesystems\Inputs\static_test_env\symlink_to_dir'                ) == 0 or die "unlink: $!";
      system('mklink /D libcxx-${version}.src\test\std\input.output\filesystems\Inputs\static_test_env\symlink_to_dir dir1'           ) == 0 or die "mklink: $!";

      system('del       libcxx-${version}.src\test\std\input.output\filesystems\Inputs\static_test_env\dir1\dir2\symlink_to_dir3'     ) == 0 or die "unlink: $!";
      system('mklink /D libcxx-${version}.src\test\std\input.output\filesystems\Inputs\static_test_env\dir1\dir2\symlink_to_dir3 dir3') == 0 or die "mklink: $!";

      move('llvm-${version}.src',              "$ENV{out}"                        ) or die "move: $!";
      move('lld-${version}.src',               "$ENV{out}/tools/lld"              ) or die "move: $!";
      move('lldb-${version}.src',              "$ENV{out}/tools/lldb"             ) or die "move: $!";
      move('cfe-${version}.src',               "$ENV{out}/tools/clang"            ) or die "move: $!";
      move('clang-tools-extra-${version}.src', "$ENV{out}/tools/clang/tools/extra") or die "move: $!";
      move('compiler-rt-${version}.src',       "$ENV{out}/projects/compiler-rt"   ) or die "move: $!";
      move('libunwind-${version}.src',         "$ENV{out}/projects/libunwind"     ) or die "move: $!";
      move('libcxxabi-${version}.src',         "$ENV{out}/projects/libcxxabi"     ) or die "move: $!";
      move('libcxx-${version}.src',            "$ENV{out}/projects/libcxx"        ) or die "move: $!";
      move('openmp-${version}.src',            "$ENV{out}/projects/openmp"        ) or die "move: $!";
    '';
  }
  else if version == "8.0.0" then
  let
    llvm_src              = fetchGit "llvm"              "873a3e95c8d64ee8237021d3e56ded8a054f2984" "1xxhc6b3qz18vsgfzkchjg6sf1avhgf39drvj8117mv01zq7dnmj";
    lld_src               = fetchGit "lld"               "ed673fddf832ed44e04c7960d89e4b6a2d2afef0" "14jzp2ic9paykpscr4dqigpy2l7zlrp64rql5x0xlsdxlz22avcq";
    lldb_src              = fetchGit "lldb"              "6b7398e771b9a9abbef3e7aa70c0d229d671f744" "0y66rid6b578jlx94flvmbdg7021c77gn1sipny9dn6qp0756y90";
    clang_src             = fetchGit "clang"             "6cda55ec841c34fa8c4490d8e8a3f013f7779e16" "111q0yfdqhaf7yby736lf7hddgaabfaiw46zh50yd2h05r0qms9x";
    clang-tools-extra_src = fetchGit "clang-tools-extra" "93a546b52fbebbeffd91dcb44f577a7324bc3e10" "1lz9d2jz7w6hil835vivwwmb4mm2jkac8mgyaajbnyryyjw6di7n";
    compiler-rt_src       = fetchGit "compiler-rt"       "3d5a3668ac1501c6af00507d8349b6d09445639f" "15n41y2y41l7fmankicvl2gy9zpqr07z4m5hhplwzv83hcq79jw9";
    libunwind_src         = fetchGit "libunwind"         "9defb52f575beff21b646e60e63f72ad1ac7cf54" "0kc5z0lvfg8f90swdg5p2kl4kvmhxbdld876rmfkracdvswvc63r";
    libcxxabi_src         = fetchGit "libcxxabi"         "307bb62985575b2e3216a8cfd7e122e0574f33a9" "1wklsrmbczlf7h0z8y6m6kwdnbqh18rz5dkk9ifgj7wq0nq9r5yi";
    libcxx_src            = fetchGit "libcxx"            "51895bf735478464eaf17643e1235921594927f6" "0j8a6wj1qk4h07zd7npyinm9sjbwnlmdjc1prxsyxl9i0mrp5nlw";
    openmp_src            = fetchGit "openmp"            "a04cc5ff8bac7736c7bf5d9a8114ee1aa67e1ccc" "0cqdzyihgxf6kaax6yk9k231ih32c1m34j8262ymfghlic4sbb3n";
  in stdenv.mkDerivation {
    name = "${name}-src";
    buildCommand = ''
      system('xcopy', '/E/H/B/F/I', '${llvm_src             }' =~ s|/|\\|gr, "$ENV{out}"                         =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${lld_src              }' =~ s|/|\\|gr, "$ENV{out}/tools/lld"               =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${lldb_src             }' =~ s|/|\\|gr, "$ENV{out}/tools/lldb"              =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${clang_src            }' =~ s|/|\\|gr, "$ENV{out}/tools/clang"             =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${clang-tools-extra_src}' =~ s|/|\\|gr, "$ENV{out}/tools/clang/tools/extra" =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${compiler-rt_src      }' =~ s|/|\\|gr, "$ENV{out}/projects/compiler-rt"    =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${libunwind_src        }' =~ s|/|\\|gr, "$ENV{out}/projects/libunwind"      =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${libcxxabi_src        }' =~ s|/|\\|gr, "$ENV{out}/projects/libcxxabi"      =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${libcxx_src           }' =~ s|/|\\|gr, "$ENV{out}/projects/libcxx"         =~ s|/|\\|gr) == 0 or die "xcopy: $!";
      system('xcopy', '/E/H/B/F/I', '${openmp_src           }' =~ s|/|\\|gr, "$ENV{out}/projects/openmp"         =~ s|/|\\|gr) == 0 or die "xcopy: $!";

      # https://sourceforge.net/p/sevenzip/bugs/2174/ workaround
      system('del',          "$ENV{out}/tools/lldb/test/testcases"                                                                          =~ s|/|\\|gr                                     ) == 0 or die "unlink: $!";
      system('mklink', '/D', "$ENV{out}/tools/lldb/test/testcases"                                                                          =~ s|/|\\|gr, '..\packages\Python\lldbsuite\test') == 0 or die "mklink: $!";
      system('del',          "$ENV{out}/projects/libcxx/test/std/input.output/filesystems/Inputs/static_test_env/symlink_to_dir"            =~ s|/|\\|gr                                     ) == 0 or die "unlink: $!";
      system('mklink', '/D', "$ENV{out}/projects/libcxx/test/std/input.output/filesystems/Inputs/static_test_env/symlink_to_dir"            =~ s|/|\\|gr, 'dir1'                             ) == 0 or die "mklink: $!";
      system('del',          "$ENV{out}/projects/libcxx/test/std/input.output/filesystems/Inputs/static_test_env/dir1/dir2/symlink_to_dir3" =~ s|/|\\|gr                                     ) == 0 or die "unlink: $!";
      system('mklink', '/D', "$ENV{out}/projects/libcxx/test/std/input.output/filesystems/Inputs/static_test_env/dir1/dir2/symlink_to_dir3" =~ s|/|\\|gr, 'dir3'                             ) == 0 or die "mklink: $!";
    '';
  }
  else throw "version=${version}";

  nativeBuildInputs = [ cmake python ninja ];

  buildInputs = [ libxml2 /* dll */
                  zlib    /* static lib */ ]
    ++ lib.optional (libffi != null) libffi
    /*++ lib.optional enablePFM libpfm*/; # exegesis

  # use ninja instead of nmake for multicore build
  configurePhase = ''
    $ENV{INCLUDE} = "${zlib}/include;${libxml2}/include;$ENV{INCLUDE}"; # TODO: setup hook should handle this
    $ENV{LIB}     = "${zlib}/lib;${libxml2}/lib;$ENV{LIB}";             # TODO: setup hook should handle this
    mkdir("build");                                                                                                      # -\
    chdir("build");                                                                                                      #   >- TODO: cmake setup hook should handle this
    system("cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ENV{out} $ENV{cmakeFlags} ..") == 0 or die; # -/
  '';

  buildPhase = ''
    system("ninja ${lib.concatStringsSep " " buildTargets}") == 0 or die;
  '';

  doCheck = false; # it needs coreutils&findutils (cp, touch, chmod, rm, find, ...)
  checkPhase = ''
    system("ninja ${lib.concatMapStringsSep " " (x: "check-${x}") buildTargets}") == 0 or die;
  '';

  installPhase = ''
    system("ninja ${lib.concatMapStringsSep " " (x: if x == "all" then "install" else "install-${x}") buildTargets}") == 0 or die;
    copy('${zlib}/bin/zlib1.dll',      "$ENV{out}/bin/") or die "copy(zlib1.dll): $!";    # TODO: setup hook should handle this
    copy('${libxml2}/bin/libxml2.dll', "$ENV{out}/bin/") or die "copy(libxml2.dll): $!";  # TODO: setup hook should handle this
  '' + lib.optionalString (libffi != null) ''
    copy('${libffi}/bin/libffi-7.dll', "$ENV{out}/bin/") or die "copy(libffi.dll): $!";   # TODO: setup hook should handle this
  '';

  cmakeFlags = with stdenv; [
    "-DCMAKE_BUILD_TYPE=${if debugVersion then "Debug" else "Release"}"
    "-DLLVM_INSTALL_UTILS=ON"  # Needed by rustc
    "-DLLVM_BUILD_TESTS=${if doCheck then "ON" else "OFF"}"
    "-DLLVM_ENABLE_RTTI=ON"

    "-DLLVM_HOST_TRIPLE=${stdenv.hostPlatform.config}"
    "-DLLVM_DEFAULT_TARGET_TRIPLE=${stdenv.hostPlatform.config}"
    "-DTARGET_TRIPLE=${stdenv.hostPlatform.config}"

    "-DLLVM_TARGETS_WITH_JIT=X86"
    "-DLLVM_ALL_TARGETS=X86"
    "-DLLVM_TARGETS_TO_BUILD=X86"

    "-DLLVM_ENABLE_DUMP=ON"
  ]
  ++ lib.optionals (libffi != null) [
    "-DLLVM_ENABLE_FFI=ON"
    "-DFFI_INCLUDE_DIR=${libffi}/include" # TODO: $ENV{INCLUDE} / $ENV{LIB} is not enough
    "-DFFI_LIBRARY_DIR=${libffi}/lib"
  ]
  ++ lib.optionals enableWasm [
   "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly"
  ];

  meta = {
    description = "Collection of modular and reusable compiler and toolchain technologies";
    homepage    = http://llvm.org/;
    license     = lib.licenses.ncsa;
    maintainers = with lib.maintainers; [ lovek323 raskin dtzWill ];
    platforms   = lib.platforms.all;
  };
}
