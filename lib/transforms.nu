
# produce list with value flagged for use in command spread
export def into-flag [flag item?] {
  let cond = $in
  let flag = ('--' + $flag)
  let item = $item | default $cond
  if ($cond | is-empty) or ($cond == false) { return [] }
  if ($cond == true) and ($item == true) { return [$flag] }
  return [$flag (varval $item $cond)]
}
