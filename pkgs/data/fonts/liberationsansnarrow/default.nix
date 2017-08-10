{stdenv, liberation_ttf_v1_from_source}:

stdenv.mkDerivation rec {
  name = builtins.replaceStrings ["liberation-fonts"] ["liberationsansnarrow"] liberation_ttf_v1_from_source.name;

  buildCommand = ''
    mkdir -p $out/share/fonts/truetype $out/share/doc/${name}
    cp ${liberation_ttf_v1_from_source}/share/fonts/truetype/*Narrow*.ttf $out/share/fonts/truetype/
    cp ${liberation_ttf_v1_from_source}/share/doc/*/*                     $out/share/doc/${name}
  '';

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "1jlvw2xx3impafc541416jiiaan19yi8rn4kxl8rgds2xj1iirp1";

  inherit (liberation_ttf_v1_from_source) meta;
}
