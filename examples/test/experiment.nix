{ inputs', pkgs, experiment }:

let
  nixnet = inputs'.nixnet.legacyPackages;

  # --- parameters from JSON ---
  rateMbit = experiment.rateMbit;
  delayMs  = experiment.delayMs;
  lossPercent = experiment.lossPercent;
  congestion = experiment.congestion;
  implementation = experiment.implementation;

  config = {

    arp = false;
    arpPrefill = true;

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
            addresses = [{
              address = "10.0.1.1";
              prefixLength = 24;
            }];

            routes = [{
              address = "10.0.3.0";
              prefixLength = 24;
              via = "10.0.1.2";
              options.metric = "100";
            }];
          };

          eth2.ipv4 = {
            addresses = [{
              address = "10.0.2.1";
              prefixLength = 24;
            }];

            routes = [{
              address = "10.0.3.0";
              prefixLength = 24;
              via = "10.0.2.2";
              options.metric = "200";
            }];
          };
        };

        scripts.main = {
          exec = if implementation=="quiche" then "tokio-client --no-verify http://10.0.3.2:4433/10MB --cc-algorithm ${congestion}" else "tokio-client --no-verify http://10.0.3.2:4433/10MB --cc-algorithm ${congestion}";
          await = true;
        };

        workDir = "./client";
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

        scripts.main.exec =
        if implementation=="quiche" then "tokio-server --listen 10.0.3.2:4433 "
          + "--root ./ "
          + "--cert ${inputs'.test-certs.packages.default}/cert.crt "
          + "--key ${inputs'.test-certs.packages.default}/cert.key "
          + "--cc-algorithm ${congestion}" else "tokio-server --listen 10.0.3.2:4433 "
          + "--root ./ "
          + "--cert ${inputs'.test-certs.packages.default}/cert.crt "
          + "--key ${inputs'.test-certs.packages.default}/cert.key "
          + "--cc-algorithm ${congestion}";

        workDir = "./server";
      };
    };

    veths.eth1 = {
      arpPrefill = true;
      arp = false;
      mtu = 1500;

      netem = {
        rateMbit = rateMbit;
        delayMs = delayMs;
        autoLimit = true;
        lossPercent = lossPercent;
      };

      a.node = "client";
      b.node = "server";
    };

    veths.eth2 = {
      arpPrefill = true;
      arp = false;
      mtu = 1500;

      netem = {
        rateMbit = rateMbit;
        delayMs = delayMs;
        autoLimit = true;
        lossPercent = lossPercent;
      };

      a.node = "client";
      b.node = "server";
    };
  };

in
{
  # main experiment output
  default = nixnet.mkExperiment config;

  # optional visualizations
  mermaid = nixnet.mkMermaid config;
  mermaid-svg = nixnet.mkMermaidSvg config;
}