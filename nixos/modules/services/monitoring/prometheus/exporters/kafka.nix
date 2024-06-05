{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus.exporters.kafka;
  inherit (lib)
    mkIf
    mkOption
    mkMerge
    types
    concatStringsSep
    ;
in {
  port = 8080;
  extraOpts = {
  };
  serviceOpts = mkMerge ([{
    serviceConfig = {
      ExecStart = ''
        ${pkgs.kminion}/bin/kminion
      '';
      RestartSec = "3s";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };
  }] ++ [
    (mkIf config.services.apache-kafka.enable {
      after = [ "apache-kafka.service" ];
      requires = [ "apache-kafka.service" ];
    })
  ]);
}
