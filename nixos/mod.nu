#! /usr/bin/env nu
#|
#| NixOS Utilities

use ../anvil *

export const nixso = '/nix/store'
export const nixsw = '/run/current-system/sw'

export module nix {

  # pipe expression to nix with args for evaluation
  export def --wrapped eval [...argv] { $in | ^nix eval --file - ...$argv }

  # print the output paths of a nix derivation
  export def tree [query] { ^nix build $query --print-out-paths --no-link | tree $in }

}

use nix

# evaluate nix expression into nu data types
export def "from nix" [] { $in | nix eval --json | from json }

# generate nix expression from nu data types
export def "to nix" [] { $in | str enquote | nix eval --apply 'builtins.fromJSON' }

#|