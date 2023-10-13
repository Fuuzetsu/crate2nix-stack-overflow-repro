To reproduce and get a stack overflow fairly quickly run:

```console
nix -L build .#crate2nix-stack-overflow-repro --no-link --show-trace
```

We can however do better. You can use a patched `nix` version to get a trace
from before the overflow happens:

```console
nix -L run .#nix-stack-overflow  -- -L build .#crate2nix-stack-overflow-repro --no-link --show-trace
```

This latter will take a while. I recommend suffixing something like `2>&1 | tee
/tmp/log` as the output will be quite large.