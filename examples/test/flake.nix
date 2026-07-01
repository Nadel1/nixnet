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

        packages =
          builtins.listToAttrs (map (exp: {
            name = exp.name;

            value =
              (import ./experiment.nix {
                inherit inputs' pkgs;
                experiment = exp;
              }).default;
          }) experiments);

      };
    };
}