
# inverse of is-empty
export alias is-thing = is-not-empty

# return head of list
export def hd [list?] { $in | default $list | first }

# return tail of list
export def tl [list?] { $in | default $list | skip 1 }

# enforce given order of columns
export def reorder [...headers] { $in | move ...(tl $headers) --after (hd $headers) }

# flatten returning first item if only one
export def squish [...items] {
  let flat = $in | append $items | flatten | where {is-thing}
  if ($flat | length) == 1 { $flat | first } else { $flat }
}

# test if input is of some types
export def of-type [...types] {
  if (($in | describe) in $types) { return true } else { return false }
}

# assert is empty or matches sample
export def is-empty-or [match] {
  let it = $in
  if ($it | is-empty) or ($it =~ $match) { return true } else { return false }
}
