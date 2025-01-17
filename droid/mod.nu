# Android Workbench

use ../anvil *

export alias ab = ^adb
export alias sh = ^adb shell
export alias am = ^adb shell am
export alias pm = ^adb shell pm
export alias su = ^adb shell su --preserve-environment
export alias fb = ^fastboot

def wait_targs [] { [ device recovery rescue sideload bootloader disconnect ] }
def reboot_targs [] { [ bootloader recovery device poweroff sideload sideload-auto-reboot ] }

# block until android state is reached
export def wait [
  state?: string@wait_targs = 'device'
  --usb # listen over only usb transport
  --tcp # listen over only net transport
] {
  let tran = if $usb {'usb'} else if $tcp {'local'} else {'any'}
  [ wait-for $tran $state ] | str join '-' | ^adb $in
}
