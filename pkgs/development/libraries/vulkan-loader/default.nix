{ stdenv, fetchFromGitHub, cmake, python3, vulkan-headers, pkgconfig
, xlibsWrapper, libxcb, libXrandr, libXext, wayland, addOpenGLRunpath }:

let
  version = "1.1.114.0";
in

assert version == vulkan-headers.version;
stdenv.mkDerivation rec {
  pname = "vulkan-loader";
  inherit version;

  src = fetchFromGitHub {
    owner = "KhronosGroup";
    repo = "Vulkan-Loader";
    rev = "sdk-${version}";
    sha256 = "08nibkbjf3g32qyp5bpdvj7i0zdv5ds1n5y52z8pvyzkpiz7s6ww";
  };

  nativeBuildInputs = [ pkgconfig addOpenGLRunpath ];
  buildInputs = [ cmake python3 xlibsWrapper libxcb libXrandr libXext wayland ];
  enableParallelBuilding = true;

  cmakeFlags = [
    "-DSYSCONFDIR=${addOpenGLRunpath.driverLink}/share"
    "-DVULKAN_HEADERS_INSTALL_DIR=${vulkan-headers}"
  ];

  outputs = [ "out" "dev" ];

  # Set RUNPATH so that driver libraries in /run/opengl-driver(-32)/lib can be found.
  # See the explanation in addOpenGLRunpath.
  postFixup = ''
    addOpenGLRunpath $out/lib/libvulkan.so
  '';

  meta = with stdenv.lib; {
    description = "LunarG Vulkan loader";
    homepage    = https://www.lunarg.com;
    platforms   = platforms.linux;
    license     = licenses.asl20;
    maintainers = [ maintainers.ralith ];
  };
}
