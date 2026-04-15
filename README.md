# aptenodytes

:)

# hierarchy

For `make.defaults`, there's some invariant variables, which means you really shouldn't modify them after profile has been selected.

* `IGLU_ID`, the hostname
* UKI without initramfs, means the kernel won't boot if disks have been switched

For less restriction, i.e. users, they can be modify dynamically,

* `IGLU_LIVES`, an `USE_EXPAND` variable
