import ./make-test-python.nix (
  { lib, pkgs, ... }:
  let
    # https://concourse-ci.org/concourse-generate-key.html
    session_signing_key =
      pkgs.runCommand "session-signing-key" { nativeBuildInputs = [ pkgs.concourse ]; }
        ''
          concourse generate-key -t rsa -f ./session_signing_key
          mkdir -p $out
          mv session_signing_key $out
        '';

    tsa_host_key = pkgs.runCommand "tsa-host-key" { nativeBuildInputs = [ pkgs.concourse ]; } ''
      concourse generate-key -t ssh -f ./tsa_host_key
      mkdir -p $out
      mv tsa_host_key tsa_host_key.pub $out
    '';

    worker_key = pkgs.runCommand "worker-key" { nativeBuildInputs = [ pkgs.concourse ]; } ''
      concourse generate-key -t ssh -f ./worker_key
      mkdir -p $out
      mv worker_key worker_key.pub $out
    '';
  in
  {
    name = "concourse";
    meta.maintainers = with lib.maintainers; [ jpds ];

    nodes = {
      fly = {
        environment.systemPackages = [
          pkgs.fly
        ];
      };

      postgresql = {
        networking.firewall.allowedTCPPorts = [ 5432 ];

        services.postgresql = {
          enable = true;
          ensureDatabases = [ "concourse" ];
          enableTCPIP = true;
          authentication = pkgs.lib.mkOverride 10 ''
            #type database DBuser origin-address auth-method
            local all      all     trust
            # ... other auth rules ...

            # ipv4
            host  all      all     0.0.0.0/0   trust
            # ipv6
            host  all      all     ::/0        trust
          '';
          ensureUsers = [
            {
              name = "concourse";
              ensureDBOwnership = true;
            }
          ];
        };
      };

      web =
        { pkgs, ... }:
        {
          networking.firewall.allowedTCPPorts = [
            2222
            8080
          ];

          systemd.services.concourse-web = {
            after = [ "network-online.target" ];
            requires = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Environment = [
                "CONCOURSE_ADD_LOCAL_USER=test:test"
                "CONCOURSE_CLUSTER_NAME=tutorial"
                "CONCOURSE_EXTERNAL_URL=http://web:8080"
                "CONCOURSE_MAIN_TEAM_LOCAL_USER=test"
                "CONCOURSE_POSTGRES_DATABASE=concourse"
                "CONCOURSE_POSTGRES_HOST=postgresql"
                "CONCOURSE_POSTGRES_PASSWORD=concourse"
                "CONCOURSE_POSTGRES_USER=concourse"
                "CONCOURSE_SESSION_SIGNING_KEY=${session_signing_key}/session_signing_key"
                "CONCOURSE_TSA_AUTHORIZED_KEYS=${worker_key}/worker_key.pub"
                "CONCOURSE_TSA_HOST_KEY=${tsa_host_key}/tsa_host_key"
              ];
              ExecStart = ''
                ${pkgs.concourse}/bin/concourse web
              '';
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        };

      worker =
        { pkgs, ... }:
        {
          systemd.services.concourse-worker = {
            after = [ "network-online.target" ];
            requires = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            path = [
              pkgs.containerd
              pkgs.iptables
            ];

            serviceConfig = {
              Environment = [
                "CONCOURSE_TSA_HOST=web:2222"
                "CONCOURSE_TSA_PUBLIC_KEY=${tsa_host_key}/tsa_host_key.pub"
                "CONCOURSE_TSA_WORKER_PRIVATE_KEY=${worker_key}/worker_key"
                "CONCOURSE_RUNTIME=containerd"
                "CONCOURSE_WORKER_BAGGAGECLAIM_DRIVER=overlay"
              ];
              ExecStart = ''
                ${pkgs.concourse}/bin/concourse worker --work-dir /tmp
              '';
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        };
    };

    testScript = ''
      postgresql.wait_for_unit("postgresql.service")

      web.wait_for_unit("concourse-web.service")
      web.wait_for_open_port(2222)
      web.wait_for_open_port(8080)

      worker.wait_for_unit("concourse-worker.service")
      worker.wait_for_open_port(7777)
      worker.wait_for_open_port(7788)
      worker.wait_until_succeeds("journalctl -o cat -u concourse-worker.service | grep 'containerd successfully booted'")

      web.wait_until_succeeds("journalctl -o cat -u concourse-web.service | grep 'register.done'")

      fly.systemctl("start network-online.target")
      fly.wait_for_unit("network-online.target")

      # fly.wait_until_succeeds("fly --target tutorial login --concourse-url=http://web:8080 --username=test --password=test")
      # fly.wait_until_succeeds("fly --target tutorial status")
    '';
  }
)
