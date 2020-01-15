{ stdenv, fetchurl, pkgconfig, pcre, perl, flex, bison, gettext, libpcap, libnl, c-ares
, gnutls, libgcrypt, libgpgerror, geoip, openssl, lua5, python3, libcap, glib
, libssh, nghttp2, zlib, cmake, fetchpatch, makeWrapper
, qt5 ? null
, ApplicationServices, SystemConfiguration, gmp
}:


with stdenv.lib;

let
common = { version, sources-sha256 }: { withQt }:
assert withQt -> qt5 != null;
stdenv.mkDerivation {
  pname = "wireshark-${if withQt then "qt" else "cli"}";
  inherit version;
  outputs = [ "out" "dev" ];

  src = fetchurl {
    url = "https://www.wireshark.org/download/src/all-versions/wireshark-${version}.tar.xz";
    sha256 = sources-sha256;
  };

  cmakeFlags = [
    "-DBUILD_wireshark=${if withQt then "ON" else "OFF"}"
    "-DENABLE_APPLICATION_BUNDLE=${if withQt && stdenv.isDarwin then "ON" else "OFF"}"
  ];

  nativeBuildInputs = [
    bison cmake flex pkgconfig
  ] ++ optional withQt qt5.wrapQtAppsHook;

  buildInputs = [
    gettext pcre perl libpcap lua5 libssh nghttp2 openssl libgcrypt
    libgpgerror gnutls geoip c-ares python3 glib zlib makeWrapper
  ] ++ optionals withQt  (with qt5; [ qtbase qtmultimedia qtsvg qttools ])
    ++ optionals stdenv.isLinux  [ libcap libnl ]
    ++ optionals stdenv.isDarwin [ SystemConfiguration ApplicationServices gmp ]
    ++ optionals (withQt && stdenv.isDarwin) (with qt5; [ qtmacextras ]);

  patches = [ ./wireshark-lookup-dumpcap-in-path.patch ]
    # https://code.wireshark.org/review/#/c/23728/
    ++ stdenv.lib.optional stdenv.hostPlatform.isMusl (fetchpatch {
      name = "fix-timeout.patch";
      url = "https://code.wireshark.org/review/gitweb?p=wireshark.git;a=commitdiff_plain;h=8b5b843fcbc3e03e0fc45f3caf8cf5fc477e8613;hp=94af9724d140fd132896b650d10c4d060788e4f0";
      sha256 = "1g2dm7lwsnanwp68b9xr9swspx7hfj4v3z44sz3yrfmynygk8zlv";
    });

  postPatch = ''
    sed -i -e '1i cmake_policy(SET CMP0025 NEW)' CMakeLists.txt
  '';

  preBuild = ''
    export LD_LIBRARY_PATH="$PWD/run"
  '';

  postInstall = optionalString (versionAtLeast version "3.0") ''
    # to remove "cycle detected in the references"
    mkdir -p $dev/lib/wireshark
    mv $out/lib/wireshark/cmake $dev/lib/wireshark
  '' + (optionalString withQt (if stdenv.isDarwin then ''
    mkdir -p $out/Applications
    mv $out/bin/Wireshark.app $out/Applications/Wireshark.app

    for f in $(find $out/Applications/Wireshark.app/Contents/PlugIns -name "*.so"); do
        for dylib in $(otool -L $f | awk '/^\t*lib/ {print $1}'); do
            install_name_tool -change "$dylib" "$out/lib/$dylib" "$f"
        done
    done

    wrapQtApp $out/Applications/Wireshark.app/Contents/MacOS/Wireshark
  '' else ''
    install -Dm644 -t $out/share/applications ../wireshark.desktop

    substituteInPlace $out/share/applications/*.desktop \
        --replace "Exec=wireshark" "Exec=$out/bin/wireshark"

    install -Dm644 ../image/wsicon.svg $out/share/icons/wireshark.svg
  '')) + ''
    mkdir $dev/include/{epan/{wmem,ftypes,dfilter},wsutil,wiretap} -pv
    cp config.h $dev/include/
    cp ../ws_*.h $dev/include
    cp ../epan/*.h $dev/include/epan/
    cp ../epan/wmem/*.h $dev/include/epan/wmem/
    cp ../epan/ftypes/*.h $dev/include/epan/ftypes/
    cp ../epan/dfilter/*.h $dev/include/epan/dfilter/
    cp ../wsutil/*.h $dev/include/wsutil/
    cp ../wiretap/*.h $dev/include/wiretap
  '';

  enableParallelBuilding = true;

  dontFixCmake = true;

  shellHook = ''
    # to be able to run the resulting binary
    export WIRESHARK_RUN_FROM_BUILD_DIRECTORY=1
  '';

  meta = with stdenv.lib; {
    homepage = https://www.wireshark.org/;
    description = "Powerful network protocol analyzer";
    license = licenses.gpl2;

    longDescription = ''
      Wireshark (formerly known as "Ethereal") is a powerful network
      protocol analyzer developed by an international team of networking
      experts. It runs on UNIX, macOS and Windows.
    '';

    platforms = platforms.linux ++ platforms.darwin;
    maintainers = with maintainers; [ bjornfor fpletz ];
  };
};

wireshark-2_6  = common {
  version        = "2.6.12";
  sources-sha256 = "1mjb32iwdc15ixyqa78qqbwy4291i668db5w0v0rscarskgkvbc3";
};
wireshark-3_0  = common {
  version        = "3.0.7";
  sources-sha256 = "1wljg5z994r8zbjig52zlgp0b8lqbzdl1d6ysnw9hcvm2y82farv";
};
wireshark-3_2 = common {
  version        = "3.2.0";
  sources-sha256 = "0v5nn7i2nbqr59jsw8cs2052hr7xd96x1sa3480g8ks5kahk7zac";
};

in {
  wireshark-qt_2_6  = wireshark-2_6 { withQt = true;  };
  wireshark-cli_2_6 = wireshark-2_6 { withQt = false; };
  wireshark-qt_3_0  = wireshark-3_0 { withQt = true;  };
  wireshark-cli_3_0 = wireshark-3_0 { withQt = false; };
  wireshark-qt_3_2  = wireshark-3_2 { withQt = true;  };
  wireshark-cli_3_2 = wireshark-3_2 { withQt = false; };
}
