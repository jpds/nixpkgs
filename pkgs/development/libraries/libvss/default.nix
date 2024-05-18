{ lib
, stdenv
, fetchFromGitHub
, gprbuild
, gnat
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libvss";
  version = "24.0.0";

  src = fetchFromGitHub {
    owner = "AdaCore";
    repo = "VSS";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Tgu+0vlfgM6uZo5SwQk6nV67YCGI6VOOj32pHlOtjU0=";
  };

  nativeBuildInputs = [ gprbuild gnat ];

  buildPhase = ''
    make all
  '';

  installPhase = ''
    make install PREFIX=$out
  '';

  meta = with lib; {
    description = "High level string and text processing library";
    homepage = "https://github.com/AdaCore/VSS";
    changelog = "https://github.com/AdaCore/VSS/releases/tag/v${finalAttrs.version}";
    license = licenses.asl20-llvm;
    maintainers = with maintainers; [ jpds ];
    platforms = platforms.unix;
  };
})
