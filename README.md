# aptenodytes

in pseudo-declarative style :)

# darwin

heavily fixing many darwin prefix issues, you can use this repository to have it.

note don't emerge `sci-misc/aptenodytes` and `*/*-p` packages.

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
arch-chroot "${EPREFIX}" eselect profile set "aptenodytes:iglu/${IGLU_ID}"
arch-chroot "${EPREFIX}" emerge -1 sci-misc/aptenodytes
# apply patching the portage if you're using prefix:
arch-chroot "${EPREFIX}" emerge -1 sys-apps/portage
arch-chroot "${EPREFIX}" emerge -uNDv @world
arch-chroot "${EPREFIX}" passwd "${IGLU_LIVES}"
```

(still incomplete, broken now)
