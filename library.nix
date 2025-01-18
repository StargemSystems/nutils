{ lib, pkgs, ... }: let
  l = builtins // lib;
  t = lib.types;
  p = pkgs;

  runJSON = { name ? "json-data", deps ? [] }: cmds:
    l.importJSON (_runJSON name deps cmds);
  _runJSON = name: deps: cmds: p.runCommand name {
    nativeBuildInputs = [ p.jq p.jo p.ripgrep ] ++ deps;
  } cmds;

	# runNuCommand = name: attrs: script: p.runCommandWith {
  #   inherit name;
  #   stdenv = p.nuenv;
  #   derivationArgs = attrs;
  #   # runLocal = attrs.runLocal;
  # } script;

in {
  inherit runJSON;
}
