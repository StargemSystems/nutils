
# generate a namespaced v5 uuid
export def nsidgen [seed?: string base: string = "@oid"] {
  let seed = $in | default $seed
  uuidgen --sha1 --namespace $base --name $seed | str trim
}
