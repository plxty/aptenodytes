# aptenodytes

in pseudo-declarative style :)

# profiling

* `IGLU_ID`, the hostname
* `IGLU_LIVES, iglu_lives_`, the username(s)
* `IGLU_NETWORK`, the network topo

if you change any of them, please check ebuilds that use, and re-emerge to take effects.

there might be some hidden dependency-chain, so, good luck.

# bring it up

```bash
curl -L "https://ptr.kei.network/noot" | bash -s -- ${IGLU_ID} /mnt/gentoo
```

(still incomplete, broken now)

# things one more

* supporting prefix, both linux and darwin
* nix-like parsing config while in ebuild
