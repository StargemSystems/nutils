{
  description = "Nu Shell Utility Library";

  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs@{...}:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    imports = [ ];

    perSystem = toplevel@{ config, self', inputs', pkgs, system, ... }: {
      packages.default = config.packages.nutils;
      # packages.oilshell = pkgs.oils-for-unix;
      packages.nushell = pkgs.nushell;

      packages.nutils = pkgs.runCommand "nutils" {} ''
        mkdir $out/usr/share/nushell/nutils
        cp -r ${./.} $out/usr/share/nushell/nutils
        rm $out/usr/share/nushell/nutils/flake.nix
      '';
    };
  };
}