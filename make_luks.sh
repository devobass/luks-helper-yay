#!/usr/bin/env sh

set -e

if [ "$(id -u)" -ne 0 ]
then
	printf "Not running as root, try again.\n"
	exit 1
fi

close() {
	umount "/media/$USB_UUID"
}
trap close EXIT

mount_usb() {
	if ! [ -e "/dev/disk/by-uuid/$USB_UUID" ]
	then
		printf "USB key drive not found, exiting."
		exit 1
	fi

	if mountpoint -q "/media" 
	then
		printf "Please unmount /media before continuing.\n"
		exit 1
	fi

	mkdir -p "/media/$USB_UUID"
	mount --uuid "$USB_UUID" "/media/$USB_UUID"
}

verify() {
	cd "/media/$USB_UUID"

	if [ -e "$LUKS_UUID.b3sum" ]
	then
		printf "Checksum file exists, stopping."
		exit 1
	fi
	
	b3sum "$LUKS_UUID.key" > "$LUKS_UUID.b3sum"
	b3sum "$LUKS_UUID.header" >> "$LUKS_UUID.b3sum"
}

create_luks() {

	if ! [ -e "/dev/disk/by-uuid/$LUKS_UUID" ]
	then
		printf "LUKS drive not found, exiting."
		exit 1
	fi

	if [ -n "$(blkid "/dev/disk/by-uuid/$LUKS_UUID" -s TYPE -o value)" ]
	then
		printf "Another formatted filesystem already existing, continue? (y/n) "
		read answer
		case "$answer" in
			y) printf "Continuing.\n";;
			Y) printf "Continuing.\n";;
			*) exit 1 ;;
		esac
	fi
	cryptsetup luksFormat --type luks2 "/dev/disk/by-uuid/$LUKS_UUID"
}

backup_header() {
	cryptsetup luksHeaderBackup "/dev/disk/by-uuid/$LUKS_UUID" --header-backup-file "/media/$USB_UUID/$LUKS_UUID.header"
}

add_keyfile() {
	if [ -e "/media/$USB_UUID/$LUKS_UUID.key" ]
	then
		printf "Key exists, exiting."
		exit 1
	fi
	dd if="/dev/urandom" of="/media/$USB_UUID/$LUKS_UUID.key" bs=4096 count=1	
	cryptsetup luksAddKey "/dev/disk/by-uuid/$LUKS_UUID" "/media/$USB_UUID/$LUKS_UUID.key"
}

init() {
	rm -f ./config.sh
	printf "Select LUKS drive.\n"
	printf "Accepted input: /dev/sdX, /dev/nvmeXnYpZ.\n"
	blkid --output device
	read device

	LUKS_UUID="$(blkid -s UUID -o value "$device")"
	
	printf "Select drive that will store the keyfile.\n"
	printf "Accepted input: /dev/sdX, /dev/nvmeXnYpZ.\n"
	blkid --output device
	read device

	USB_UUID="$(blkid -s UUID -o value "$device")"

	printf "LUKS_UUID=\"$LUKS_UUID\"\n" >> "./config.sh"
	printf "USB_UUID=\"$USB_UUID\"\n" >> "./config.sh"
}

if [ ! -r "./config.sh" ]
then
	printf "config.sh not found, initializing.\n"
	init
fi

. "./config.sh"

mount_usb
create_luks
add_keyfile
backup_header
verify
printf "Completed.\n"
