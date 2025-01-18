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

# Display artwork for some keyid.
export def keyart [iden?] { ^keyart -c -l $iden }

# Force redetection of avalible smartcards.
export def recard [
  --no-stat # skip reporting status
] {
	callup "scd serialno" "learn --force" /bye | ignore; sleep 1sec
  if not $no_stat { ^gpg --card-status; ykman info }
}

# Deliver payload to the gnupg agent.
export def --wrapped callup [...payload] {
  let payload = $in | append $payload
  ^gpg-connect-agent --subst --quiet --no-history --unbuffered ...$payload
}

# Parse colons from gpg command output.
export def --wrapped colonate [...optargs] {
  ^gpg --with-colons ...$optargs | lines | par-each --keep-order {split row ':'}
}

# Run gpg command with scripted input.
export def --wrapped evaluate [
  ...optargs # arguments passed to command line
  --payload(-i): list = [] # scripted inputs piped to command
  --preargs(-o): list = [--expert --yes] # first optargs in cmdline
  --keyfile(-k): path # password file location
  # --systime(-t): datetime # faked system time
  --hushrun(-q) # silence all output
] {
  let payload = $in | append $payload | flatten | str join nl
  let keyfile = $keyfile | default ($env.GNUPGHOME + /passwd.txt)
  let cmdline = [
    ($hushrun | mk-flag quiet) ($hushrun | mk-flag no-tty) $preargs
    --pinentry-mode=loopback --command-fd=0 --status-fd=2 --attribute-fd=2
    # ($systime | mk-flag faked-system-time {$systime | format date '%s'})
    ($keyfile | mk-flag passphrase-file) $optargs
  ] | flatten
  if $hushrun {
    $payload | ^gpg ...$cmdline e> (null-device)
  } else {
    $payload | ^gpg ...$cmdline
  }
}

export def edit-keys [id: string] {
  $env.GPG_TTY = (tty)
  (^gpg
    --pinentry-mode=loopback
    --passphrase-file ($env.GNUPGHOME + /passwd.txt)
    --expert --edit-key $id)
}

export def list-pubkeys [] { colonate -k | where {$in.0 == 'pub'} | each {get 4} }
export def list-userids [] { colonate -k | where {$in.0 == 'uid'} | each {get 9} | uniq }
export def list-subkeys [id: string] { colonate -k $id | where {$in.0 == 'sub'} | each {get 4 11 16} }
export def list-fingers [] { ^gpg --list-options show-only-fpr-mbox -k | lines | parse '{fingerprint} {email}' }
export def list-bylines [] { list-userids | each {parse-byline} }

def parse-byline [iden?: string] {
  let mark0 = $in | default $iden
  let mark1 = try { $mark0 | parse '{name} ({comment}) <{email}>' | move comment --after email }
  let mark2 = try { $mark0 | parse '{name} <{email}>' | insert comment null }
  if ($mark1 | is-empty) { return $mark2 } else { return $mark1 }
  }

export def --env restore-homedir [] { $env.GNUPGHOME = $env.OLD_GNUPGHOME; return $env.OLD_GNUPGHOME }

# Setup temp gnupg home directory.
export def --env mkhome [
  --password-file: path # predefine insted of generate password file
  --import-gpgfile: path # auto import and trust keys from file
] {
  let target = mktemp -d gnupg.XXXXXX
  let passwd = $target + /passwd.txt
  '#use-keyboxd' | save ($target + /common.conf)
  'disable-ccid' | save ($target + /scdaemon.conf)
  $gnupg_confs.basic | save ($target + /gpg.conf)
  $gnupg_confs.agent | save ($target + /gpg-agent.conf)
  if ($password_file | is-thing) and ($password_file | path exists) {
    cp $password_file $passwd
  } else {
    seq 1 6 | each {random chars -l 8 | str upcase} | str join sp | save $passwd
  }
  claim $target
  ^gpgconf --kill all e+o> (null-device)
  $env.OLD_GNUPGHOME = $env.GNUPGHOME
  $env.GNUPGHOME = $target
  $env.GPG_TTY = (tty)
  $env.SSH_AUTH_SOCK = (^gpgconf --list-dirs agent-ssh-socket)
  ^gpgconf --launch gpg-agent e+o> (null-device)
  ^gpg-connect-agent --quiet updatestartuptty /bye e+o> (null-device)
  ^gpg --rebuild-keydb-caches e+o> (null-device)
  if ($import_gpgfile | is-thing) and ($import_gpgfile | path exists) {
    (^gpg --pinentry-mode=loopback
      --passphrase-file $passwd
      --import $import_gpgfile e+o> (null-device))
    list-userids | each {ult-trust}
  }
  return $target
}

# Generate fresh ecdsa certify key.
export def mkcert [
  owner: string # fullname of owner
  email: string # digital mail address
] {
  let byline = $"($owner) <($email)>"
  let mykeys = list-pubkeys
  evaluate -q --quick-generate-key $byline ed25519 cert never
  list-pubkeys | where {|it| not ($it in $mykeys)} | first
}

# Generate fresh set of ecdsa subkeys.
export def mksubs [
  finger: string # cert key fingerprint
  --expire: duration = 720day
] {
  let expire = $expire | format duration day | split row ' ' | get 0
  [
    [addkey 10 1 $expire y y]
    [addkey 11 S A Q 1 $expire y y]
    [addkey 12 1 $expire y y] [save y]
  ] | flatten | evaluate -q --expert --edit-key $finger
}

# export keyset to backup directory
export def backup [keyid: string targ?: path] {
  let targ = ($targ | default $env.PWD) + $"/($keyid)-(date stamp)"
  mkdir $targ; cp ($env.GNUPGHOME + /passwd.txt) $targ
  evaluate -q --output ($targ + /certkey.gpg) --export-secret-keys $keyid
  evaluate -q --output ($targ + /subkeys.gpg) --export-secret-subkeys $keyid
  evaluate -q --output ($targ + /public.ssh) --export-ssh-key $keyid
  evaluate -q --output ($targ + /public.key) --export $keyid
}

# embed subkeys into smartcard
export def keys2card [
  keyid: string # gnupg key identity
  scpin: int # smartcard admin pin
] {
  [
    'key 1' keytocard 1 $scpin $scpin 'key 0'
    'key 2' keytocard 3 $scpin $scpin 'key 0'
    'key 3' keytocard 2 $scpin $scpin 'key 0'
    save
  ] | evaluate --edit-key $keyid
}

# trust the user id ultimately
export def ult-trust [id?: string] {
  let id = $in | default $id
  [ 'uid 1' trust 5 y q ] | evaluate -q --edit-key $id
}

export def openpgp-upload [keyid: string] {
  evaluate -q --export $keyid | curl -T - https://keys.openpgp.org
}
