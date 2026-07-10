# aptenodytes

in pseudo-declarative style :)

please note `sci-misc/aptenodytes` and `SLOT=ridgeni` in ebuild mean profile packages, which is highly personalized.

# profiling

* `GENTOO_BINHOST`, binary package for platforms
* `IGLU_ID`, the hostname, including domain
* `IGLU_LIVES, iglu_lives_`, the username(s)
* `IGLU_NETWORK`, the network topo

if you change any of them, please check ebuilds that use, and re-emerge to take effects.

there might be some hidden dependency-chain, so, good luck.

# burn-it-down

investigate `scripts/burn.sh` for spy.
