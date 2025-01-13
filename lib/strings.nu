
export alias conjoin-nl = str join (char nl)
export alias conjoin = str join ''

# remove all of char from string
export def "str strip" [char: string = ' '] { $in | str replace -a $char '' }

# remove regex match from string
export def "str purge" [expr: string] { $in | str replace -arm $expr '' }

# replace repeating chars with a single one
export def "str squeeze" [char: string = ' '] { $in | str replace -a -r $'[($char)]+' $char }

# join list into string with new lines
export def "str join-nl" [...items] { $in | append $items | flatten | str join (char nl) }

# dubble quote something for posix usage
export def "str enquote" [it?: any] { $in | default $it | to json -r | str replace -am '"' '\"' | $'"($in)"' }
