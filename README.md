# Magisk OverlayFS
From Android 10+, system may no longer to be mounted as read-write. A simple script that can emulate read-write partition for read-only system partitions.

## Requirements
- Your kernel must support overlayfs

## What this module do?

> This module is experimental, might not work or cause some problems on some devices/ROMs

- The aim of this module is to emulate system writeable by using overlayfs also make modifying system partition become systemless. That's mean no actual changes are done on system partition through overlayfs. The modified files are stored inside `/data/adb/modules/magisk_overlayfs/overlay`. Note, overlay is mounted read-only by default (still can be remounted read-write), you can create `mountrw` in `/data/adb/modules/magisk_overlayfs` to make it mounted read-write by default and allow runtime modified files.
- After modifying overlay, you can lock it as read-only by creating a dummy file name `lockro`, however overlay will not be able to be remounted as read-write.
- Hide custom ROM, overlay system partitions with no `addon.d` and `init.d` without actually deleting them.
- Hide OverlayFS: Create `hide` dummy file in `/data/adb/modules/magisk_overlayfs` to hide overlayfs but hiding custom ROM will lose effect. In fact, there are very few apps detect for OverlayFS or Custom ROM. In short, cannot hide both Custom ROM and OverlayFS at same time.
- On Android 12+, font modules will crash apps if you hide Magisk from those apps. OverlayFS will keep all font files intact after magisk module files are unmounted for those apps (only if OverlayFS is enabled on modules and hiding OverlayFS is disabled).
- Overlay-based modules for Magisk modules, (merge modules system files into system by using overlayfs instead of Magic Mount): 
    - Enable on some modules: Create `overlay` and `skip_mount` (if you don't want to use Magic Mount) dummy file in which module directory you want to enable this feature
    - Enable for all modules (Global mode): Create `enable` dummy file in `/data/adb/modules/magisk_overlayfs` and create `skip_mount` for all modules, you can do it by using this command in Terminal Emulator: 
```
for module in `ls /data/adb/modules`; do
touch /data/adb/modules/$module/skip_mount
done
```


## Magic Mount vs OverlayFS

| Magic Mount | OverlayFS |
| :--: | :--: |
| Work on almost kernel | Only work if kernel support (usually Android 10+) |
| Does not support delete files systemlessly (It can but very complicated) | Can emulate files have been deleted without changing the original partition make remove files systemlessly possible |
| When a module want to add a file into real partition, Magisk cannot add it directly, has to do under-hood multiple mount bind tasks to achieve it | Add files by combining between lowerdir and upperdir |
