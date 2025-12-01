(
  { lib, pkgs, ... }:

  {
    name = "parca";
    meta.maintainers = [ pkgs.lib.maintainers.jpds ];

    nodes = {
      agent =
        { config, pkgs, ... }:
        {
          systemd.services.parca-agent = {
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "simple";
              ExecStart = "${lib.getExe pkgs.parca-agent} --remote-store-address=parca:7070 --remote-store-insecure";
              User = "root";
              Group = "root";
              AmbientCapabilities = [
                "CAP_BPF"
                "CAP_SYS_ADMIN"
              ];
              Restart = "on-failure";
              RestartSec = 10;
            };
          };
        };

      parca =
        { config, pkgs, ... }:
        {
          networking.firewall.allowedTCPPorts = [ 7070 ];

          environment.systemPackages = [ pkgs.grpc-health-probe ];

          environment.etc."parca/parca.yaml".text = ''
            object_storage:
              bucket:
                type: "FILESYSTEM"
                config:
                  directory: "/var/lib/parca/"

            scrape_configs:
              - job_name: "parca"
                scrape_interval: "2s"
                static_configs:
                  - targets: ["127.0.0.1:7070"]
          '';

          systemd.services.parca = {
            wantedBy = [ "multi-user.target" ];
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              ExecStart = "${lib.getExe pkgs.parca} --config-path=/etc/parca/parca.yaml";
              User = "parca";
              Group = "parca";
              CapabilityBoundingSet = [ "" ];
              DevicePolicy = "closed";
              DynamicUser = true;
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
              ProcSubset = "pid";
              ProtectClock = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectControlGroups = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              ProtectSystem = "strict";
              Restart = "on-failure";
              RestartSec = 10;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              StateDirectory = "parca";
              SystemCallArchitectures = "native";
              SystemCallFilter = [
                "@system-service @resources"
                "~@privileged"
              ];
            };
          };
        };
    };

    testScript = ''
      parca.start()
      parca.wait_for_unit("parca")
      parca.wait_for_open_port(7070)

      parca.wait_until_succeeds(
        "journalctl -o cat -u parca.service --grep 'starting server'"
      )

      parca.wait_until_succeeds(
        "grpc-health-probe -addr localhost:7070"
      )

      agent.start()
      agent.wait_for_unit("parca-agent")

      agent.sleep(10)

      parca.log(parca.succeed(
        """
          curl http://localhost:7070/metrics | grep 'grpc_server_handled_total{grpc_code="OK",grpc_method="Upload",grpc_service="parca.debuginfo.v1alpha1.DebuginfoService",grpc_type="client_stream"}'
        """
      ))

      parca.log(parca.succeed(
        "systemd-analyze security parca.service | grep -v '✓'"
      ))

      agent.log(agent.succeed(
        "systemd-analyze security parca-agent.service | grep -v '✓'"
      ))
    '';
  }
)
