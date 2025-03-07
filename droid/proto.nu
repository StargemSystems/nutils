#! nu
#| droid bench tools

use ../anvil *

const tell_dbug = false
const tell_hush = false
const tell_lvls = [ dbug info okay warn fail ]
const tell_pfix = 'droid '

def tell_levels [] { $tell_lvls }
def tell [
  level?: string@tell_levels = 'none'
  message?: string
] {
  let pfix = $tell_pfix + $'[($level | str upcase)]: '
  let message = $message | default $in
  match $level {
    'dbug' | 5 => {if $tell_dbug {
      print ($pfix + $message)
    }}
    'info' | 4 => {if not $tell_hush {
      print ($pfix + $message)
    }}
    'okay' | 3 => {
      print ($pfix + $message)
    }
    'warn' | 2 => {
      print --stderr ($pfix + $message)
    }
    'fail' | 1 => {
      error make -u {msg: $message}
    }
  }
}

export-env {
  $env.droid = {}
  evaluate_bench
}

# prepare workbench for usage
def --env evaluate_bench [] {
  let bench = $env.DROID_BENCH | default $env.PWD
  let phone = $bench | path join phone.yml | default $env.DROID_PHONE | open | into record
  let sdcard = $bench + '/sdcard'
  let bucket = $bench + '/bucket'
  let recov = glob $'($bucket)/**/($phone.rom.recovery)-*.img' | last
  let dynam = {
    bench:$bench
    sdcard:$sdcard
    bucket:$bucket
    recovery:$recov
    ...$phone
  }; $env.droid = $dynam
}

####

export def main [] {
  # Android Workbench Toolkit
  echo 'droid bench tools'
}

####

def wait_targs [] { [ device recovery rescue sideload bootloader disconnect ] }
# sit around until a state is reached
export def wait [
  state?: string@wait_targs = 'device'
  --usb --tcp
] {
  let tran = if $usb {'usb'} else if $tcp {'local'} else {'any'}
  [ wait-for $tran $state ] | str join '-' | adb $in
}

def compile_reasons [] { [ install cmdline bg-dexopt speed-profile ] }
# force optimization all applications like after an OTA update
export def compilate [reason: string@compile_reasons = 'bg-dexopt'] {
  tell info $'optimizing a total of (package_list | length) applications with the profile ($reason)'
  adb shell -x pm compile -a -f --full -r $reason | pkg_progress --last-written=50 | ignore
  tell info 'begining background dexopt job'
  adb shell pm bg-dexopt-job
  tell info 'cleaning up art supplies'
  adb shell pm art cleanup
  tell okay 'the system has been optimized'
}

export alias ab = adb
export alias sh = adb shell
export alias am = adb shell am
export alias pm = adb shell pm
export alias su = adb shell su --preserve-environment
export alias fb = fastboot

#### Rebooting

def reboot_targs [] { [ bootloader recovery device poweroff sideload sideload-auto-reboot ] }

# check the boot status of device
export def state [] {
  let state = get_transport
  if ($state | is-empty) { return 'offline' }
  if $state.1 == 'fastboot' { return 'bootloader' }
  return $state.1
}

# reboot device into chosen state
export def bootup [target: string@reboot_targs] {
  let state = state
  if ($state == 'offline') { tell fail 'device is not avalible' }
  if ($state == $target) { tell info 'already booted into chosen mode'; return }
  let target = $target | str replace 'device' ''
  match $state {
    device|recovery => { adb reboot $target }
    bootloader => { fastboot reboot $target }
  }
}

#### Reporting

# report avalible devices from fastboot and adb
export def get_transport [] {
  let fb = fastboot devices -l | str squeeze | lines -s
  let ab = adb devices -l | str squeeze | lines -s | skip 1
  let it = $fb ++ $ab
  if ($it | not-empty) { $it | first | split row ' ' } else { [] }
}

# get prod and serl while in fastboot mode
export def fast_iden [] {
  let serl = (fastboot getvar serialno e>| split row -r '\s+' | get 1)
  let prod = (fastboot getvar product e>| split row -r '\s+' | get 1)
  [$prod $serl]
}

# report all installed package idenifiers
export def package_list [] { adb shell pm list packages -a e> /dev/null | lines }

# report progress when enumerating packages
export def --wrapped pkg_progress [...args] { $in | pv --progress --timer --discard --line-mode --bytes --size (package_list | length) ...$args }

# list all mounted sdcards
export def sdcards [] {
  let base = '/storage'
  (adb shell ls $base | lines | reverse
  | filter {$in !~ 'self|emulated'}
  | each {|it| $base | path join $it})
}

#### Recovery

# restart remote device into local recovery image
export def enter-recovery [] {
  bootup bootloader
  tell info 'sideload booting into local recovery image'
  fastboot boot $env.droid.recovery
  wait recovery
}

# burn recovery to both slots and optionally reboot into it
export def flash-recovery [] {
  bootup bootloader
  tell info 'flashing fresh recovery image to both slots'
  fastboot --slot=all flash recovery $env.droid.recovery
  bootup recovery
}

# sideload an ota zip package
export def slide [
  ota_zip: path
  --stand # do not reboot after operation
] {
  tell info 'entering sideload boot mode and waiting for it to show'
  tell warn 'you may have to start it from recovery'
  bootup sideload
  wait  sideload
  tell info $'sideloading the ota zip ($ota_zip | path basename)'
  adb sideload $ota_zip
  tell okay 'seems installing the package was successful'
  if not $stand { bootup recovery } else {
    tell warn 'it is usually recomended to reboot after sideload' }
}

