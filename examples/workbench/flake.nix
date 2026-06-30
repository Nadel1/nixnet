{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixnet.url = "github:birneee/nixnet";
    test-certs.url = "github:Nadel1/test-certs";
    quiche.url = "git+https://github.com/Nadel1/quiche?ref=further-research-plateau";#has to look like this as quiche uses submodules
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixnet.supportedSystems;
      perSystem =
        { inputs', pkgs, ... }:
        let
          nixnet = inputs'.nixnet.legacyPackages;
          config = {
            arp = false;
            arpPrefill = true;
            #preRun = ''
            #  python3 ../../space_quic/workbench/analysis/setup.py ../../space_quic/workbench/network/experiments/1-2-1-rtt=1s-rate=3125000Bps-loss=0%-asymFactor=1-outageduration-0.json
            #'';
            nodePackages = with pkgs; [
              inputs'.quiche.packages.default
              coreutils
              iputils
            ];
            nodes = {
               client = {
                packages = with pkgs; [ iputils ];
                networking.interfaces = {
                  eth1.ipv4 = {
                    addresses = [
                      {
                        address = "10.0.1.1";
                        prefixLength = 24;
                      }
                    ];
                    routes = [
                      {
                        address = "10.0.3.0";
                        prefixLength = 24;
                        via = "10.0.1.2";
                        options.metric = "100";
                      }
                    ];
                  };
                  eth2.ipv4 = {
                    addresses = [
                      {
                        address = "10.0.2.1";
                        prefixLength = 24;
                      }
                    ];
                    routes = [
                      {
                        address = "10.0.3.0";
                        prefixLength = 24;
                        via = "10.0.2.2";
                        options.metric = "200";
                      }
                    ];
                  };
                };
                scripts.main = {
                  exec = "tokio-client --no-verify http://10.0.3.2:4433/README.md --cc-algorithm bbr2";# --logging-file /home/natia/uni/space_quic/workbench/runs/2026-06-24T15:52:53.419682-Bob-CR/quiche:1-2-1-rtt=1s-rate=3125000Bps-loss=0%-asymFactor=1-outageduration-0.json:client0:bbr2:run=0:baseline.csv --requests 1";
                  await= true;
                };
                workDir="./client";
              };
              server = {
                networking.interfaces = {
                  eth1.ipv4.addresses = [
                    {
                      address = "10.0.1.2";
                      prefixLength = 24;
                    }
                    {
                      address = "10.0.3.2";
                      prefixLength = 24;
                    }
                  ];
                  eth2.ipv4.addresses = [
                    {
                      address = "10.0.2.2";
                      prefixLength = 24;
                    }
                    {
                      address = "10.0.3.2";
                      prefixLength = 24;
                    }
                  ];
                };
             
                scripts.main.exec="tokio-server --listen 10.0.3.2:4433 --root ./ --cert  ${inputs'.test-certs.packages.default}/cert.crt --key ${inputs'.test-certs.packages.default}/cert.key --cc-algorithm bbr2";# --logging-file /home/natia/uni/space_quic/workbench/runs/2026-06-24T15:52:53.419682-Bob-CR/quiche:1-2-1-rtt=1s-rate=3125000Bps-loss=0%-asymFactor=1-outageduration-0.json:server0:bbr2:run=0:baseline.csv";
                  # --logging-file /home/natia/uni/space_quic/workbench/runs/2026-06-24T14:11:20.310501-Bob-CR/quinn:1-2-1-rtt=1s-rate=3125000Bps-loss=0%-asymFactor=1-outageduration-0.json:server0:bbr:run=0:baseline.csv";
                
                workDir="./server";
               };
            };

          

           veths.eth1 = {
              a.node = "client";
              b.node = "server";
            };
            veths.eth2 = {
              a.node = "client";
              b.node = "server";
            };
          };
        in
        {
          packages.default = nixnet.mkExperiment config;
          packages.mermaid = nixnet.mkMermaid config;
          packages.mermaid-svg = nixnet.mkMermaidSvg config;
        };
    };
}
