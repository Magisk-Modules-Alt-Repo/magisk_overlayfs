unset vendor
unset product
unset system_ext

MODPATH="${0%/*}"
rm -rf "$MODPATH/err_output.txt"
exec 2>> "$MODPATH/err_output.txt"
set -x

MAGISKTMP="$(magisk --path)"
[ -z "$MAGISKTMP" ] && MAGISKTMP=/sbin

mkdir -p "$MAGISKTMP/.magisk/tmp"

TMPDIR="$MAGISKTMP/.magisk/tmp"



DATA_BLOCK="$(mount | grep " /data " | awk '{ print $1 }')"
DATA_BLOCK="/dev/block/$(basename "$DATA_BLOCK")"
test -z "$DATA_BLOCK" && exit
MAGISK_DATAMIRROR="$MAGISKTMP/.magisk/mirror/data"

MODID="$(basename "${0%/*}")"
MODPATH="$MAGISK_DATAMIRROR/adb/modules/$MODID"
MODDIR="$MODPATH"

mount | grep -q " /vendor " && vendor=/vendor
mount | grep -q " /system_ext " && system_ext=/system_ext
mount | grep -q " /product " && product=/product

# support replace folder for overlay like Magic Mount can do

( IFS=$'\n'
list_folder="$(find /data/adb/modules/*/system/* -type d)"
for dir in $list_folder; do
test -f "$dir/.replace" && setfattr -n trusted.overlay.opaque -v y "$dir" || setfattr -x trusted.overlay.opaque "$dir"
done
)



get_modules(){ (
extra="$1"; data="$2"
[ -z "$data" ] && data="$MAGISKTMP/.magisk/modules"
IFS=$'\n'
modules="$(find "$data/"*"/system" -prune -type d)"
( for module in $modules; do
[ ! -e "${module%/*}/disable" ] && [ -f "${module%/*}/overlay" -o -f "$MODDIR/enable" ] && [ -d "${module}${extra}" ] && echo -ne "${module}/${extra}\n"
done ) | tr '\n' ':'
) }

# default is read-only

MOUNT_ATTR=ro
LOCK_RO=false
if [ -f "$MODDIR/mountrw" ]; then
MOUNT_ATTR=rw
elif [ -f "$MODDIR/lockro" ]; then
MOUNT_ATTR=ro
LOCK_RO=true
fi


overlay(){ (
fs="$1"
extra="$2"
overlay_name="$MAGISKTMP/.magisk/block/overlay"
mkdir -p "$MODDIR/overlay/$fs"
mkdir -p "$MODDIR/workdir/$fs"
magisk --clone-attr "$fs" "$MODDIR/overlay/$fs"
true
MOUNT_OPTION="lowerdir=$extra$fs,upperdir=$MODDIR/overlay/$fs,workdir=$MODDIR/workdir/$fs"
MOUNT_OPTION2="lowerdir=$extra$MAGISKTMP/.magisk/mirror/$fs,upperdir=$MODDIR/overlay/$fs,workdir=$MODDIR/workdir/$fs"
if $LOCK_RO; then
MOUNT_OPTION="lowerdir=$MODDIR/overlay/$fs:$extra$fs"
MOUNT_OPTION2="lowerdir=$MODDIR/overlay/$fs:$extra$MAGISKTMP/.magisk/mirror/$fs"
fi

mount -t overlay -o "$MOUNT_ATTR,$MOUNT_OPTION" $overlay_name "$fs" 
mount -t overlay -o "$MOUNT_ATTR,$MOUNT_OPTION2" $overlay_name "$MAGISKTMP/.magisk/mirror/$fs" 
mount -t overlay | grep " $fs " && echo -n  "$fs " >>"$TMPDIR/overlay_mountpoint"
) &
}


rm -rf "/dev/system_overlay"
ln -fs "$MODDIR" "/dev/system_overlay"
rm -rf "/dev/module_overlay"
ln -fs "$MAGISKTMP/.magisk/modules" "/dev/module_overlay"

overlay_system(){ (
fs="$1"
extra="$2"
overlay_name="/dev/block/by-name/system"
mkdir -p "$MODDIR/overlay/$fs"
mkdir -p "$MODDIR/workdir/$fs"
magisk --clone-attr "$fs" "$MODDIR/overlay/$fs"
MODDIR2="/dev/system_overlay"

true
MOUNT_OPTION="lowerdir=$extra$fs,upperdir=$MODDIR2/overlay/$fs,workdir=$MODDIR2/workdir/$fs"
MOUNT_OPTION2="lowerdir=$extra$MAGISKTMP/.magisk/mirror/$fs,upperdir=$MODDIR/overlay/$fs,workdir=$MODDIR/workdir/$fs"
if $LOCK_RO; then
MOUNT_OPTION="lowerdir=$MODDIR2/overlay/$fs:$extra$fs"
MOUNT_OPTION2="lowerdir=$MODDIR/overlay/$fs:$extra$MAGISKTMP/.magisk/mirror/$fs"
fi

mount -t overlay -o "$MOUNT_ATTR,$MOUNT_OPTION" $overlay_name "$fs" 
mount -t overlay -o "$MOUNT_ATTR,$MOUNT_OPTION2" $overlay_name "$MAGISKTMP/.magisk/mirror/$fs" 
mount -t overlay | grep " $fs " && echo -n  "$fs " >>"$TMPDIR/overlay_mountpoint"
) &
}



ROPART="
$vendor
$system_ext
$product
"

for block in system system_root vendor system_ext product; do
if [ -b "$MAGISKTMP/.magisk/block/$block" ]; then
mkdir -p "$MAGISKTMP/.magisk/mirror/real_$block"
mount -o ro "$MAGISKTMP/.magisk/block/$block" "$MAGISKTMP/.magisk/mirror/real_$block"
fi
done



overlay /system




mk_nullchar_dev(){
TARGET="$1"
rm -rf "$TARGET"
mkdir -p "${TARGET%/*}"
mknod "$TARGET" c 0 0
}


# merge modified /system, /vendor, /product, ... from modules to real partition (do not merge on root directory of these partition)

(cd /system; find * -prune -type d ) | while read dir; do
if [ ! -L "/system/$dir" ]; then
    mountpoint "/system/$dir" -q || overlay "/system/$dir" "$(get_modules "/$dir")"
fi
done


for part in $ROPART; do
find $part/* -prune -type d | while read dir; do
if [ ! -L "$dir" ]; then
mountpoint $dir -q || overlay $dir "$(get_modules "$dir")"
fi
done
done

sleep 0.05

module_status(){

COUNT=0

IFS=$'\n'
modules="$(find /data/adb/modules/*/system -prune -type d)"
for module in $modules; do
[ ! -e "${module%/*}/disable" ] && [ -f "${module%/*}/overlay" -o -f "$MODDIR/enable" ] && COUNT=$(($COUNT+1))
done

cp "$MODPATH/module.prop" "$TMPDIR/overlay_status"

DESC="OverlayFS is working normally 😋. Loaded overlay for $COUNT module(s)"

[ ! -f "$TMPDIR/overlay_mountpoint" ] && DESC="OverlayFS is not working!! Maybe your kernel does not support overlayfs ☹️"


sed -Ei "s|^description=(\[.*][[:space:]]*)?|description=[ $DESC ] |g" "$TMPDIR/overlay_status"

mount --bind "$TMPDIR/overlay_status" "$MAGISKTMP/.magisk/modules/$MODID/module.prop"
}

module_status &
rm -rf "/dev/system_overlay"
rm -rf "/dev/module_overlay"
