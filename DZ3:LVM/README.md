# Для начала необходимо создать LV, на который будет перенесен рут, так как xfs нельзя уменшить 
```ssh
[root@lvmZhukov ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
[root@lvmZhukov ~]# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created
[root@lvmZhukov ~]# lvcreate -n lv_root -l +10%FREE /dev/vg_root
  Logical volume "lv_root" created.
[root@lvmZhukov ~]#
```
После этого монитурую создаю и файловую систему на новый LV
```ssh 
[root@lvmZhukov ~]# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=65280 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=261120, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=855, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvmZhukov ~]# mount /dev/vg_root/lv_root /mnt
```
Далее копирую все содержимое корневой директории в /mnt, но для начала необходимо поставить утилиту xfsdump-3.1.7-1.el7.x86_6
```ssh
[root@lvmZhukov ~]# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
xfsdump: using file dump (drive_simple) strategy
xfsdump: version 3.1.7 (dump format 3.0
...
...
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 7 seconds elapsed
xfsrestore: Restore Status: SUCCESS
[root@lvmZhukov ~]#
```

Затем переконфигурирую grub для того, чтобы при старте перейти в новый /
```ssh
[root@lvmZhukov ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvmZhukov ~]# chroot /mnt/
[root@lvmZhukov /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
[root@lvmZhukov /]#
```
Обновляю образ initrd
```ssh
[root@lvmZhukov /]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;
> s/.img//g"` --force; done
```

Вношу изменения в файл /boot/grub2/grub.cfg для rd.lvm.lv с VolGroup00/LogVol00 на vg_root/lv_root. После этого выхожу из chroot и перезагружаюсь.
После перезагрузки проверяю что рут действительно в новом томе
```shh
[vagrant@lvmZhukov ~]$ lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
|-sda1                    8:1    0    1M  0 part
|-sda2                    8:2    0    1G  0 part /boot
`-sda3                    8:3    0   39G  0 part
  |-VolGroup00-LogVol00 253:1    0 37.5G  0 lvm
  `-VolGroup00-LogVol01 253:2    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk
`-vg_root-lv_root       253:0    0 1020M  0 lvm  /
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```
После этого удаляю старый LV и создаю новый с размером в 8Гб
```ssh
[root@lvmZhukov ~]# lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
  Logical volume "LogVol00" successfully removed
[root@lvmZhukov ~]# lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/VolGroup00/LogVol00.
  Logical volume "LogVol00" created.
```
Проделываю все те же операции, описанные выше

Далее выделяю том под /var с созданием зеркала
```ssh
[root@lvmZhukov boot]# pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
[root@lvmZhukov boot]# vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created
[root@lvmZhukov boot]# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
[root@lvmZhukov boot]
```
Создаю на новом томе файловую систему и перетаскиваю туда /var
```ssh
[root@lvmZhukov boot]# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
60928 inodes, 243712 blocks
12185 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=249561088
8 block groups
32768 blocks per group, 32768 fragments per group
7616 inodes per group
Superblock backups stored on blocks:
	32768, 98304, 163840, 229376

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

[root@lvmZhukov boot]# mount /dev/vg_var/lv_var /mnt
[root@lvmZhukov boot]# cp -aR /var/* /mnt/
[root@lvmZhukov boot]# rsync -avHPSAX /var/ /mnt/
sending incremental file list
./
.updated
            163 100%    0.00kB/s    0:00:00 (xfr#1, ir-chk=1028/1030)

sent 130,427 bytes  received 565 bytes  261,984.00 bytes/sec
total size is 163,954,291  speedup is 1,251.64
```
Так как в /var ничего нет, то копировать содержимое не нужно. Просто монтирую новый /var и правлю /etc/fstab для автоматического монтирования
```ssh
[root@lvmZhukov boot]# umount /mnt
[root@lvmZhukov boot]# mount /dev/vg_var/lv_var /var
[root@lvmZhukov boot]# echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```
После ребута проверяю, что корень и /var на нужных LV
```ssh
[root@lvmZhukov ~]# df -h
Filesystem                       Size  Used Avail Use% Mounted on
/dev/mapper/VolGroup00-LogVol00  8.0G  790M  7.3G  10% /
devtmpfs                         110M     0  110M   0% /dev
tmpfs                            118M     0  118M   0% /dev/shm
tmpfs                            118M  4.6M  114M   4% /run
tmpfs                            118M     0  118M   0% /sys/fs/cgroup
/dev/sda2                       1014M   61M  954M   6% /boot
/dev/mapper/vg_var-lv_var        922M  165M  694M  20% /var
tmpfs                             24M     0   24M   0% /run/user/1000
```
Удаляю временные PV,VG,LV
```ssh
[root@lvmZhukov ~]# lvremove /dev/vg_root/lv_root
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed
[root@lvmZhukov ~]# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
[root@lvmZhukov ~]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.
```

