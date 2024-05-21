import ../make-test-python.nix ({ lib, pkgs, ... }:

# This test is modeled on the microservices mode found at
# https://grafana.com/docs/loki/latest/get-started/deployment-modes/

let
  inherit (lib) mkMerge maintainers;

  gossipPort = 7946;
  grpcPort = 9095;
  httpPort = 3100;

  s3 = {
    bucket = "loki-bucket";
    accessKey = "BKIKJAA5BMMU2RHO6IBB";
    secretKey = "V7f1CwQqAcwo80UEIJEjc5gVQUSSx5ohQ9GSrr12";
  };

  baseLokiConf = {
    networking.firewall.allowedTCPPorts = [ httpPort gossipPort grpcPort ];
    networking.firewall.allowedUDPPorts = [ gossipPort ];

    services.loki = {
      enable = true;

      configuration = {
        auth_enabled = false;

        memberlist = {
          randomize_node_name = false;
          join_members = [
            "compactor:${toString gossipPort}"
            "distributor:${toString gossipPort}"
            "indexgateway:${toString gossipPort}"
            "ingester:${toString gossipPort}"
            "querier:${toString gossipPort}"
            "queryfrontend:${toString gossipPort}"
            "queryscheduler:${toString gossipPort}"
            "ruler:${toString gossipPort}"
          ];
          bind_addr = [ "::" ];
          bind_port = gossipPort;
        };

        common = {
          ring = {
            kvstore = {
              store = "memberlist";
            };
          };

          replication_factor = 1;
          path_prefix = "/tmp/loki/";
        };

        schema_config = {
          configs = [{
            from = "2020-05-15";
            object_store = "aws";
            store = "tsdb";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];
        };

        storage_config = {
         tsdb_shipper = {
           active_index_directory = "/var/lib/loki/index";
           cache_location = "/var/lib/loki/index_cache";
          };

          aws = {
            insecure = true;
            endpoint = "http://minio:9000";
            region = "us-east-1";
            s3 = "s3://${s3.accessKey}:${s3.secretKey}@minio:9000/${s3.bucket}";
            s3forcepathstyle = true;
          };
        };
      };
    };
  };

  extraLokiConfs = {
    compactor = {
      services.loki.extraFlags = [ "-target=compactor" ];
    };

    distributor = {
      services.loki.extraFlags = [ "-target=distributor" ];
    };
    
    indexGateway = {
      services.loki.extraFlags = [ "-target=index-gateway" ];
    };

    ingester = {
      services.loki.extraFlags = [ "-target=ingester" ];
    };
    
    querier = {
      services.loki.extraFlags = [ "-target=querier" ];
      services.loki.configuration = {
        common = {
          compactor_address = "http://compactor:${toString httpPort}";
        };
      };
    };
    
    queryFrontend = {
      services.loki.extraFlags = [ "-target=query-frontend" ];
      services.loki.configuration = {
        common = {
          compactor_address = "http://compactor:${toString httpPort}";
        };
      };
    };
    
    queryScheduler = {
      services.loki.extraFlags = [ "-target=query-scheduler" ];
    };

    ruler = {
      services.loki.extraFlags = [ "-target=ruler" ];
      services.loki.configuration = {
        ruler = {
          enable_api = true;

          storage = {
            type = "local";
            local = {
              directory = "/tmp/rules";
            };
          };

          rule_path = "/tmp/scratch";

          ring = {
            kvstore = {
              store = "inmemory";
            };
          };
        };
      };
    };
  };

  lokiNodes = builtins.mapAttrs (_: val: mkMerge [ val baseLokiConf ]) extraLokiConfs;
in {
  name = "loki-ssd";

  meta = with maintainers; {
    maintainers = [ willibutz ];
  };

  nodes = {
    minio = { pkgs, ... }: {
      virtualisation.diskSize = 2 * 1024;
      networking.firewall.allowedTCPPorts = [ 9000 ];

      services.minio = {
        enable = true;
        inherit (s3) accessKey secretKey;
      };

      environment.systemPackages = [ pkgs.minio-client ];
    };

    inherit (lokiNodes) compactor distributor indexGateway ingester querier queryFrontend queryScheduler ruler;

    # Place logcli in a separate VM to emulate Grafana talking to read endpoint
    logcli = { ... }: {
      environment.systemPackages = [ pkgs.grafana-loki ];
    };

    vector = { ... }: {
      services.vector = {
        enable = true;
        journaldAccess = true;
        settings = {
          sources = {
            journald.type = "journald";
          };

          sinks = {
            loki = {
              type = "loki";
              inputs = [ "journald" ];
              endpoint = "http://distributor:${toString httpPort}";
              encoding = { codec = "json"; };
              out_of_order_action = "accept";

              labels.source = "journald";
            };
          };
        };
      };
    };
  };

  testScript = ''
    minio.wait_for_unit("minio")
    minio.wait_for_open_port(9000)
    minio.succeed(
      "mc config host add minio "
      + "http://localhost:9000 "
      + "${s3.accessKey} ${s3.secretKey} --api s3v4",
      "mc mb minio/${s3.bucket}",
    )

    # Bucket ready, start Loki VMs
    for machine in compactor, distributor, indexGateway, ingester, querier, queryFrontend, queryScheduler, ruler:
      machine.start()
      machine.wait_for_unit("loki")
      machine.wait_for_open_port(3100)
      #machine.wait_for_open_port(7946) # indexGateway doesn't have this
      machine.wait_for_open_port(9095)
      machine.succeed("curl http://localhost:${toString httpPort}/ready")
      machine.wait_until_succeeds(
        "journalctl -o cat -u loki.service | grep 'Loki started'"
      )

    vector.start()
    vector.wait_for_unit("vector")

    logcli.wait_until_succeeds(
        "${pkgs.grafana-loki}/bin/logcli --addr='http://queryFrontend:${toString httpPort}' query --no-labels '{source=\"journald\"}' | grep -q 'systemd'"
    )

    queryFrontend.wait_until_succeeds(
      "journalctl -o cat -u loki.service | grep 'executing query'"
    )
    querier.wait_until_succeeds(
      "journalctl -o cat -u loki.service | grep 'executing query'"
    )
  '';
})
