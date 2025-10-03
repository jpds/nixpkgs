{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  meshcore,
  meshcore-cli,
}:

buildHomeAssistantComponent rec {
  owner = "meshcore-dev";
  domain = "meshcore";
  version = "2.1.5";

  src = fetchFromGitHub {
    owner = "meshcore-dev";
    repo = "meshcore-ha";
    tag = "v${version}";
    hash = "sha256-xoZlHIiCsJmYi/Gdq3OeZfoPsSDSYiRkUieTcwK7cTY=";
  };

  dependencies = [
    meshcore
    meshcore-cli
  ];

  meta = {
    changelog = "https://github.com/meshcore-dev/meshcore-ha/releases/tag/${src.tag}";
    description = "Home Assistant integration for monitoring and controlling MeshCore radio networks";
    homepage = "https://github.com/meshcore-dev/meshcore-ha";
    maintainers = with lib.maintainers; [ jpds ];
    license = lib.licenses.mit;
  };
}
