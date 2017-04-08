{ stdenv, fetchzip, ocaml, opam }:

stdenv.mkDerivation {
  name = "jbuilder-1.0+beta6";
  src = fetchzip {
    url = http://github.com/janestreet/jbuilder/archive/1.0+beta6.tar.gz;
    sha256 = "0fq8lqqfax4p2bd5rlwg6m2h4gc8hjph2hgb7azf1wlp10rqja9n";
  };

  buildInputs = [ ocaml ];

  installPhase = "${opam}/bin/opam-installer -i --prefix=$out --libdir=$OCAMLFIND_DESTDIR";

  preFixup = "rm -rf $out/jbuilder";

  meta = {
    homepage = https://github.com/janestreet/jbuilder;
    description = "Fast, portable and opinionated build system";
    maintainers = [ stdenv.lib.maintainers.vbgl ];
    license = stdenv.lib.licenses.asl20;
    inherit (ocaml.meta) platforms;
  };
}
