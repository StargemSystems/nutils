#|

# mount a filesystem without needing an existing directory
export alias mnt = doas mount --mkdir

# unmount all filesystems at and under the target
export def ejc [...targs: path] {
  for trg in $targs {
    doas umount --quiet --recursive $trg
    rmdir $trg
  }
}

# report the serial idenifier of a block device
export def blkd-mark [dev: path] {
  if (($dev | path type) != 'block device') {
    failure 'not a block device' }
  ( lsblk -ndo vendor,model,serial $dev
  | str trim | str upcase
  | str replace -ar '[^[:alnum:]]' '_'
  | str replace -ar '[_]+' '_' )
}

# refine block device idenifier
export def blkd-serl [dev: path] {
  let mark = blkd-mark $dev
  let wwid = lsblk -ndo wwn $dev
  let uuid = nsidgen $mark
  let stub = $uuid | str substring (-7)..
  return {stub: $stub mark: $mark uuid: $uuid wwid: $wwid}
}

# locate mountpoint target with label
export def "mnt get-target" [label?: string] {
  let label = $in | default $label
  let found = findmnt -n --output target --source $label | str trim
  elif ($found | is-empty) null $found
}

# query if target is an active mountpoint
export def "mnt is-alive" [target?] {
  let targ = $in | default $target
  if ($targ | path expand) in (sys disks).mount { return true } else {
    mnt get-targ $targ | is-not-empty
  }
}

# applet for LUKSv2 sub-commands of cryptsetup
export def --wrapped luks [task: string ...argv] {
  doas cryptsetup --batch-mode --type=luks2 $"luks($task | str capitalize)" ...$argv
}

#|