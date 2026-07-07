{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixnet.url = "github:birneee/nixnet";
    test-certs.url = "github:Nadel1/test-certs";
    quiche.url = "git+https://github.com/Nadel1/quiche?ref=further-research-plateau";
  };

  outputs = inputs@{ flake-parts, ... }:
    let
      experimentDir = ./experiments;

      files = builtins.readDir experimentDir;

      configFiles =
        map (name: experimentDir + "/${name}")
          (builtins.filter
            (name:
              files.${name} == "regular"
              && builtins.match ".*\\.json" name != null)
            (builtins.attrNames files));

      experiments =
        builtins.concatLists (
          map
            (file:
              (builtins.fromJSON (builtins.readFile file)).experiments)
            configFiles
        );

      singleOutageSteadyExperiments =
        (builtins.fromJSON
          (builtins.readFile ./experiments/single-outage-steady.json)).experiments;

    in
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = inputs.nixnet.supportedSystems;

      perSystem = { inputs', pkgs, ... }:

        let
          buildExperiments = runName: exps:
          map (exp:
            let
              built = (import ./experiment.nix {
                inherit inputs' pkgs;
                experiment = exp;
                workDir = "out/{run}";
              }).default;
            in {
              name = exp.name;
              path = built;
            }
          ) exps;


        builtAllExperiments =
          buildExperiments "allExperiments" experiments;


        builtSingleOutageSteady =
          buildExperiments "singleOutageSteady" singleOutageSteadyExperiments;


          #outageNames = map (e: e.name) singleOutageSteadyExperiments;
#
          #builtSingleOutageSteady =
          #  builtins.filter
          #    (e: builtins.elem e.name outageNames)
          #    perExperiment;

        in {

          packages.default =
            pkgs.runCommand "all-experiments" {} ''
              mkdir -p $out

              ${builtins.concatStringsSep "\n" (map (e: ''
                mkdir -p $out/${e.name}
                cp -r ${e.path}/* $out/${e.name}/
              '') builtAllExperiments)}
            '';
          # gather the outage experiments into one numbered subfolder
          packages.singleOutageSteadyExperiments =
            pkgs.writeShellScriptBin "singleOutageSteadyExperiments" ''
              set -euo pipefail

              i=0
              while [ -e "out/runOutages$i" ]; do
                i=$((i+1))
              done

              mkdir -p "out/runOutages$i"

              echo "Results will be stored in out/runOutages$i"

              cd "out/runOutages$i"

              ${builtins.concatStringsSep "\n" (map (e: ''
                echo "Running ${e.name}"
                "${e.path}/bin/testbed"
              '') builtSingleOutageSteady)}
            '';
        };
    };
}