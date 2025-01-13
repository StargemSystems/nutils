
# produce BLAKE3 checksums
export def "hash b3sum" [
  --derive(-d): string # use key derivation mode
  --length(-l): int = 32 # number of output bytes
  --seekto(-s): int = 0 # starting output byte offset
] {
  $in | ^b3sum --no-names --length $length --seek $seekto ...($derive | into-flag derive-key)
}
