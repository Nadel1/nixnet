{ inputs', pkgs, experiment }:

let
  nixnet = inputs'.nixnet.legacyPackages;

  # --- parameters from JSON ---
  rateMbit = experiment.rateMbit;
  delayMs  = experiment.delayMs;
  lossPercent = experiment.lossPercent;
  congestion = experiment.congestion;
  implementation = experiment.implementation;
  download = experiment.download;
  outageDuration = if experiment?"outageDuration" then experiment.outageDuration else "0";
  outageAmount = if experiment?"outageAmount" then experiment.outageAmount else "0";
  outageType = if experiment?"outageType" then experiment.outageType else "None";
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
          exec = if implementation=="quiche" then "tokio-client --no-verify http://10.0.3.2:4433/${download} --cc-algorithm ${congestion} --logging-file client.csv" else "tokio-client --no-verify http://10.0.3.2:4433/10MB --cc-algorithm ${congestion} --logging-file client.csv";
          await = true;
        };
        scripts.outage={
          exec =
          if outageType=="None" then '' ''
          else 
          ''
            _PATH="" # clear path
            _PATH="/nix/store/ld6xfarvm9rbaikaaqys1bm1x01hy5h7-busybox-mini/bin:$_PATH"
            _PATH="/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin:$_PATH"
            _PATH="/nix/store/9ypz3flqsrl5xl495mm8h645gadjsxi1-coreutils-9.11/bin:$_PATH"
            _PATH="/nix/store/f8y3cn08mlw2cwjq05anf6sgkfyb0k8a-iproute2-7.0.0/bin:$_PATH"
            _PATH="/nix/store/fhscg4f05syxdy0ki4byxislvq66y73q-util-linux-minimal-2.42-bin/bin:$_PATH"
            _PATH="/nix/store/manhdgqn5ibvk81024rdigmm679xxw5l-jail/bin:$_PATH"
            export PATH="$_PATH"
            sleep 5
            echo "Outage!"
            ip link set eth1 down
            ip link set eth2 down
            sleep ${outageDuration}
            echo "Back up"
            ip link set eth1 up
            ip link set eth2 up

            '';
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
          + "--cc-algorithm ${congestion} " 
          + "--logging-file server.csv" else "tokio-server --listen 10.0.3.2:4433 "
          + "--root ./ "
          + "--cert ${inputs'.test-certs.packages.default}/cert.crt "
          + "--key ${inputs'.test-certs.packages.default}/cert.key "
          + "--cc-algorithm ${congestion} "
          + "--logging-file server.csv";
        scripts.outage= {
          exec =
          if outageType=="None" then '' ''
          else 
          ''
            _PATH="" # clear path
            _PATH="/nix/store/ld6xfarvm9rbaikaaqys1bm1x01hy5h7-busybox-mini/bin:$_PATH"
            _PATH="/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin:$_PATH"
            _PATH="/nix/store/9ypz3flqsrl5xl495mm8h645gadjsxi1-coreutils-9.11/bin:$_PATH"
            _PATH="/nix/store/f8y3cn08mlw2cwjq05anf6sgkfyb0k8a-iproute2-7.0.0/bin:$_PATH"
            _PATH="/nix/store/fhscg4f05syxdy0ki4byxislvq66y73q-util-linux-minimal-2.42-bin/bin:$_PATH"
            _PATH="/nix/store/manhdgqn5ibvk81024rdigmm679xxw5l-jail/bin:$_PATH"
            export PATH="$_PATH"
            sleep 5
            echo "Outage!"
            ip link set eth1 down
            ip link set eth2 down
            sleep ${outageDuration}
            echo "Back up"
            ip link set eth1 up
            ip link set eth2 up

            '';
          await = true;
        };

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