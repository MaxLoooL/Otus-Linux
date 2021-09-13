#!/bin/bash
UUID=$(ls -la /dev/disk/by-uuid/ | grep /md0 | awk '{print $9}')

mdadm --create --verbose /dev/md0 -l 0 -n 3 /dev/sd{b,c,d} &&
mkfs.ext4 /dev/md0 && 
mkdir /root/data &&
mount /dev/md0 /root/data &&
mkdir /etc/mdadm &&
touch /etc/mdadm/mdadm.conf &&
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf &&
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf &&
echo "/dev/md0       /root/data     ext4   defaults   0 0">>/etc/fstab

for i in {1..5} ; do
sgdisk -n ${i}:0:+10M /dev/sde
done
