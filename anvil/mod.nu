# NuShell Anvil Utility Library

#====================================================#

export use std [null-device "path add"]

#| core.nu

# Print an error message and halt.
export def failure [message: string] { error make -u {msg: $message} }

# Given closure do it, otherwise return given value.
export def do-lazy [it? ...rest] {
  let it = $in | default $it
  if ($it | of-type closure) { do $it ...$rest } else { return $it }
}

# Simpler if-else statement for ergonomic use within variable bindings.
export def elif [cond: bool then: any else?: any] {
  if $cond { do-lazy $then } else { do-lazy $else }
}

# Dynamicly evaled values for defaults.
export def "default do" [func: closure] {
  let it = $in; if ($it | is-empty) { do $func } else { $it }
}

# Describe top level datatype, excluding any subtypes.
export def what-is [item: any = null] { $in | default $item | describe | str replace --regex '<.*' '' }

#| default.nu


#| filters.nu

# inverse of is-empty
export alias is-thing = is-not-empty

# return head of list
export def hd [list?] { $in | default $list | first }

# return tail of list
export def tl [list?] { $in | default $list | skip 1 }

# Assert pipe input is of given types.
export def of-type [...types] { ($in | what-is) in $types }

# Assert is empty or matches sample.
export def is-empty-or [match] { let it = $in; ($it | is-empty) or ($it =~ $match) }

# Enforce order of columns.
export def reorder [...headers] { $in | move ...(tl $headers) --after (hd $headers) }

# Flatten list and or unwrap singleton.
export def squish [...items] {
  let flat = $in | append $items | flatten deep -n
  if ($flat | length) == 1 { $flat | first } else { $flat }
}

# Fully flatten list of lists and values
export def "flatten deep" [
  ...rest # appended to input
  --strip-nulls(-n) # reject empty values
] {
  mut it = $in | append $rest
  while ($it | any {of-type list}) {$it = $it | flatten --all }
  if $strip_nulls { $it | where {is-thing} } else { return $it }
}

#| generators.nu

# Generate a namespaced v5 uuid.
export def nsidgen [
  seed?: string # value to generate id with
  --namespace(-n) = '@oid' # uuid to derive id from
] {
  let ns = if ($namespace | of-type binary) { $namespace | format uuid } else { $namespace }
  $in | default $seed | ^uuidgen --sha1 --namespace $ns --name $in | format uuid raw $in
}

#| transforms.nu

# Format uuid as binary
export def "format uuid raw" [uuid: string] {
  $uuid | str trim | str strip '-' | decode hex
  # match (what-is $uuid) {
    # string => { $uuid | str trim | str strip '-' | decode hex }
    # binary => { $uuid }
  # }
}

# Format uuid as string
export def "format uuid str" [uuid: binary] {
  let x = ($uuid | encode hex --lower | split chars
  | chunks 4 | par-each --keep-order {str join})
  $'($x.0)($x.1)-($x.2)-($x.3)-($x.4)-($x.5)($x.6)($x.7)'
  # match (what-is $uuid) {
  #   string => { $uuid }
  #   binary => {
  #     let x = ($uuid | encode hex --lower | split chars
  #     | chunks 4 | par-each --keep-order {str join})
  #     $'($x.0)($x.1)-($x.2)-($x.3)-($x.4)-($x.5)($x.6)($x.7)'
  #   }
  # }
}

# Transform uuid between raw binary and formatted string.
export def "format uuid" [uuid?] {
  let uuid = $in | default $uuid
  match (what-is $uuid) {
    string => { format uuid raw $uuid }
    binary => { format uuid str $uuid }
    # string => { $uuid | str trim | str strip '-' | decode hex }
    # binary => {
      # let x = ($uuid | encode hex --lower | split chars
      # | chunks 4 | par-each --keep-order {str join})
      # $'($x.0)($x.1)-($x.2)-($x.3)-($x.4)-($x.5)($x.6)($x.7)'
    # }
    $it => { error make {
      msg: $'invalid type `($it)` provided'
      help: 'try with a `binary` or `string` uuid' }
    }
  }
}

# Produce list with value flagged for use in command spread.
export def mk-flag [flag item?] {
  let cond = $in
  let flag = ('--' + $flag)
  let item = $item | default $cond
  if ($cond | is-empty) or ($cond == false) { return [] }
  if ($cond == true) and ($item == true) { return [$flag] }
  # if ($item | of-type closure) { $cond | do $item }
  return [$flag (do-lazy $item $cond)]
}

