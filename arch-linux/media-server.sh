#!/usr/bin/env bash

# This is used in conjunction with an ansible playbook that is triggered by the terraform configs at this URL https://github.com/mesoterra/terraform_kvm_lab/tree/main/kvm/archlinux-media-server
echo '//SAMBASERVERHERE/share /mnt/media_files cifs vers=3.0,credentials=SAMBACREDENTIALFILEHERE,uid=emby,gid=emby' >> /etc/fstab


