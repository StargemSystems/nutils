# Gnu Privacy Guard

use anvil *

const gnupg_confs = {
  basic: '
    no-greeting
    no-comments
    charset utf-8
    no-emit-version
    keyid-format 0xlong
    with-subkey-fingerprint
    with-v5-fingerprint
    with-fingerprint
    with-keygrip
    require-cross-certification
    default-keyserver-url hkps://keys.openpgp.org
    default-new-key-algo ed25519/cert,sign+cv25519/encr
    # default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
    # s2k-digest-algo SHA512
    # s2k-cipher-algo AES256
    verify-options show-uid-validity
    list-options show-uid-validity
    # no-symkey-cache
    throw-keyids
    use-agent
    armor
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

# run gpg with scripted input
export def --wrapped evaluate [
  ...optargs # arguments passed to command line
  --payload(-i): list = [] # scripted inputs piped to gpg
  --preargs(-o): list = [--expert --yes --no-tty] # first optargs in cmdline
] {
  let payload = $in | append $payload | flatten | str join nl
  let cmdline = [
    ...$preargs
    --pinentry-mode=loopback --command-fd=0
    --passphrase-file=($env.GNUPGHOME + /passwd.txt)
    ...$optargs
  ]
  $payload | ^gpg ...$cmdline
}

# deliver payload to the gnupg agent
export def --wrapped callupon [...payload] {
  let payload = $in | append $payload
  gpg-connect-agent --subst --quiet --no-history --unbuffered ...$payload
}

# setup temp gnupg home dir
export def --env mktemp-homedir [
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
  claim-as $env.USER nogroup 'a=,u=rwX' $target
  ^gpgconf --kill all e+o> (null-device)
  $env.OLD_GNUPGHOME = $env.GNUPGHOME
  $env.GNUPGHOME = $target
  $env.GPG_TTY = (tty)
  ^gpg-connect-agent --homedir $target --quiet /bye e+o> (null-device)
  ^gpg --homedir $target --rebuild-keydb-caches e+o> (null-device)
  return $target
}

# listing of avalible public and secret keys
export def key-list [] {
  [public secret] | each {(
    ^gpg --with-colons $'--list-($in)-keys' | lines
    | par-each --keep-order { split row ':' | squish }
  )} | flatten
}

# listing of all avalible fingerprints
export def fpr-list [] { key-list | where {$in.0 =~ 'fpr|grp'} | each {skip 1} | flatten }

# listing of known identities
export def idn-list [] { ^gpg --list-options show-only-fpr-mbox -k | parse '{fingerprint} {mailbox}' }

# force redetect avalible smartcards
export def recard [
  --quiet # skip reporting status
] {
	callupon "scd serialno" "learn --force" /bye | ignore
	sleep 1sec
  if not $quiet { ^gpg --card-status; ykman info }
}