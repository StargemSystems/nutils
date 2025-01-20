# Nutils

> NuShell utility toolkit and standard library

## Getting Started

Our extended standard library is called `anvil`. Append `nutils` to your NuShell library search path. Then bring the common use namespace into scope.

```nushell
  $env.NU_LIB_DIRS = $env.NU_LIB_DIRS | append (
    (nix build --no-link --print-out-paths
      'github:StargemSystems/nutils')
    + /share/nushell/nutils)
  use nutils/anvil *
```

## Available Applets

- droid
- gnupg
- nixos
- other
- regex
- zedfs
