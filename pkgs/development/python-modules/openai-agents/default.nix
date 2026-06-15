{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  griffelib,
  mcp,
  openai,
  pydantic,
  requests,
  types-requests,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "openai-agents";
  version = "0.17.5";
  pyproject = true;

  src = fetchPypi {
    inherit version;
    pname = "openai_agents";
    hash = "sha256-XdRpQ7mT4aaKeKzSVPxqAM8EVfw9zIAgeOomlksUJ4w=";
  };

  build-system = [
    hatchling
  ];

  dependencies = [
    griffelib
    mcp
    openai
    pydantic
    requests
    types-requests
    typing-extensions
  ];

  pythonImportsCheck = [
    "agents"
  ];

  meta = {
    changelog = "https://github.com/openai/openai-agents-python/releases/tag/${version}";
    homepage = "https://github.com/openai/openai-agents-python";
    description = "Lightweight, powerful framework for multi-agent workflows";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.bryanhonof ];
  };
}
