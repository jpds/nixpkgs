{ config, pkgs, lib, ... }:

with lib;

let cfg = config.services.prometheus.exporters.systemd;

in {
  port = 9558;

  extraOpts = {
    package = mkOption {
      type = types.package;
      default = pkgs.prometheus-systemd-exporter;
      defaultText = literalExpression "pkgs.prometheus-systemd-exporter";
      example = literalExpression "pkgs.prometheus-systemd-exporter";
      description = lib.mdDoc ''
        The package to use for prometheus-systemd-exporter
      '';
    };
  };
  serviceOpts = {
    serviceConfig = {
      ExecStart = ''
        ${pkgs.prometheus-systemd-exporter}/bin/systemd_exporter \
          --web.listen-address ${cfg.listenAddress}:${toString cfg.port} ${concatStringsSep " " cfg.extraFlags}
      '';
      RestrictAddressFamilies = [
        # Need AF_UNIX to collect data
        "AF_UNIX"
      ];
    };
  };
}
