
# reset and clear terminal
export def --env clr [] { clear; reset }

# prompt for confirmation
export def confirm [
  prompt: string # message to query with
  --invert # default to no insted of yes
] {
  if $invert {
    (input -n 1 ($prompt + ' [N/y]: ')) =~ "n|N|\n"
  } else {
    (input -n 1 ($prompt + ' [Y/n]: ')) =~ "y|Y|\n"
  }
}