По тому же принципу что и с /var создаю LV для /home
```ssh
[root@lvmZhukov ~]# lvcreate -n LogLov_Home -L 2G /dev/VolGroup00
  Logical volume "LogLov_Home" created.
[root@lvmZhukov ~]# mkfs.xfs /dev/VolGroup00/LogLov_Home
meta-data=/dev/VolGroup00/LogLov_Home isize=512    agcount=4, agsize=131072 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvmZhukov ~]# mount /dev/VolGroup00/LogLov_Home /home
[root@lvmZhukov ~]# echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```
Создаю несколько файлов в /home, LV с их снепшотами, удаляю несколько файлов и мержу снепшоты
```ssh
[root@lvmZhukov ~]# touch /home/file{1..20}
[root@lvmZhukov ~]# ls /home/
file1   file11  file13  file15  file17  file19  file20  file4  file6  file8
file10  file12  file14  file16  file18  file2   file3   file5  file7  file9
[root@lvmZhukov ~]# lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogLov_Home
  Rounding up size to full physical extent 128.00 MiB
  Logical volume "home_snap" created.
[root@lvmZhukov ~]# rm -f /home/file{10..20}
[root@lvmZhukov ~]# ls /home/
file1  file2  file3  file4  file5  file6  file7  file8  file9
[root@lvmZhukov ~]# umount /home/
[root@lvmZhukov ~]# lvconvert --merge /dev/VolGroup00/home_snap
  Merging of volume VolGroup00/home_snap started.
  VolGroup00/LogLov_Home: Merged: 100.00%

[root@lvmZhukov ~]#
[root@lvmZhukov ~]# mount /home/
[root@lvmZhukov ~]# ls /home/
file1   file11  file13  file15  file17  file19  file20  file4  file6  file8
file10  file12  file14  file16  file18  file2   file3   file5  file7  file9
```

Теперь необходимо создать кеш и попробовать примонтировать zfs
```ssh
[root@lvmZhukov ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
[root@lvmZhukov ~]# vgcreate cache /dev/sdb
[root@lvmZhukov ~]# lvcreate -n metacahce -L3G /dev/cache
  Logical volume "metacahce" created.
[root@lvmZhukov ~]# lvcreate -n datacache -L6G /dev/cache
  Logical volume "datacache" created.
[root@lvmZhukov ~]# lvconvert --type cache --cachepool /dev/cache/datacache /dev/cache/metacahce
  WARNING: Converting cache/datacache to cache pool's data volume with metadata wiping.
  THIS WILL DESTROY CONTENT OF LOGICAL VOLUME (filesystem etc.)
Do you really want to convert cache/datacache? [y/n]: y
  Converted cache/datacache to cache pool.
  Logical volume cache/metacahce is now cached.
[root@lvmZhukov ~]# lvs -a
  LV                VG         Attr       LSize   Pool        Origin            Data%  Meta%  Move Log Cpy%Sync Convert
  LogLov_Home       VolGroup00 -wi-ao----   2.00g
  LogVol00          VolGroup00 -wi-ao----   8.00g
  LogVol01          VolGroup00 -wi-ao----   1.50g
  [datacache]       cache      Cwi---C---   6.00g                               0.00   6.77            0.00
  [datacache_cdata] cache      Cwi-ao----   6.00g
  [datacache_cmeta] cache      ewi-ao----  12.00m
  [lvol0_pmspare]   cache      ewi-------  12.00m
  metacahce         cache      Cwi-a-C---   3.00g [datacache] [metacahce_corig] 0.00   6.77            0.00
  [metacahce_corig] cache      owi-aoC---   3.00g
  lv_var            vg_var     rwi-aor--- 952.00m                                                      100.00
  [lv_var_rimage_0] vg_var     iwi-aor--- 952.00m
  [lv_var_rimage_1] vg_var     iwi-aor--- 952.00m
  [lv_var_rmeta_0]  vg_var     ewi-aor---   4.00m
  [lv_var_rmeta_1]  vg_var     ewi-aor---   4.00m
```
```ssh
[root@lvmZhukov ~]# pvremove /dev/sde
  Labels on physical volume "/dev/sde" successfully wiped.
[root@lvmZhukov ~]#
[root@lvmZhukov ~]# mkfs.btrfs /dev/sde -L singe_drive
btrfs-progs v4.9.1
See http://btrfs.wiki.kernel.org for more information.

Label:              singe_drive
UUID:               8ad742af-ad53-4463-b672-15997608f466
Node size:          16384
Sector size:        4096
Filesystem size:    1.00GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         DUP              51.19MiB
  System:           DUP               8.00MiB
SSD detected:       no
Incompat features:  extref, skinny-metadata
Number of devices:  1
Devices:
   ID        SIZE  PATH
    1     1.00GiB  /dev/sde

```
