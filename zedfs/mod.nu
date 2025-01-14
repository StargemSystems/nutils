# Zed Filesystem

use ../anvil *

# filesystem applet
export alias zfs = doas zfs

# dataset applet
export alias zds = doas zpool

# subvolume applet
export alias zol = zfs subvolume

# dataset and volume listing
export def zls [...targs] {
  (zfs list -r -t all -o all ...$targs
  | detect columns | rename --block { str downcase })
}

# get and set zedfs properties
export def zet [trg key val?] {
  if ($val == null) {
    try { zfs get -Ho value $key $trg e> (null-device)
    } catch { 'null' } | from json
  } else {
    let val = $val | to json --raw #| str trim -c '"'
    zfs set ($key + '=' + $val) $trg
  }
}

# export def "zuks report" [] {}
# export def "zuks create" [] {}
# export def "zuks unlock" [] {}
