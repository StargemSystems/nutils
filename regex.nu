# Helpers for working with regular expressions

use anvil

export-env {
  $env.regex_pallet = {
    hexDigit: ''
    emailAddress: ''
    uuid: ''
  }
}

# Turn an oil style regular expression into standard form
export def eggex [...expr] { ^ysh -c $'write $[/ ($expr | conjoin) /]' }

def fits_into [type: string item?] {
  let item = $in | default $item
}

export def fits-into [type: string ...items] {
  let items = $in | append $items
  $items | each { fits_into $type }
}

#|