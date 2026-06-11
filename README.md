# aptenodytes

in pseudo-declarative style :)

# profiling

* `GENTOO_BINHOST`, binary package for platforms
* `IGLU_ID`, the hostname
* `IGLU_LIVES, iglu_lives_`, the username(s)
* `IGLU_NETWORK`, the network topo
* `IGLU_DOMAIN`, dns search domain

if you change any of them, please check ebuilds that use, and re-emerge to take effects.

there might be some hidden dependency-chain, so, good luck.

# bring it up

```bash
# stages follow gentoo handbook first
eselect profile set "aptenodytes:iglu/${IGLU_ID}"
emerge -1 sci-misc/aptenodytes
# apply patching the portage if you're using prefix:
emerge -1 sys-apps/portage
emerge -uNDv @world
passwd "${IGLU_LIVES}"
```

(still incomplete, broken now)
