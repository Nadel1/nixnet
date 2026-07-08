{ inputs', pkgs, experiment, workDir ? "out/{run}" }:

let
  nixnet = inputs'.nixnet.legacyPackages;

  # --- parameters from JSON ---
  name=experiment.name;
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
  carefulResume = if experiment?"carefulResume" then true else false;
  outagesConfig =
    (builtins.fromJSON (builtins.readFile ./outagesConfig.json));

  mkClientCmd = loggingName:
    if implementation == "quiche" then
      "tokio-client --no-verify http://10.0.3.2:4433/${download} "
      + "--cc-algorithm ${congestion} "
      + "--idle-timeout ${maxIdleTimeout} "
      + " --saved-params saved-params-client.csv "
      + "--logging-file ${loggingName}"
    else
      "tokio-client --no-verify http://10.0.3.2:4433/10MB "
      + "--cc-algorithm ${congestion} "
      + "--idle-timeout ${maxIdleTimeout} "
      + " --saved-params saved-params-client.csv "
      + "--logging-file ${loggingName}";

  mkServerCmd = loggingName:
    if implementation == "quiche" then
      "tokio-server --listen 10.0.3.2:4433 "
      + "--root ./ "
      + "--cert ${inputs'.test-certs.packages.default}/cert.crt "
      + "--key ${inputs'.test-certs.packages.default}/cert.key "
      + "--cc-algorithm ${congestion} "
      + "--idle-timeout ${maxIdleTimeout} "
      + " --saved-params saved-params-server.csv "
      + "--logging-file ${loggingName}"
    else
      "tokio-server --listen 10.0.3.2:4433 "
      + "--root ./ "
      + "--idle-timeout ${maxIdleTimeout} "
      + "--cert ${inputs'.test-certs.packages.default}/cert.crt "
      + "--key ${inputs'.test-certs.packages.default}/cert.key "
      + "--cc-algorithm ${congestion} "
      + " --saved-params saved-params-server.csv "
      + "--logging-file ${loggingName}";
  outageStart =
    if outageType == "none" then
      []
    else
      outagesConfig.${outageType}.${implementation}.${congestion}."delay-${toString delayMs}";
  config = {
  inherit workDir;
  arp = false;
  arpPrefill = true;
  nodePackages = with pkgs; [
      inputs'.quiche.packages.default
      coreutils
      iputils
    ];


    nodes = {

      client = {

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
          exec = 
          if carefulResume then 
            ''
              ${mkClientCmd "${name}-client-baseline.csv"} 
              CAREFUL_RESUME=true 
              ${mkClientCmd "${name}-client-cr.csv"}
            ''
          else
            ''
              ${mkClientCmd "${name}-client.csv"}
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
        if carefulResume then 
          ''
             ${mkServerCmd "${name}-server-baseline.csv"} 
             CAREFUL_RESUME=true 
             ${mkServerCmd "${name}-server-cr.csv"}
          ''
        else
          ''
            ${mkServerCmd "${name}-server.csv"}
          '';
        workDir = "./server";
      };
    };
    scripts.main = {
      exec = 
        if outageType!="none" then
        ''
        down() { jail enter "$1" ip link set "$2" down; }
        up()   { jail enter "$1" ip link set "$2" up; }
        outageStart=(${builtins.concatStringsSep " " (map toString outageStart)})

        for ((i=0; i<${toString outageAmount}; i++)); do
        sleep ''${outageStart[$i]}
        echo "Outage start"
        jail enter client echo $PATH
        jail enter server echo $PATH
        jail enter client ip link set eth1 down
        jail enter client ip link set eth2 down
        jail enter server ip link set eth1 down
        jail enter server ip link set eth2 down

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