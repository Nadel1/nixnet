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
          # Build every experiment exactly once
          perExperiment =
            map (exp:
              let
                built = (import ./experiment.nix {
                  inherit inputs' pkgs;
                  experiment = exp;
                }).default;
              in {
                name = exp.name;
                path = built;
              })
            experiments;

          outageNames = map (e: e.name) singleOutageSteadyExperiments;

          builtSingleOutageSteady =
            builtins.filter
              (e: builtins.elem e.name outageNames)
              perExperiment;

        in {

          packages.default =
            pkgs.runCommand "all-experiments" {} ''
              mkdir -p $out

              ${builtins.concatStringsSep "\n" (map (e: ''
                mkdir -p $out/${e.name}
                cp -r ${e.path}/* $out/${e.name}/
              '') perExperiment)}
            '';

          packages.singleOutageSteadyExperiments =
            pkgs.writeShellScriptBin "run-single-outage-steady" ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail

              ${builtins.concatStringsSep "\n" (map (e: ''
                echo "=================================="
                echo "Running ${e.name}"
                echo "=================================="

                "${e.path}/bin/testbed"
              '') builtSingleOutageSteady)}
            '';
        };
    };
}