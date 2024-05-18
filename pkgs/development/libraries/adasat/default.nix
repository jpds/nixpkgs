{ lib
, stdenv
, fetchFromGitHub
#, e3-testsuite
, gprbuild
, gnat
, python3
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libadasat";
  version = "24.0.0";

  src = fetchFromGitHub {
    owner = "AdaCore";
    repo = "AdaSAT";
    rev = "v${finalAttrs.version}";
    hash = "sha256-CPYXMT53PRRDYY8zDirN3UqbUa1QOmzGjlPXyScnwxM=";
  };

  nativeBuildInputs = [ gprbuild gnat ];

  buildPhase = ''
    gprbuild -P adasat.gpr -p -XBUILD_MODE=dev
  '';

  installPhase = ''
    gprinstall -P adasat.gpr -p -XBUILD_MODE=dev --prefix=$out
  '';

#  doCheck = true;

#  nativeCheckInputs = [
#    e3-testsuite
#  ];

#  checkPhase = ''
#    ${python3.interpreter} testsuite/testsuite.py
#  '';

  meta = with lib; {
    description = "Implementation of a DPLL-based SAT solver in Ada";
    homepage = "https://github.com/AdaCore/AdaSAT";
    changelog = "https://github.com/AdaCore/AdaSAT/releases/tag/v${finalAttrs.version}";
    license = licenses.asl20-llvm;
    maintainers = with maintainers; [ jpds ];
    platforms = platforms.unix;
  };
})