# Split string characters into chunck groups.
export def "split chunks" [
  ...takes: int # char length of each grouping
  --strict(-s) # discard ungrouped remainders
] {
  mut chars = $in | split chars
  [
    (for len in $takes {
      let it = $chars | take $len
      $chars = $chars | skip $len
      $it | str join
    })
    (if not ($strict) { $chars | str join })
  ] | flatten
}

#| formats.nu


#| strings.nu

# Conjoin list with newline chars.
export alias "str join nl" = str join (char newline)

# Conjoin list with space chars.
export alias "str join sp" = str join (char space)

# Better named alias for substring.
export def "str range" [span: range] { $in | str substring -b $span }

# Remove all of char from string.
export def "str strip" [char: string = ' '] { $in | str replace -a $char '' }

# Remove all regex matches from string.
export def "str purge" [expr: string] { $in | str replace -arm $expr '' }

# Replace repeating chars with a single one.
export def "str squeeze" [char: string = ' '] { $in | str replace -ar $'[($char)]+' $char }

# Escape all quotes for posix consumption.
export def "str enquote" [it?: any] { $in | default $it | to json -r | str replace -am '"' '\"' | $'"($in)"' }

# Append number with proper spoken ending.
export def "str nth-int" [
  it?: int # number to suffix
  --suffix-only(-s) # skip prepending number
] {
  let num = $in | default $it | into string
  let fix = match ($num | split chars | last | into int) {
    1 => { 'st' }
    2 => { 'nd' }
    3 => { 'rd' }
    _ => { 'th' }
  }
  if $suffix_only { $fix } else { $num ++ $fix }
}

#| platform.nu

# Reset and clear terminal.
export def --env clr [] { clear; reset }

# Silence all output from external commands.
export def --wrapped run-hushed [cmd: string ...optarg] {
  run-external $cmd ...$optarg e+o> (null-device)
}

# Prompt for user confirmation.
export def confirm [
  prompt: string # message to query with
  --invert(-i) # default to no insted of yes
  --failed(-f): string # cancellation message
] {
  let res = if $invert {
    (input -n 1 ($prompt + ' [N/y]: ')) =~ "n|N|\n"
  } else {
    (input -n 1 ($prompt + ' [Y/n]: ')) =~ "y|Y|\n"
  }
  if (($failed | is-thing) and (not $res)) {
    failure $failed
  } else { return $res }
}

#| system.nu

# Keep system awake while preforming a command.
export def --wrapped wake-lock [
  ...commands # task to wake lock while executing
  --reason: string # why the system was wake locked
  --super # run wake lock with super user permission
] {
  let cmd = [
    (elif $super doas) systemd-inhibit
    --what=idle:sleep:handle-lid-switch
    --mode=block ...($reason | mk-flag why)
    -- ...$commands
  ] | filter {is-thing}
  run-external (hd $cmd) ...(tl $cmd)
}

#| shells.nu


#| random.nu

# Report random numbers available from `/dev/urandom`. Raise values below 2000 with rng-tools.
export def "random entropy" [] { open /proc/sys/kernel/random/entropy_avail | into int }

#| path.nu

# Flatten and join list into clean path.
export def "path flat-join" [
  ...segments # items to concatanate
] { $in | append $segments | flatten deep -n | path join }

#| hash.nu

# Produce BLAKE3 checksums.
export def "hash b3sum" [
  --derive(-d): string # use key derivation mode
  --length(-l): int = 32 # number of output bytes
  --seekto(-s): int = 0 # starting output byte offset
] {
  $in | ^b3sum --no-names --length $length --seek $seekto ...($derive | mk-flag derive-key)
}

#| date.nu

# Current or given datetime under utc timezone.
export def "date utc" [] { $in | default (date now) | date to-timezone UTC }

# Produce a sortable intiger timestamp.
export def "date stamp" [
  when?: datetime
  --precise(-p) # include micro seconds
  --hex(-x) # produce hexadecimal output
] {
  let fine = if $precise {'%3f'} else {''}
  let when = $in | default $when | default (date utc) | format date $"%Y%m%d%H%M%S($fine)" | into int
  if $hex { $when | format number | get upperhex | str range 2.. } else { $when }
}

#| misc.nu

# Dvorak typist practice program.
export alias dvorak-typist = ^gtypist --personal-best --scoring=cpm --max-error=2.0 --show-errors d.typ

#| network.nu

# Probe a network host for open ports.
export def open-port-scan [
  host: string = localhost # target network address
  ports: range = 1..65535 # range of ports to check
  --timeout(-t): string = 5m # stop after given duration
] {
  (^nmap -sT --open --host-timeout $timeout $host -p $"($ports | first)-($ports | last)"
  | str replace -a '/tcp' "" | lines -s | skip until {|| $in == 'PORT      STATE SERVICE' }
  | drop 1 | str join $"\n" | detect columns | reject STATE | into int PORT)
}

