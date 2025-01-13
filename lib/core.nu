
# print an error message and halt
export def failure [message: string] { error make -u {msg: $message} }

# eval closure otherwise return given value
export def varval [it? ...rest] {
  let it = $in | default $it
  if ($it | of-type closure) { do $it ...$rest } else { return $it }
}

# simpler if-else statement for ergonomic use within variable bindings
export def elif [cond: bool then: any else?: any] {
  if $cond { varval $then } else { varval $else }
}

# dynamic evaled values for defaults
export def "default do" [func: closure] {
  let item = $in
  if ($item | is-empty) { do $func } else { $item }
}
