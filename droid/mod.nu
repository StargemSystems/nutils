# Android Workbench

use ../anvil *

const sdroot = '/sdcard' # '/storage/self/primary'

export-env {
  $env.DROID_BENCH = $env.DROID_BENCH? | default ($env.HOME | path join Android)
  let trg = $env.DROID_BENCH | path join device.yml
  $env.droid = (if ($trg | path exists) { open $trg } else {serial: null}) | merge {
    sdcard: ($env.DROID_BENCH | path join sdcard)
    assets: ($env.DROID_BENCH | path join assets)
    backup: ($env.DROID_BENCH | path join backup)
  }
}

alias ab = ^adb
alias fb = ^fastboot
alias sh = ^adb shell -t
alias am = ^adb shell -T am
alias pm = ^adb shell -T pm
alias su = ^adb shell -t su --preserve-environment

def dev_boot_slots [] { [ a b c ] } # 'c' is for current
def dev_boot_targs [] { [ bootloader recovery device sideload sideload-auto-reboot poweroff ] }
def wait_for_targs [] { [ bootloader recovery device sideload disconnect rescue ] }

# report a state of 'offline', 'bootloader', or 'device'
def get_state [] { list_devs | get 0?.1 | default 'offline' }
def _get_state [] { try { ^adb get-state e> (null-device) } catch { 'offline' } }

# report details of avalible devices
def list_devs [cell?: cell-path] {
  let fsb = try { ^fastboot devices -l e> (null-device) } | str squeeze | lines | each {split row (char sp)}
  let adb = try { ^adb devices -l e> (null-device) } | str squeeze | lines | tl | each {split row (char sp)}
  let res = $fsb | append $adb
  if ($cell | is-empty) { return $res } else { $res | get $cell }
}

# report product name and serial in either `adb` or `fastboot` mode
def prod_serl [] {
  if ((get_state) == 'fastboot') {
    [(^fastboot getvar product) (^fastboot getvar serialno)]
  } else {
    [(^adb shell getprop ro.product.name) (^adb shell getprop ro.serialno)]
  }
}

# block script until transport state is reached
export def wait-for [
  state?: string@wait_for_targs = 'device'
  --usb # listen over usb transport only
  --tcp # listen over net transport only
] {
  let tran = if $usb {'usb'} else if $tcp {'local'} else {'any'}
  [ wait-for $tran $state ] | str join '-' | ^adb $in e+o> (null-device)
}

# restart connected android device into mode
export def reboot [
  target?: string@dev_boot_targs = 'device'
  --slot: string@dev_boot_slots # select active partition slot (WIP!)
] {
  match (get_state) {
    'offline' => { failure 'device not avalible' },
    'fastboot' => { match $target {
      'bootloader' => { ^fastboot reboot bootloader },
      'device' => { ^fastboot reboot; return null },
      _ => { ^fastboot reboot; wait-for device },
    }}
  }
  if ($target == 'poweroff') { ^adb shell poweroff } else { ^adb reboot $target }
}

# only copy local files newer than or missing on remote
export def push [loc_src: path, rmt_dst: path = $sdroot] {
  adb push -z zstd --sync $loc_src $rmt_dst
}

# clobber files over remote destination
export def plow [loc_src: path, rmt_dst: path = $sdroot] {
  adb push -z zstd $loc_src $rmt_dst
}

# clone remote files with metadata
export def pull [rmt_src: path = $sdroot, loc_dst: path = ./.] {
  adb pull -z zstd -a $rmt_src $loc_dst
}

# mount primary sdcard locally
export def fuse [rmt_org: path = $sdroot, loc_trg?: path] {
  let loc_trg = $loc_trg | default $env.droid.sdcard
  mkdir $loc_trg
  adbfs -o rellinks -o modules=subdir -o ('subdir=' + $rmt_org) ($loc_trg | path expand)
  tree -L 2 $loc_trg
}
