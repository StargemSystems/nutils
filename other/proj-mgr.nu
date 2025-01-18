# project management

export-env {
  $env.PROJECTS = ($env.HOME | path join project)
}

export def shelve [...targs: path] {
  for targ in $targs {
    let item = (date now | format date '%s') + '-' + ($targ | path basename)
    let dest = ([$env.PROJECTS '.defunct' $item] | path join)
    mv $targ $dest
  }
}

export def defunct [] {
  (ls ($env.PROJECTS | path join .defunct) | get name
  | each {basename $in | parse '{archive_time}-{project_name}'}
  | flatten | update archive_time {$in | into datetime --format '%s'}
  | move project_name --before archive_time)
}

#|