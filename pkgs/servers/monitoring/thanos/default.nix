{ lib
, buildGoModule
, fetchFromGitHub
, go
}:

buildGoModule rec {
  pname = "thanos";
  version = "0.32.4";

  src = fetchFromGitHub {
    owner = "thanos-io";
    repo = "thanos";
    rev = "refs/tags/v${version}";
    hash = "sha256-EahgFeBYcjj4app+/XkcC8T99TvnrasjrtRphLthl8c=";
  };

  vendorHash = "sha256-KM1TmTyi9gIHizL62MbzsmtJogI+oLuJ8K2lRb0MlpA=";

  doCheck = true;

  subPackages = "cmd/thanos";

  ldflags = let t = "github.com/prometheus/common/version"; in [
    "-X ${t}.Version=${version}"
    "-X ${t}.Revision=unknown"
    "-X ${t}.Branch=unknown"
    "-X ${t}.BuildUser=nix@nixpkgs"
    "-X ${t}.BuildDate=unknown"
    "-X ${t}.GoVersion=${lib.getVersion go}"
  ];

  meta = with lib; {
    description = "Highly available Prometheus setup with long term storage capabilities";
    homepage = "https://github.com/thanos-io/thanos";
    changelog = "https://github.com/thanos-io/thanos/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ basvandijk ];
  };
}
