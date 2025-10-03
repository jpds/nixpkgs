{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  meshcore,
  nix-update-script,
  prompt-toolkit,
  pythonOlder,
  requests,
}:

buildPythonPackage rec {
  pname = "meshcore-cli";
  version = "1.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "meshcore-dev";
    repo = "meshcore-cli";
    rev = "v${version}";
    hash = "sha256-Vs7/vbyY+RJ4Uwa5XZeF9KlkRhDIzyV37xsuHfxWAo4=";
  };

  disabled = pythonOlder "3.10";

  build-system = [
    hatchling
  ];

  dependencies = [
    meshcore
    prompt-toolkit
    requests
  ];

  pythonImportsCheck = [
    "meshcore_cli"
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Command line interface to MeshCore node";
    homepage = "https://github.com/meshcore-dev/meshcore-cli";
    changelog = "https://github.com/meshcore-dev/meshcore-cli/releases/tag/${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      jpds
    ];
  };
}
