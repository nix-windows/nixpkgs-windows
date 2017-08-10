{ stdenv, fetchurl, fontforge, libfaketime }:

stdenv.mkDerivation rec {
  name = "linux-libertine-5.3.0";

  src = fetchurl {
    url = mirror://sourceforge/linuxlibertine/5.3.0/LinLibertineSRC_5.3.0_2012_07_02.tgz;
    sha256 = "0x7cz6hvhpil1rh03rax9zsfzm54bh7r4bbrq8rz673gl9h47v0v";
  };

  setSourceRoot = "sourceRoot=`pwd`";

  nativeBuildInputs = [ fontforge ];

  buildPhase = ''
    for i in *.sfd; do
      fontforge -lang=ff -c \
        'Open($1);
        ScaleToEm(1000);
        Reencode("unicode");
        Generate($1:r + ".ttf");
        Generate($1:r + ".otf");
        Reencode("TeX-Base-Encoding");
        Generate($1:r + ".afm");
        Generate($1:r + ".pfm");
        Generate($1:r + ".pfb");
        Generate($1:r + ".map");
        Generate($1:r + ".enc");
        ' $i;
    done
    #sed -i 's#^%%CreationDate: ... ... .. ..:..:.. ....$#%%CreationDate: Thu Jan  1 00:00:01 1970#' *.pfb *.map *.enc
    # mitigate difference between "Nix build user 2" and "Nix build user 4"
    sed -i 's#^%%Creator: Nix build user.+$#%%Creator: Nix build user#' *.pfb *.map *.enc
    #sed -i 's#^% Generated by FontForge .+$#% Generated by FontForge#'                              *.pfb *.map *.enc
  '';

  installPhase = ''
    mkdir -p $out/share/fonts/{opentype,truetype,type1}/public
    mkdir -p $out/share/texmf/fonts/{enc,map}
    cp *.otf $out/share/fonts/opentype/public
    cp *.ttf $out/share/fonts/truetype/public
    cp *.pfb $out/share/fonts/type1/public
    cp *.enc $out/share/texmf/fonts/enc
    cp *.map $out/share/texmf/fonts/map
  '';

  LD_PRELOAD = "${libfaketime}/lib/libfaketime.so.1";
  FAKETIME = "1970-01-01 00:00:01";
#output path ‘/nix/store/w7h2n05axysw6jn6l6y7xglfswfs8rif-linux-libertine-5.3.0’ has r:sha256 hash ‘sha256:1y9kvs2nbypp65qc5g21fnrhrjhc40sxkvxcgdx0kn8v3ckxls9w’ when 
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "1y9kvs2nbypp65qc5g21fnrhrjhc40sxkvxcgdx0kn8v3ckxls9w";

  meta = {
    description = "Linux Libertine Fonts";
    homepage = http://linuxlibertine.sf.net;
    platforms = stdenv.lib.platforms.all;
  };
}
