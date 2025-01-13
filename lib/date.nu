
# current datetime with utc timezone
export def "date utc" [] {
  let when = $in | default (date now)
  $when | date to-timezone UTC
}

# produce a sortable utc timestamp
export def "date stamp" [
  when?: datetime
  --precise(-p)
  --hex(-x)
] {
  let fine = elif $precise '%3f' ''
  let when = $when | default (date utc) | format date ('%y%m%d%H%M%S' + $fine) | into int
  if $hex { $when | fmt | get upperhex | str substring 2.. } else { $when }
}
