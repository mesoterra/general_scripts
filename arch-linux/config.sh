#!/usr/bin/env bash

#echo -e 'temppw\ntemppw' | passwd

# this is used with several subdomains.
BASE_DOMAIN="domain.tld"

hostname="$1"
disk_name="$2"
token="$3"
install_user="aur-user"

ln -sf /usr/share/zoneinfo/America/Detroit /etc/localtime

hwclock --systohc

locale-gen

echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

echo "$hostname" > /etc/hostname

if [[ $(grep -oP "^PermitRootLogin[[:blank:]]+.*$" /etc/ssh/sshd_config) ]] ; then
	sed -i 's/^PermitRootLogin.*$/PermitRootLogin no/g' /etc/ssh/sshd_config
elif [[ $(grep -oP "^[[:blank:]]*#[[:blank:]]*PermitRootLogin.*$" /etc/ssh/sshd_config) ]] ; then
	sed -i 's/^[[:blank:]]*#[[:blank:]]*PermitRootLogin.*$/PermitRootLogin yes/g' /etc/ssh/sshd_config
else
	sed '1 i\PermitRootLogin yes' /etc/ssh/sshd_config
fi

grub-install --target=i386-pc $disk_name

grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p /root/.ssh
chmod 700 /root/.ssh
curl -s -o /root/.ssh/authorized_keys "http://scripts.$BASE_DOMAIN/general/jenkins_ssh_key.pub"
chmod 600 /root/.ssh/authorized_keys

vim_rc=":filetype plugin on
:syntax on
set mouse-=a"
echo "$vim_rc" > /etc/skel/.vimrc
echo "$vim_rc" > /root/.vimrc

curl -s -o /etc/systemd/system/arch-linux-config.service "http://scripts.$BASE_DOMAIN/arch-linux/arch-linux-config.service"
systemctl enable arch-linux-config

systemctl enable sshd
systemctl enable NetworkManager

if [[ -f /root/extra-packages.txt ]] ; then
  echo 'yes|pacman --noconfirm -S $(cat /root/extra-packages.txt)
rm -f /root/extra-packages.txt'  >> /root/arch-linux-config.sh
fi

if [[ -f /root/aur-packages.txt ]] ; then
  echo "install_user=\"$install_user\"" >> /root/arch-linux-config.sh
  echo '
  useradd -m $install_user
  for each in $(cat /root/aur-packages.txt)
    do
      pkg_name="$(echo "${each}" | cut -d '"'"';'"'"' -f1)"
      pkg_file="$(echo "${each}" | cut -d '"'"';'"'"' -f2)"
      pkg_url="$(echo "${each}" | cut -d '"'"';'"'"' -f3)"
      mkdir -p /home/$install_user/$pkg_name
      wget -O /home/$install_user/$pkg_name/$pkg_file "${pkg_url}"
      cd /home/$install_user/$pkg_name/
      tar -zxvf /home/$install_user/$pkg_name/$pkg_file
      rm -f /home/$install_user/$pkg_name/$pkg_file
      cd /home/$install_user/$pkg_name/$pkg_name
      chown -R $install_user. /home/$install_user/$pkg_name
      sudo -u $install_user makepkg
      pkgname="$(grep '"'"'^pkgname='"'"' PKGBUILD | cut -d '"'"'='"'"' -f2)"
      pkgver="$(grep '"'"'^pkgver='"'"' PKGBUILD | cut -d '"'"'='"'"' -f2)"
      pkgrel="$(grep '"'"'^pkgrel='"'"' PKGBUILD | cut -d '"'"'='"'"' -f2)"
      arch="$(grep '"'"'^arch='"'"' PKGBUILD | cut -d '"'"'='"'"' -f2 | tr -d "'"'"'()")"
      install_file="$(find ./ -maxdepth 1 -name "${pkgname}-${pkgver}-${pkgrel}-${arch}.pkg.tar.*" | head -n1)"
      yes|pacman --noconfirm -U "${install_file}"
      cd /root
      rm -rf /home/$install_user/$pkg_name
  done
  rm -f /root/aur-packages.txt
  userdel -r $install_user
' >> /root/arch-linux-config.sh
fi

if [[ -f /root/additional_commands.sh ]] ; then
  echo '
  chmod 700 /root/additional_commands.sh
  /root/additional_commands.sh
  rm -f /root/additional_commands.sh
' >> /root/arch-linux-config.sh
fi

echo "
curl -s -X POST -u ${token} \"http://jenkins.$BASE_DOMAIN/job/Provisioning%20-%20Arch%20Linux%20-%20New%20VM%20Setup/buildWithParameters?ansible_hosts_to_update=\${ip}&ansible_host_mac_addr=\${mac_addr}&ansible_hostname=${hostname}\"
systemctl disable arch-linux-config
rm -f /etc/systemd/system/arch-linux-config.service
rm -f /root/arch-linux-config.sh
" >> /root/arch-linux-config.sh
chmod 700 /root/arch-linux-config.sh

exit 0
