let
  pkgs = import <nixpkgs> {};
  config = builtins.fromJSON (builtins.readFile ./config.json);

  experiments = builtins.map (exp:
    {
      name = exp.name;
      drv = pkgs.callPackage ./hello.nix {
        name = exp.name;
        audience = exp.arg;
      };
    }
  ) config.experiments;

in
pkgs.runCommand "experiments" {} ''
  mkdir -p $out

  ${builtins.concatStringsSep "\n" (map (exp: ''
    mkdir -p $out/${exp.name}
    cp -r ${exp.drv}/* $out/${exp.name}/
  '') experiments)}
''