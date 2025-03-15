{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,
  geopandas,
  pdm-backend,
  beautifulsoup4,
  click,
  duckdb,
  geoarrow-pyarrow,
  geoarrow-pandas,
  geopy,
  pooch,
  polars,
  psutil,
  pyarrow,
  requests,
  rich,
  typeguard,
  typer,
  tqdm,
}:

buildPythonPackage rec {
  pname = "quackosm";
  version = "0.13.0";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "kraina-ai";
    repo = "quackosm";
    rev = "refs/tags/${version}";
    hash = "sha256-Xm3VHK4dJQLTWmSadz/XnFHngLRJhANzYNPjs/pidZI=";
  };

  build-system = [ pdm-backend ];

  dependencies = [
    beautifulsoup4
    click
    duckdb
    geoarrow-pyarrow
    geoarrow-pandas
    geopandas
    geopy
    polars
    pooch
    psutil
    pyarrow
    requests
    rich
    tqdm
    typeguard
    typer
  ];

  pythonImportsCheck = [
    "quackosm"
  ];

  pytestCheckHook = true;

  meta = {
    description = "an open-source Python and CLI tool for reading OpenStreetMap PBF files using DuckDB";
    homepage = "https://kraina-ai.github.io/quackosm/";
    changelog = "https://github.com/kraina-ai/quackosm/releases/tag/${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      jpds
    ];
  };
}

