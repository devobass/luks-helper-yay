#!/usr/bin/env sh

set -e

if [ "$(id -u)" -ne 0 ]
then
	printf "Not running as root, try again.\n"
	exit 1
fi

close() {
	printf "Closing LUKS.\n"

	umount "/mnt/$LUKS_UUID"
	cryptsetup luksClose "BACKUP_$LUKS_UUID"
	umount "/media/$USB_UUID"
}

mount_drives() {
	if mountpoint -q "/media"
	then
		printf "Please unmount /media before continuing.\n"
		exit 1
	fi

	if mountpoint -q "/mnt"
	then
		printf "Please unmount /mnt before continuing.\n"
		exit 1
	fi

	mkdir -p "/media/$USB_UUID"
	mkdir -p "/mnt/$LUKS_UUID"

	mount "/dev/disk/by-uuid/$USB_UUID" "/media/$USB_UUID"
}

verify() {
	KEYFILE="/media/$USB_UUID/$LUKS_UUID.key"
	CHECKSUM="$LUKS_UUID.b3sum"

	cd "/media/$USB_UUID"
	if ! b3sum -c "$CHECKSUM"
	then
		printf "WARNING: CHECKSUM MISMATCH, YOUR KEY MIGHT BE CORRUPTED!\n"
		exit 1
	fi
}

open_luks() {
	cryptsetup luksOpen --key-file "/media/$USB_UUID/$LUKS_UUID.key" "/dev/disk/by-uuid/$LUKS_UUID" "BACKUP_$LUKS_UUID"
	mount "/dev/mapper/BACKUP_$LUKS_UUID" "/mnt/$LUKS_UUID"
}

init() {
	printf "Select LUKS drive.\n"
	printf "Accepted input: /dev/sdX, /dev/nvmeXnYpZ.\n"
	blkid --output device
	read device

	LUKS_UUID="$(blkid -s UUID -o value "$device")"

	if [ -z "$LUKS_UUID" ]
	then
		printf "Drive %s not found.\n" "$device"
		exit 1
	fi
	
	printf "Select drive that has the keyfile.\n"
	printf "Accepted input: /dev/sdX, /dev/nvmeXnYpZ.\n"
	blkid --output device
	read device

	USB_UUID="$(blkid -s UUID -o value "$device")"

	if [ -z "$USB_UUID" ]
	then
		printf "Drive %s not found.\n" "$device"
		exit 1
	fi

	rm -f ./config.sh

	printf "LUKS_UUID=\"$LUKS_UUID\"\n" >> "./config.sh"
	printf "USB_UUID=\"$USB_UUID\"\n" >> "./config.sh"
}

open() {
	mount_drives
	verify
	open_luks
	printf "Drive is open at /mnt/%s\n" "$LUKS_UUID"
}

help() {
	printf "Usage: main.sh open|close|init\n"	
	printf "open: open luks\n"	
	printf "close: close luks\n"	
	printf "init: create/change config\n"	
	exit 0
}

if [ ! -r "./config.sh" ]
then
	printf "config.sh not found, initializing.\n"
	init
fi

. "./config.sh"

if [ -z "$1" ] 
then
	help
fi

case "$1" in
	open) open ;;
	close) close ;;
	init) init ;;
	*) help ;;
esac
