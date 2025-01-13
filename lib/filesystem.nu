
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

# simpler linking
export alias lnh = ^ln     # hard link
export alias lns = ^ln -s  # soft link
export alias lnr = ^ln -sr # rela link

# create one or more directories
export alias mkd = mkdir

# create parent directory and touch file
export def mkf [...items] { $items | par-each {|it| $it | path dirname | mkdir $in; touch $it }; ignore }

# remove a symbolic link
export alias rmln = str trim -r -c '/' | unlink

# force remove anything and everything
export alias rmrf = rm -prf

# own and mod recursive file targets
export def claim-as [user group mode ...targets] {
  try {
    chown -R $'($user):($group)' ...$targets
    chmod -R $mode ...$targets
  } catch {
    doas chown -R $'($user):($group)' ...$targets
    doas chmod -R $mode ...$targets
  }
}

# Run rsync with commonly used flags while staying awake
export def --wrapped synchro [
  ...argv
  --super(-s) # run with super-user privlege
] {
  let inhibit = [ systemd-inhibit
    --why='Synchronization of file data and directory structure'
    --what=idle:sleep:handle-lid-switch -- ]
  let optargs = [ rsync
    -ahvir --sparse --partial --append-verify
    --no-inc-recursive --progress --info=progress2 ]
  let cmdline = (elif $super [doas])| append $inhibit | append $optargs
  run-external ($cmdline | hd) ...($cmdline | tl) ...$argv
}
