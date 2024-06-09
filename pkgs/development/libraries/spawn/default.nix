{ lib
, stdenv
, fetchFromGitHub
, fetchpatch
, gprbuild
, gnat
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "spawn";
  version = "22.0.0";

  src = fetchFromGitHub {
    owner = "AdaCore";
    repo = "spawn";
    rev = "v${finalAttrs.version}";
    hash = "sha256-pDC3Ouoq4VHCx65QN9mz8if32pOncoaeKDaulKSTgjw=";
  };

  patches = [
    (fetchpatch {
      # https://github.com/AdaCore/spawn/pull/21
      name = "remove-unwanted-pragma-unreferenced.patch";
      url = "https://patch-diff.githubusercontent.com/raw/AdaCore/spawn/pull/21.patch";
      hash = "sha256-uRMkYNbs0nyfha4czxQvPLEtj/uhI+S0yQV0b/OJ7NM=";
    })
  ];

  nativeBuildInputs = [ gprbuild gnat ];

  buildPhase = ''
    make all
  '';

  installPhase = ''
    make install PREFIX=$out
  '';

  meta = with lib; {
    description = "";
    homepage = "https://github.com/AdaCore/spawn";
    license = licenses.asl20-llvm;
    maintainers = with maintainers; [ jpds ];
    platforms = platforms.unix;
  };
})
