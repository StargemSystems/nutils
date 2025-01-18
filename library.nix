{ lib, pkgs, ... }: let
  l = builtins // lib;
  t = lib.types;

  runJSON = { name ? "json-data", deps ? [] }: cmds:
    l.importJSON (_runJSON name deps cmds);
  _runJSON = name: deps: cmds: p.runCommand name {
    nativeBuildInputs = [ p.jq p.jo p.ripgrep ] ++ deps;
  } cmds;

	fromNUON = file: l.fromJSON (l.readFile file);

in {
  inherit runJSON fromNUON;
}
