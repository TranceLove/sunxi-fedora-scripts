#!/bin/bash

DIALOG="$(which dialog 2> /dev/null)"

set -e

CANON="$(readlink -f $0)"
BOARD="$1"
LCD=""
UBOOT_MOUNT="$(dirname $CANON)"
BOARDS_DIR="$UBOOT_MOUNT/boards"
UBOOT_DEV="$(df $CANON | tail -n 1 | awk '{print $1}')"

BOARDS=()
BOARDS+=(a10_mid_1gb         "A10 tablet sold under various names (whitelabel)")
BOARDS+=(meep1               "Oregon Scientific Meeppad 1")

if [ "$1" = "--help" -o -z "$DIALOG" -a -z "$BOARD" ]; then
    echo "Usage: \"$0 <board>\""
    echo "Available boards:"
    for (( i = 0; i < ${#BOARDS[@]} ; i+=2 )); do
        printf "%-20s%s\n" "${BOARDS[$i]}" "${BOARDS[(($i + 1))]}"
    done
    exit 0
fi


# Remove partition at the end of UBOOT_DEV to get the sdcard dev
if expr match "$UBOOT_DEV" "/dev/sd.1" > /dev/null; then
    SDCARD_DEV=$(echo $UBOOT_DEV | sed 's+1$++')
elif expr match "$UBOOT_DEV" "/dev/mmcblk.p1" > /dev/null; then
    SDCARD_DEV=$(echo $UBOOT_DEV | sed 's+p1$++')
else
    echo "Error cannot determine sdcard-dev from uboot-dev $UBOOT_DEV"
    exit 1
fi

if [ ! -w "$SDCARD_DEV" ]; then
    echo "Error cannot write to $SDCARD_DEV (try running as root)"
    exit 1
fi


yesno () {
    if [ -z "$DIALOG" ]; then
        echo "$1"
        echo -n "Press enter to continue, CTRL+C to cancel"
        read
    else
        dialog --yesno "$1" 20 76
    fi
}


if [ -z "$BOARD" ]; then
    yesno "Your sdcard has been detected at $SDCARD_DEV. If this is wrong this utility may corrupt data on the detected disk! Is $SDCARD_DEV the correct disk to install the spl, u-boot and uEnv too ?"

    TMPFILE=$(mktemp)
    dialog --menu "Select your Allwinner board" 20 76 30 "${BOARDS[@]}" 2> $TMPFILE
    BOARD="$(cat $TMPFILE)"
    rm $TMPFILE
fi

case "$BOARD" in
    *-lcd7)
        BOARD=${BOARD:0:-5}
        LCD=-lcd7
        ;;
    *-lcd10)
        BOARD=${BOARD:0:-6}
        LCD=-lcd10
        ;;
esac

if [ -d $BOARDS_DIR/sun4i/$BOARD ]; then
    ARCH=sun4i
else
    echo "Error cannot find board dir: $BOARDS_DIR/sun?i/$BOARD"
    exit 1
fi

yesno "Are you sure you want to install the spl, u-boot and kernel for $BOARD$LCD from $BOARDS_DIR onto $SDCARD_DEV ?"

echo
echo "Installing spl, u-boot and kernel for $BOARD$LCD onto $SDCARD_DEV ..."

dd if="$BOARDS_DIR/$ARCH/$BOARD/u-boot-sunxi-with-spl.bin" of="$SDCARD_DEV" bs=1024 seek=8
dd if="$BOARDS_DIR/uEnv-img.bin" of="$SDCARD_DEV" bs=1024 seek=544
cp "$BOARDS_DIR/$ARCH/$BOARD/script$LCD.bin" "$UBOOT_MOUNT/script.bin"
sync

echo "Done"
