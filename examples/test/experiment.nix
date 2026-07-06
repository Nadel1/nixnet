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
  maxIdleTimeout=experiment.maxIdleTimeout;
  outageDuration = if experiment?"outageDuration" then experiment.outageDuration else "0";
  outageAmount = if experiment?"outageAmount" then experiment.outageAmount else "0";
  outageType = if experiment?"outageType" then experiment.outageType else "None";
  outagesConfig =
    (builtins.fromJSON (builtins.readFile ./outagesConfig.json));

  outageStart= if outageType=="steady" then outagesConfig.steady.${implementation}.${congestion}."delay-${toString delayMs}" else  outagesConfig.steady.${implementation}.${congestion}."delay-${toString delayMs}";

  config = {

  arp = false;
  arpPrefill = true;
  #testbedPackages = with pkgs; [ iputils bash coreutils iproute2 util-linuxMinimal busybox-mini];
  #testbedPackages = pkgs.lib.mkOptionDefault [ iputils bash coreutils iproute2 ];
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
          exec = if implementation=="quiche" then "tokio-client --no-verify http://10.0.3.2:4433/${download} "
          + "--cc-algorithm ${congestion} "
          + "--idle-timeout ${maxIdleTimeout} "
          + "--logging-file client.csv" 
          else "tokio-client --no-verify http://10.0.3.2:4433/10MB " 
          + "--cc-algorithm ${congestion} "
          + "--idle-timeout ${maxIdleTimeout} "
          + "--logging-file client.csv";
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
          + "--idle-timeout ${maxIdleTimeout} "
          + "--logging-file server.csv" else "tokio-server --listen 10.0.3.2:4433 "
          + "--root ./ "
          + "--idle-timeout ${maxIdleTimeout} "
          + "--cert ${inputs'.test-certs.packages.default}/cert.crt "
          + "--key ${inputs'.test-certs.packages.default}/cert.key "
          + "--cc-algorithm ${congestion} "
          + "--logging-file server.csv";

        workDir = "./server";
      };
    };

    scripts.main = {
      exec = 
        if outageType=="steady" then
        ''
        down() { ip netns exec "$1" ip link set "$2" down; }
        up()   { ip netns exec "$1" ip link set "$2" up; }
        outageStart=(${builtins.concatStringsSep " " (map toString outageStart)})

        for ((i=0; i<${toString outageAmount}; i++)); do
        sleep ''${outageStart[$i]}
        echo "Outage start"
        down client eth1
        down client eth2
        down server eth1
        down server eth2
        sleep ${outageDuration}
        echo "Outage end"
        up client eth1
        up client eth2
        up server eth1
        up server eth2
        _MAC=$(ip netns exec server cat /sys/class/net/eth1/address)
        ip -n client neigh add 10.0.1.2 lladdr "$_MAC" dev eth1
        ip -n client neigh add 10.0.3.2 lladdr "$_MAC" dev eth1
        _MAC=$(ip netns exec client cat /sys/class/net/eth1/address)
        ip -n server neigh add 10.0.1.1 lladdr "$_MAC" dev eth1
        _MAC=$(ip netns exec server cat /sys/class/net/eth2/address)
        ip -n client neigh add 10.0.2.2 lladdr "$_MAC" dev eth2
        ip -n client neigh add 10.0.3.2 lladdr "$_MAC" dev eth2
        _MAC=$(ip netns exec client cat /sys/class/net/eth2/address)
        ip -n server neigh add 10.0.2.1 lladdr "$_MAC" dev eth2

	      ip -n client route add 10.0.3.0/24 via 10.0.1.2 dev eth1 metric 100
	      ip -n client route add 10.0.3.0/24 via 10.0.2.2 dev eth2 metric 200
        done
      ''
        else '''';
      
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