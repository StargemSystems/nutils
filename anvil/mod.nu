# NuShell Anvil Utility Library

#====================================================#

export use std [null-device]

#| core.nu

# print an error message and halt
export def failure [message: string] { error make -u {msg: $message} }

# do closure otherwise return given value
export def do-lazy [it? ...rest] {
  let it = $in | default $it
  if ($it | of-type closure) { do $it ...$rest } else { return $it }
}

# simpler if-else statement for ergonomic use within variable bindings
export def elif [cond: bool then: any else?: any] {
  if $cond { do-lazy $then } else { do-lazy $else }
}

# dynamic evaled values for defaults
export def "default do" [func: closure] {
  let it = $in; if ($it | is-empty) { do $func } else { $it }
}

# describe top level datatype
export def what-is [item: any = null] { $in | default $item | describe | str replace --regex '<.*' '' }

#| default.nu


#| filters.nu

# inverse of is-empty
export alias is-thing = is-not-empty

# return head of list
export def hd [list?] { $in | default $list | first }

# return tail of list
export def tl [list?] { $in | default $list | skip 1 }

# assert pipe input is of given types
export def of-type [...types] { ($in | what-is) in $types }

# assert is empty or matches sample
export def is-empty-or [match] { let it = $in; ($it | is-empty) or ($it =~ $match) }

# enforce order of columns
export def reorder [...headers] { $in | move ...(tl $headers) --after (hd $headers) }

# flatten list and or unwrap singleton
export def squish [...items] {
  let flat = $in | append $items | flatten | where {is-thing}
  if ($flat | length) == 1 { $flat | first } else { $flat }
}

#| generators.nu

# generate a namespaced v5 uuid
export def nsidgen [
  seed?: string # value to generate id with
  --namespace(-s): string = '@oid' # uuid to derive id from
  --binary(-b) # return raw decoded representation
] {
  let id = $in | default $seed | ^uuidgen --sha1 --namespace $namespace --name $in | str trim
  elif $binary {$id | str strip '-' | decode hex} $id
}

#| transforms.nu

# produce list with value flagged for use in command spread
export def mk-flag [flag item?] {
  let cond = $in
  let flag = ('--' + $flag)
  let item = $item | default $cond
  if ($cond | is-empty) or ($cond == false) { return [] }
  if ($cond == true) and ($item == true) { return [$flag] }
  # if ($item | of-type closure) { $cond | do $item }
  return [$flag (do-lazy $item $cond)]
}

#| formats.nu


#| strings.nu

# conjoin list with newline chars
export alias "str join nl" = str join (char newline)

# conjoin list with space chars
export alias "str join sp" = str join (char space)

# remove all of char from string
export def "str strip" [char: string = ' '] { $in | str replace -a $char '' }

# remove regex match from string
export def "str purge" [expr: string] { $in | str replace -arm $expr '' }

# replace repeating chars with only one
export def "str squeeze" [char: string = ' '] { $in | str replace -ar $'[($char)]+' $char }

# escape all quotes then wrap in quotes for posix consumption
export def "str enquote" [it?: any] { $in | default $it | to json -r | str replace -am '"' '\"' | $'"($in)"' }

#| platform.nu

# reset and clear terminal
export def --env clr [] { clear; reset }

# silence all output from external commands
export def --wrapped run-hushed [cmd: string ...optarg] {
  run-external $cmd ...$optarg e+o> (null-device)
}

# prompt for confirmation
export def confirm [
  prompt: string # message to query with
  --invert(-i) # default to no insted of yes
] {
  if $invert {
    (input -n 1 ($prompt + ' [N/y]: ')) =~ "n|N|\n"
  } else {
    (input -n 1 ($prompt + ' [Y/n]: ')) =~ "y|Y|\n"
  }
}

#| system.nu

# keep system awake while preforming a command
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

