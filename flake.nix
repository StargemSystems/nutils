{
  description = "NuShell Utility Library";

  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.hackit.url = "github:StargemSystems/hackit";

  outputs = inputs@{...}:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    # imports = [ ];

    perSystem = toplevel@{ config, self', inputs', pkgs, system, ... }: {
      packages.default = config.packages.nutils;
      packages.nushell = pkgs.nushell;

      packages.nutils = pkgs.stdenv.mkDerivation rec {
        src = ./.;
        pname = "nutils";
        version = "0.7.0";
        dontBuild = true;
        installPhase = ''
          mkdir $out/share/nushell
          cp -r $src $out/share/nushell/nutils
          rm $out/share/nushell/nutils/flake.*
          rm $out/share/nushell/nutils/.gitignore
        '';
        meta = {
          description = "NuShell utility toolkit and standard library";
          # maintainers = [ inputs.hackit.lib.maintainers.StargemSystems ]
          license = pkgs.lib.licenses.mit;
        };
      };
    };
  };
}