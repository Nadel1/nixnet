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
      experiments =
        (builtins.fromJSON (builtins.readFile ./config.json)).experiments;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = inputs.nixnet.supportedSystems;

      perSystem = { inputs', pkgs, ... }: {

        packages.default =
            let
              experiments =
                (builtins.fromJSON (builtins.readFile ./config.json)).experiments;
         
              perExperiment = map (exp:
                let
                  built = (import ./experiment.nix {
                    inherit inputs' pkgs;
                    experiment = exp;
                  }).default;
                in
                {
                  name = exp.name;
                  path = built;
                }
              ) experiments;
            
            in
            pkgs.runCommand "all-experiments" {} ''
              mkdir -p $out
            
              ${builtins.concatStringsSep "\n" (map (e: ''
                mkdir -p $out/${e.name}
                cp -r ${e.path}/* $out/${e.name}/
              '') perExperiment)}
            '';
                };
    };
}