#| filesystem.nu

# Return known directory module entrypoint file.
def get-module-shim [file: path] {
  let item = $file | path parse
  let file = $file | path basename
  match $item.extension {
    nu => 'mod.nu'
    py => '__init__.py'
    nix => 'default.nix'
    _ => $file
  }
}

# Turn module file into directory module.
export def shim-module-file [
  file: path # target moved into self named directory
  shim?: string # entrypoint module file for language
] {
  let targ = $file | path parse
  let shim = $shim | default (get-module-shim $file)
  let base = $targ.parent | path join $targ.stem
  let dest = $base | path join $shim
  mkdir $base; mv $file $dest
}

# Simpler linking

export alias lnh = ^ln     # hard link
export alias lns = ^ln -s  # soft link
export alias lnr = ^ln -sr # rela link

# Create one or more directories.
export alias mkd = mkdir

# Create parent directory and touch file.
export def mkf [...items] {
  $in | append $items | par-each {|it|
    $it | path dirname | mkdir $in; touch $it
  }; ignore
}

# Create and enter directory.
export def --env mkcd [
  trg: path # target to create and enter
  --own: string # passed to chown
  --mod: string # passed to chmod
] {
  mkdir $trg
  if ($own | is-thing) { chown -R $own $trg }
  if ($mod | is-thing) { chmod -R $mod $trg }
  cd $trg
}

# Remove a symbolic link.
export alias rmln = str trim -r -c '/' | unlink

# Force remove anything and everything.
export alias rmrf = rm -prf

# Try to own and mod recursive file targets.
export def claim [
  ...targs
  --owner(-u): string
  --group(-g): string = 'nogroup'
  --perms(-p): string = 'a=,u=rwX'
] {
  let owner = $owner | default $env.USER
  let flg = [--quiet --recursive]
  let own = $flg | append $'($owner):($group)'
  let mod = $flg | append $perms
  for trg in $targs {
    try { chown ...$own $trg } catch { try { doas chown ...$own $trg } }
    try { chmod ...$mod $trg } catch { try { doas chmod ...$mod $trg } }
  }
}

# Run rsync with commonly used flags while staying awake.
export def --wrapped synchro [
  ...argv
  --super(-s) # run with super-user privlege
] {
  let inhibit = [ systemd-inhibit
    --why='Synchronization of file data and directory structure'
    --what=idle:sleep:handle-lid-switch --mode=block -- ]
  let optargs = [ rsync
    -ahvir --sparse --partial --append-verify
    --no-inc-recursive --progress --info=all4 ]
  let cmdline = (elif $super [doas]) | append $inhibit | append $optargs
  run-external ($cmdline | hd) ...($cmdline | tl) ...$argv
}

#| blockdev.nu

# Mount a filesystem without needing an existing directory.
export alias mnt = doas mount --mkdir

# Unmount all filesystems at and under the target.
export def ejc [...targets: path] {
  for trg in $targets {
    doas umount --quiet --recursive $trg
    doas rmdir $trg | ignore
  }
}

# Locate mountpoint target with label.
export def "mnt get-label" [label?: string] {
  let label = $in | default $label
  let found = findmnt -n --output target --source $label | str trim
  elif ($found | is-empty) null $found
}

# Query if target is an active mountpoint.
export def "mnt is-alive" [target?] {
  let targ = $in | default $target
  if ($targ | path expand) in (sys disks).mount { return true } else {
    mnt get-label $targ | is-not-empty
  }
}

# Report the serial idenifier of a block device.
export def "blkd serl" [dev: path] {
  if (($dev | path type) != 'block device') {
    failure 'not a block device' }
  (lsblk -ndo vendor,model,serial $dev
  | str trim | str upcase
  | str replace -ar (eggex '!alnum') '_'
  | str squeeze '_')
}

# Refine block device idenifier.
export def "blkd iden" [dev: path] {
  let serl = blkd serl $dev
  let guid = lsblk -ndo uuid $dev
  let wwid = lsblk -ndo wwn $dev
  let uuid = nsidgen $serl | format uuid
  let mark = $uuid | str range (-7)..
  return {mark: $mark serl: $serl uuid: $uuid guid: $guid wwid: $wwid}
}

# Applet for LUKSv2 sub-commands of cryptsetup.
export def --wrapped luks [task: string ...argv] {
  doas cryptsetup --batch-mode --type=luks2 $"luks($task | str capitalize)" ...$argv
}

#|