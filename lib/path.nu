
# flatten and join list into clean path
export def "path flat-join" [
  ...segments # items to concatanate
  --expand(-x) # apply path expantion
] {
  let result = ($in | append $segments
  | flatten --all | where {is-not-empty} | path join)
  if $expand { $result | path expand } else { return $result }
}