# Report random numbers available from `/dev/urandom`. Raise values below 2000 with rng-tools
export def "random entropy" [] { open /proc/sys/kernel/random/entropy_avail | into int }

#| path.nu

# flatten and join list into clean path
export def "path flat-join" [
  ...segments # items to concatanate
  --expand(-x) # apply path expantion
] {
  let result = ($in | append $segments
  | flatten --all | where {is-not-empty} | path join)
  if $expand { $result | path expand } else { return $result }
}

#| hash.nu

# produce BLAKE3 checksums
export def "hash b3sum" [
  --derive(-d): string # use key derivation mode
  --length(-l): int = 32 # number of output bytes
  --seekto(-s): int = 0 # starting output byte offset
] {
  $in | ^b3sum --no-names --length $length --seek $seekto ...($derive | mk-flag derive-key)
}

#| date.nu

# current or given datetime under utc timezone
export def "date utc" [] { $in | default (date now) | date to-timezone UTC }

# produce a sortable intiger timestamp
export def "date stamp" [
  when?: datetime
  --precise(-p) # include micro seconds
  --hex(-x) # produce hexadecimal output
] {
  let fine = elif $precise '%3f' ''
  let when = $when | default (date utc) | format date ('%y%m%d%H%M%S' + $fine) | into int
  if $hex { $when | fmt | get upperhex | str substring 2.. } else { $when }
}

#| misc.nu

# Dvorak typist practice
export alias dvorak-typist = ^gtypist --personal-best --scoring=cpm --max-error=2.0 --show-errors d.typ

#| network.nu

# probe a network host for open ports
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

# return directory module entrypoint file
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

# turn module file into directory module
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

# simpler linking
export alias lnh = ^ln     # hard link
export alias lns = ^ln -s  # soft link
export alias lnr = ^ln -sr # rela link

# create one or more directories
export alias mkd = mkdir

# create parent directory and touch file
export def mkf [...items] { $in | append $items | par-each {|it| $it | path dirname | mkdir $in; touch $it }; ignore }

# create and enter directory
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

# remove a symbolic link
export alias rmln = str trim -r -c '/' | unlink

# force remove anything and everything
export alias rmrf = rm -prf

# own and mod recursive file targets
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

# Run rsync with commonly used flags while staying awake
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

# mount a filesystem without needing an existing directory
export alias mnt = doas mount --mkdir

# unmount all filesystems at and under the target
export def ejc [...targets: path] {
  for trg in $targets {
    doas umount --quiet --recursive $trg
    rmdir $trg
  }
}

# locate mountpoint target with label
export def "mnt get-label" [label?: string] {
  let label = $in | default $label
  let found = findmnt -n --output target --source $label | str trim
  elif ($found | is-empty) null $found
}

# query if target is an active mountpoint
export def "mnt is-alive" [target?] {
  let targ = $in | default $target
  if ($targ | path expand) in (sys disks).mount { return true } else {
    mnt get-label $targ | is-not-empty
  }
}

# report the serial idenifier of a block device
export def "blkd serl" [dev: path] {
  if (($dev | path type) != 'block device') {
    failure 'not a block device' }
  ( lsblk -ndo vendor,model,serial $dev
  | str trim | str upcase
  | str replace -ar '[^[:alnum:]]' '_'
  | str replace -ar '[_]+' '_' )
}

# refine block device idenifier
export def "blkd iden" [dev: path] {
  let serl = blkd serl $dev
  let guid = lsblk -ndo uuid $dev
  let wwid = lsblk -ndo wwn $dev
  let uuid = nsidgen $serl
  let mark = $uuid | str substring (-7)..
  return {mark: $mark serl: $serl uuid: $uuid guid: $guid wwid: $wwid}
}

# applet for LUKSv2 sub-commands of cryptsetup
export def --wrapped luks [task: string ...argv] {
  doas cryptsetup --batch-mode --type=luks2 $"luks($task | str capitalize)" ...$argv
}

#|