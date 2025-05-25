{ pkgs, ... }:

{
  name = "prometheus-hammer";
  globalTimeout = 24 * 60 * 60;

  nodes = {
    prometheus1 =
      { config, pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.jq ];

        networking.firewall.allowedTCPPorts = [ config.services.prometheus.port ];

        services.prometheus = {
          enable = true;
          package = pkgs.prometheus.override { raceDetection = true; };
          globalConfig.scrape_interval = "2s";
          scrapeConfigs = [
            {
              job_name = "prometheus";
              static_configs = [
                {
                  targets = [
                    "prometheus1:${toString config.services.prometheus.port}"
                    "prometheus2:${toString config.services.prometheus.port}"
                  ];
                }
              ];
            }
          ];
        };
      };

    prometheus2 =
      { config, pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.jq ];

        networking.firewall.allowedTCPPorts = [ config.services.prometheus.port ];

        services.prometheus = {
          enable = true;
          package = pkgs.prometheus.override { raceDetection = true; };
          globalConfig.scrape_interval = "2s";
          scrapeConfigs = [
            {
              job_name = "prometheus";
              static_configs = [
                {
                  targets = [
                    "prometheus1:${toString config.services.prometheus.port}"
                    "prometheus2:${toString config.services.prometheus.port}"
                  ];
                }
              ];
            }
          ];
        };
      };
  };

  testScript = ''
    for machine in prometheus1, prometheus2:
      machine.wait_for_unit("prometheus")
      machine.wait_for_open_port(9090)
      machine.wait_until_succeeds("journalctl -o cat -u prometheus.service | grep 'version=${pkgs.prometheus.version}'")
      machine.wait_until_succeeds("curl -sSf http://localhost:9090/-/healthy")

    # Prometheii ready - keep running until an error is encountered
    while True:
      prometheus1.fail("journalctl -o cat -u prometheus.service | grep 'level=ERROR'")
      prometheus2.fail("journalctl -o cat -u prometheus.service | grep 'level=ERROR'")
      prometheus1.sleep(30)
  '';
}
