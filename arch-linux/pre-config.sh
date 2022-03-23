#!/usr/bin/env bash

BASE_DOMAIN='domain.tld'

if [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]] ; then
	echo "You need 3 flags."
	echo "./pre-config.sh hostname_here diskpath_here jenkins_token"
	exit 0
fi

if [[ -z "$1" ]] ; then
	echo "Flags not set, you need 3 flags, hostname, disk_path, and jenkins_token"
	exit 1
elif [[ -z "$2" ]] ; then
	echo "Not enough flags were set, you need 3 flags, hostname, disk_path, and jenkins_token"
	exit 1
elif [[ -z "$3" ]] ; then
        echo "Not enough flags were set, you need 3 flags, hostname, disk_path, and jenkins_token"
        exit 1
elif [[ "$4" ]] ; then
	echo "Too many flags were set, you need 3 flags, hostname, disk_path, and jenkins_token"
	exit 1
fi

swapdevice="${2}1"
datadevice="${2}2"

# if you want to use a custom arch linux mirror.
#echo 'Server = http://MIRRORDOMAINHERE/$repo/os/$arch' > /etc/pacman.d/mirrorlist

sleep 5

ip route add default via $(ip route | awk '{print $1}' | grep -v '/')

killall gpg-agent

find /etc/pacman.d/gnupg ! -path /etc/pacman.d/gnupg -type f -exec rm -f '{}' \;
find /etc/pacman.d/gnupg -maxdepth 1 ! -path /etc/pacman.d/gnupg -type d -exec rm -rf '{}' \;

echo -e 'y\nn\n' | pacman -Sc

pacman-key --init
pacman-key --populate

yes|pacman -Sy --noconfirm
yes|pacman -S archlinux-keyring --noconfirm

# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can 
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/vda
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +1G # 1G swap parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  2 # bootable partition is partition 2 -- /dev/vda2
  t # set table flags
  1 # select swap partition
  82 # Linux Swap
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

mkswap ${swapdevice}
mkfs.ext4 ${datadevice}

swapon ${swapdevice}
mount ${datadevice} /mnt

pacstrap /mnt base base-devel linux linux-firmware python vim rsync tar openssh git wget curl grub networkmanager cdrkit cifs-utils

genfstab -U /mnt >> /mnt/etc/fstab

curl -q -o /mnt/root/config.sh http://scripts.$BASE_DOMAIN/arch-linux/config.sh
chmod 700 /mnt/root/config.sh

if [[ -f /root/extra-packages.txt ]] ; then
  mv /root/extra-packages.txt /mnt/root/extra-packages.txt
fi
if [[ -f /root/aur-packages.txt ]] ; then
  mv /root/aur-packages.txt /mnt/root/aur-packages.txt
fi
if [[ -f /root/additional_commands.sh ]] ; then
  mv /root/additional_commands.sh /mnt/root/additional_commands.sh
fi

echo "#!/usr/bin/env bash
ip=\"\$(ip addr show | grep -A3 -E '^[[:digit:]]:[[:blank:]]+en'| grep -E '[[:blank:]]+inet' | cut -d '/' -f1 | awk '{print \$2}')\"
mac_addr=\"\$(ip addr show | grep -B2 \"\${ip}\" | grep -E '^[[:blank:]]+link/ether' | cut -d '/' -f2 | awk '{print \$2}')\"" > /mnt/root/arch-linux-config.sh

if [[ -f "/root/arch-linux-config.sh" ]] ; then
  cat /root/arch-linux-config.sh >> /mnt/root/arch-linux-config.sh
  echo 'sleep 20' >> /mnt/root/arch-linux-config.sh
fi

cat << EOF > /mnt/root/.vimrc
:filetype plugin on
:syntax on
set mouse-=a
EOF

arch-chroot /mnt /root/config.sh $1 $2 $3

rm -f /mnt/root/config.sh

reboot
