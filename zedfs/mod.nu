# Zed Filesystem

use ../anvil *

# Zed filesystem applet.
export alias zfs = doas zfs

# Zed dataset applet.
export alias zds = doas zpool

# Zed subvolume applet.
export alias zol = zfs subvolume

# ZedFs dataset and volume listings.
export def zls [...targs] {
  (zfs list -r -t all -o all ...$targs
  | detect columns | rename --block { str downcase })
}

# Either get or set zedfs properties.
export def zet [trg key val?] {
  if ($val == null) {
    try { zfs get -Ho value $key $trg e> (null-device)
    } catch { 'null' } | from json
  } else {
    let val = $val | to json --raw #| str trim -c '"'
    zfs set ($key + '=' + $val) $trg
  }
}

# ZedFs Unified Keyslot Storage

# get dedails of luks encrypted zedfs volume
# export def "zuks report" [] {}

# setup new luks encrypted zedfs volume
# export def "zuks create" [] {}

# decrypt luks encrypted zedfs volume
# export def "zuks unlock" [] {}
