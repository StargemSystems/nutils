{
  description = "NuShell Utility Library";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  # inputs.hackit.url = "github:StargemSystems/hackit";

  outputs = inputs@{...}:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    # imports = [ ];

    perSystem = toplevel@{ config, self', inputs', pkgs, system, ... }: {
      # _module.args.pkgs = import inputs.hackit.inputs.nixpkgs { inherit system; };

      packages.default = config.packages.nutils;
      packages.nushell = pkgs.nushell;

      packages.nutils = pkgs.stdenv.mkDerivation rec {
        src = ./.;
        pname = "nutils";
        version = "0.7.0";
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/share/nushell
          cp -r $src $out/share/nushell/nutils

          # trg="$out/share/nushell/nutils"
          # mkdir -p $trg
          # cp $scr/mod.nu $trg
          # cp -r $scr/anvil $trg
          # cp -r $scr/droid $trg
          # cp -r $scr/gnupg $trg
          # cp -r $scr/nixos $trg
          # cp -r $scr/regex $trg
          # cp -r $scr/zedfs $trg
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