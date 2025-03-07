{
  description = "NuShell Utility Library";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  # inputs.hackit.url = "github:StargemSystems/hackit";
  # inputs.nixpkgs.follows = "hackit";
  # inputs.flake-parts.follows = "hackit";

  outputs = inputs@{...}:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    perSystem = toplevel@{ config, self', inputs', pkgs, system, ... }: {
      packages.oil = pkgs.oils-for-unix;
      packages.nushell = pkgs.nushell;
      packages.scripts = pkgs.nu_scripts;
      packages.default = config.packages.nutils;
      packages.nutils = pkgs.stdenvNoCC.mkDerivation {
        src = ./.;
        pname = "nutils";
        version = "0.7.0";
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/share/nushell/{scripts,plugins,configs}
          touch $out/share/nushell/configs/{env,run}.nu

          mkdir $out/share/nushell/scripts/nutils
          cp -r $src/* ./
          rm ./*.nix
          rm ./flake.lock
          rm ./README.md
          mv ./* $out/share/nushell/scripts/nutils
          echo "example include: `nu -I $out/share/nushell/scripts --login`"
        '';
        meta = {
          license = pkgs.lib.licenses.mit;
          description = "NuShell utility toolkit and extended standard library";
          # maintainers = [ inputs.hackit.lib.maintainers.StargemSystems ]
        };
      };
    };
  };
}