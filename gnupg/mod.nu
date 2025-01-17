# Gnu Privacy Guard

use ../anvil *

const gnupg_confs = {
  basic: '
    armor
    use-agent
    no-greeting
    no-comments
    throw-keyids
    charset utf-8
    no-emit-version
    no-symkey-cache
    keyid-format 0xlong
    require-cross-certification
    list-options show-uid-validity
    verify-options show-uid-validity
    default-keyserver-url hkps://keys.openpgp.org
    default-new-key-algo ed25519/cert,sign+cv25519/encr
    with-subkey-fingerprint
    with-v5-fingerprint
    with-fingerprint
    with-keygrip

    # For older gnupg versions only. On newer versions, this is already the default.
    # default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
    # s2k-digest-algo SHA512
    # s2k-cipher-algo AES256
  '
  agent: '
    max-cache-ttl 120
    enable-ssh-support
    default-cache-ttl 60
    allow-loopback-pinentry
    allow-preset-passphrase
    ssh-fingerprint-digest SHA256
    pinentry-program /run/current-system/sw/bin/pinentry-tty
  '
}

# Format of colon listings: https://github.com/gpg/gnupg/blob/master/doc/DETAILS

const colon_types = {
  pub: 'Public key'
  crt: 'Certificate'
  crs: 'Certificate private key'
  sub: 'Subkey'
  sec: 'Secret key'
  ssb: 'Secret subkey'
  uid: 'User id'
  uat: 'User attribute'
  sig: 'Signature'
  rev: 'Revocation signature'
  rvs: 'Standalone revocation signature'
  fpr: 'Fingerprint'
  fp2: 'SHA-256 fingerprint'
  pkd: 'Public key data'
  grp: 'Keygrip'
  rvk: 'Revocation key'
  tfs: 'TOFU statistics'
  tru: 'Trust database information'
  spk: 'Signature subpacket'
  cfg: 'Configuration data'
  gpg: 'General response'
}

const colon_feild = {
  1: 'Record type'
  2: 'Validity'
  3: 'Key length'
  4: 'Public key algorithm'
  5: 'KeyID'
  6: 'Creation date'
  7: 'Expiration date'
  8: 'Certificate S/N, UID hash, trust signature info'
  9: 'Ownertrust'
  10: 'User-ID'
  11: 'Signature class'
  12: 'Key capabilities'
  13: 'Issuer certificate fingerprint or other info'
  14: 'Flag field'
  15: 'Token serial number'
  16: 'Hash algorithm'
  17: 'Curve name'
}

# display artwork for keyid
export def keyart [iden?] { ^keyart -c -l $iden }

# force redetect of avalible smartcards
export def recard [
  --no-stat # skip reporting status
] {
	callup "scd serialno" "learn --force" /bye | ignore; sleep 1sec
  if not $no_stat { ^gpg --card-status; ykman info }
}

# deliver payload to the gnupg agent
export def --wrapped callup [...payload] {
  let payload = $in | append $payload
  ^gpg-connect-agent --subst --quiet --no-history --unbuffered ...$payload
}

# parse colons from gpg command
export def --wrapped colonate [...optargs] {
  ^gpg --with-colons ...$optargs | lines | par-each --keep-order {split row ':'}
}

# run gpg command with scripted input
export def --wrapped evaluate [
  ...optargs # arguments passed to command line
  --payload(-i): list = [] # scripted inputs piped to command
  --preargs(-o): list = [--expert --yes --no-tty] # first optargs in cmdline
  --keyfile(-k): path # password file location
  --systime(-t): datetime # faked system time
  # --hushrun(-q) # silence all output
] {
  let payload = $in | append $payload | flatten | str join nl
  let keyfile = $keyfile | default ($env.GNUPGHOME + /passwd.txt)
  let cmdline = [
    $preargs --pinentry-mode=loopback --command-fd=0
    ($systime | mk-flag faked-system-time {$systime | format date '%s'})
    ($keyfile | mk-flag passphrase-file) $optargs
  ] | flatten
  $payload | ^gpg ...$cmdline
}

def finger-email [email: string] { ^gpg --list-options show-only-fpr-mbox -k $email | split words | first }
def parse-byline [iden?: string] {
  let mark0 = $in | default $iden
  let mark1 = try { $mark0 | parse '{name} ({comment}) <{email}>' | move comment --after email }
  let mark2 = try { $mark0 | parse '{name} <{email}>' | insert comment null }
  if ($mark1 | is-empty) { return $mark2 } else { return $mark1 }
}

def find-byline [iden: string] { get-bylines | find $iden | first }
def get-bylines [] {
  (colonate -k | where {'uid' in $in}
  | par-each {get 9 | parse-byline} | flatten
  | upsert fingerprint {|idn| finger-email $idn.email }
  | upsert keyid {|idn| $idn.fingerprint | str substring (-16).. }
  | move keyid --before name )
}

# setup temp gnupg home dir
export def --env mkhome [
  --password-file: path # predefined password file
] {
  let target = mktemp -d gnupg.XXXXXX
  let passwd = $target + /passwd.txt
  '#use-keyboxd' | save ($target + /common.conf)
  'disable-ccid' | save ($target + /scdaemon.conf)
  $gnupg_confs.basic | save ($target + /gpg.conf)
  $gnupg_confs.agent | save ($target + /gpg-agent.conf)
  if $password_file { cp $password_file $passwd }
  if not ($passwd | path exists) {
    seq 1 6 | each {random chars -l 8 | str upcase}
    | str join sp | save $passwd
  }
  claim $target
  ^gpgconf --kill all e+o> (null-device)
  $env.OLD_GNUPGHOME = $env.GNUPGHOME
  $env.GNUPGHOME = $target
  $env.GPG_TTY = (tty)
  ^gpg-connect-agent --homedir $target --quiet /bye e+o> (null-device)
  ^gpg --homedir $target --rebuild-keydb-caches e+o> (null-device)
  return $target
}

# generate fresh ecdsa keyset
export def mkcert [
  owner: string # fullname of owner
  email: string # digital mail address
  --ctime(-c): datetime # creation moment
  --etime(-e): datetime # expired moment
  --skinny(-s) # skip generation of subkeys
] {
  let byline = $"($owner) <($email)>"
  let create = $ctime | default (date now)
  let expire = $etime | default ($create + 720day | format date '%Y-01-01' | into datetime)
  let expire = ($expire - $create | format duration day | split row '.').0 + 'd'
  evaluate --systime $create --quick-generate-key $byline ed25519 cert never o+e> (null-device)
  let finger = find-byline $email | get fingerprint
  if not $skinny { for kind in [ [ed25519 sign] [ed25519 auth] [cv25519 encr] ] {
    evaluate --systime ($create + 2sec) --quick-add-key $finger ...$kind $expire o+e> (null-device) }}
  return [$owner $email $finger]
}
