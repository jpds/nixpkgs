{
  lib,
  buildGoModule,
  fetchFromGitHub,
  stdenv,
}:

let
  version = "7.13.1";

  concourse-src = fetchFromGitHub {
    owner = "concourse";
    repo = "concourse";
    rev = "v${version}";
    hash = "sha256-myvYACdTqnEb8aBpBeCA1qvcnF0lwYbSo6kMgSz7iiA=";
  };

  init = stdenv.mkDerivation (finalAttrs: {
    inherit version;
    pname = "concourse-init-bin";
    src = "${concourse-src}";

    buildPhase = ''
      runHook preBuild
      $CC $src/cmd/init/init.c -o cmd/init/init
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -m755 -D cmd/init/init $out/bin/init
      runHook postInstall
    '';
  });
in

buildGoModule rec {
  inherit version;

  pname = "concourse";
  src = concourse-src;

  vendorHash = "sha256-WC4uzTgvW15IumwmsWXXeiF5qagbeb5XWRaSjd1XLvA=";

  subPackages = [ "cmd/concourse" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/concourse/concourse.Version=${version}"
  ];

  doCheck = false;

  preBuild = ''
    install -m755 -D ${init}/bin/init $out/bin/init
  '';

  meta = with lib; {
    description = "container-based automation system written in Go";
    mainProgram = "concourse";
    homepage = "https://concourse-ci.org";
    license = licenses.asl20;
    maintainers = with maintainers; [
      jpds
    ];
  };
}