#### Archiving

# archive remote sdcard data locally
export def backup-sdcard [] {
  let dest = $env.droid.bucket + '/sdcard-' + (date stamp)
  tell info $'creating backup at ($dest)'
  adb pull -a /sdcard $dest
  backup-dedupl
}

# continue previous unfinished operation
export def backup-resume [] {
  let prev = glob $'($env.droid.bucket)/sdcard-*' | sort | last
  let recv = $prev + '/sdcard'
  tell info $'resuming backup from ($prev)'
  try { ln -rs $prev $recv }
  adb pull -a /sdcard $prev
  unlink $recv
  backup-dedupl
}

# minimize size of archives by hard-linking
export def backup-dedupl [depth: int = 16] {
  let targs = glob ($env.droid.bucket + '/sdcard-*') | sort | reverse | take $depth
  rdfind -makehardlinks true -ignoreempty true ...$targs
}

#### Transfer

# only copy local files newer than or missing on remote
export def push [loc_src: path, rmt_dst = '/sdcard'] {
  adb push -z zstd --sync $loc_src $rmt_dst
}

# clobber files over remote destination
export def plow [loc_src: path, rmt_dst = '/sdcard'] {
  adb push -z zstd $loc_src $rmt_dst
}

# clone remote files with metadata
export def pull [rmt_src = '/sdcard', loc_dst: path = ./bucket] {
  adb pull -z zstd -a $rmt_src $loc_dst
}

# mount primary sdcard locally
export def fuse [loc_trg: path = ./sdcard, rmt_org = '/sdcard'] {
  mkdir $loc_trg
  adbfs -o rellinks -o modules=subdir -o ('subdir=' + $rmt_org) ($loc_trg | path expand)
  tree -L 2 $loc_trg
}

# connect to adb wirelessly on given port with optional pairing code
export def bind [host: string, port: int = 5555, code?] {
  let addr = [$host $port] | str join ':'
  ping -c1 $host all> /dev/null | ignore
  if $code { adb pair $addr $code } else { adb connect $addr }
  adb usb detach
  wait --tcp
}

# set and bind with the wireless adb port using usb transport
export def wire [port: int = 5555] {
  wait --usb
  adb tcpip $port
  adb usb detach
  wait --tcp
}

#### Helpers

def dump-build-props [
  ota_pkg: path
  out_dir?: path
] {
  let partitions = [system product vendor]
  let job_dir = mktemp -d build-prop-dump.XXXX
  let out_dir = $out_dir | default $env.PWD
  tell info 'extracting the payload'
  unzip $ota_pkg payload.bin -d $job_dir
  cd $job_dir
  tell info 'dumping target partitions'
  payload-dumper-go -o $job_dir -p ($partitions | str join ',') payload.bin
  tell info 'mounting image files'
  for prt in $partitions {
    let loop = doas losetup --read-only --nooverlap --show --find ($prt + '.img')
    doas mount --mkdir --source $loop --target ($job_dir | path join $prt)
  }
  mut props = ''
  let prop_paths = [
    'vendor/build.prop'
    'system/vendor/build.prop'
    'system/system/build.prop'
    'system/build.prop'
    'product/build.prop'
    'product/etc/build.prop'
  ]
  tell info 'gathering build properties'
  for file in $prop_paths {
    $props ++= (try { (doas cat $file) + "\n" } catch { "\n" })
  }
  $props | save ($out_dir | path join build.prop)
  tell info 'cleaning up mounted images'
  for prt in $partitions {
    doas umount $prt
    doas losetup -d ($prt + '.img')
  }
}

def mnt-img [
  file: path
  --read-only(-r)
  ] {
  if ($file | path parse | get extension) != 'img' { print -e 'not an image'; return false }
  let ro = $read_only | to-flag read-only
  let trg = $file | path parse | get parent stem | path join
  let opt = $'X-mount.owner=(id -u),X-mount.group=(id -g)'
  let dev = doas losetup --nooverlap --show --find $file
  doas mount ...$ro --mkdir=0755 --source $dev --target $trg -o $opt
}

##############################
####<< Here be Dragons! >>####
##############################



# def --env evaluate_phone [] {
#   wait
#   let state = boot_stat
#   let droid = $env.droid
#   let devpath = adb get-devpath
#   let serlial = adb get-serialno
# }



#| reboot

# reboot system into a target state
# export def rb [
#   to: string@reboot_targs = 'device'
#   --if-not # reboot only if not already in chosen state
# ] {
#   let state = boot_stat
#   if ($if_not and ($to == $state)) { tell okey 'already booted to chosen state'; return }
#   let targ = if $to == 'device' { null } else $to
#   let to = $to | str replace 'device' 'system'
#   if $state == offline {tell fail 'device was reported as offline'}
#   tell info $"attempting reboot into ($to) mode"
#   match $state {
#     'system' => {adb reboot $targ}
#     'loader' => {fastboot reboot $targ}
#   }; wait $targ; tell okay $'device is now in ($to) state'
# }

# #| recovery

# # enter bootloader and check compatibility with recovery image
# def recov_check [] {
#   rb bootloader --if-not
#   let idn = fb_iden
#   if not ($idn.0 == $env.droid.platform) { tell fail 'unexpected platform for this recovery' }
#   tell okay $'the recovery image ($env.droid.recovery | path basename) is intended for ($idn | str join '-')'
# }

# #|
