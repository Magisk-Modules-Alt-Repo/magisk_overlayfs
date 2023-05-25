touch "${0%/*}/disable"
touch /dev/.overlayfs_service_unblock

while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done
rm -rf "${0%/*}/disable"

# unmount ksu overlayfs
unmount_ksu() {
    if [ "$(cat /proc/mounts | grep " $1 " | tail -1 | awk '{ print $1 }')" == "KSU" ]; then
        umount -l "$1"
    fi
}

for part in system vendor product system_ext; do
    unmount_ksu "/$part"
done