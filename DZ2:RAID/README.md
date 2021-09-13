# В качестве Vagrantfile использую [этот](https://github.com/erlong15/otus-linux/blob/master/Vagrantfile) образ
Создаю массив RAID0 из трех дисков
```sh
[root@RAIDZhukov ~] mdadm --create --verbose /dev/md0 -l 0 -n 3 /dev/sd{b,c,d}
mdadm: chunk size defaults to 512K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
[root@RAIDZhukov ~]#
```

# Проверяю создание массива командой lsblk

```sh
[root@RAIDZhukov ~] lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda      8:0    0   40G  0 disk
`-sda1   8:1    0   40G  0 part  /
sdb      8:16   0  250M  0 disk
`-md0    9:0    0  744M  0 raid0
sdc      8:32   0  250M  0 disk
`-md0    9:0    0  744M  0 raid0
sdd      8:48   0  250M  0 disk
`-md0    9:0    0  744M  0 raid0
sde      8:64   0  250M  0 disk
```

# Создание файловой системы и монтирование массива 

```sh
[root@RAIDZhukov ~] mkfs.ext4 /dev/md0
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=128 blocks, Stripe width=384 blocks
47616 inodes, 190464 blocks
9523 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=195035136
6 block groups
32768 blocks per group, 32768 fragments per group
7936 inodes per group
Superblock backups stored on blocks:
	32768, 98304, 163840

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

[root@RAIDZhukov ~] mount /dev/md0 /root/data
[root@RAIDZhukov ~] df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        489M     0  489M   0% /dev
tmpfs           496M     0  496M   0% /dev/shm
tmpfs           496M  6.7M  489M   2% /run
tmpfs           496M     0  496M   0% /sys/fs/cgroup
/dev/sda1        40G  4.1G   36G  11% /
tmpfs           100M     0  100M   0% /run/user/1000
/dev/md0        717M  1.5M  663M   1% /root/data
[root@RAIDZhukov ~]#
```

# Создаю файл mdadm.conf и прописываю в него конфиг сборки массива при загрузке
```ssh
[root@RAIDZhukov ~] mkdir /etc/mdadm/ && touch /etc/mdadm/mdadm.conf
[root@RAIDZhukov ~] echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
[root@RAIDZhukov ~] mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```
Перезагружаю систему и проверяю что масссив создался
```ssh
ast login: Sun Sep 12 20:03:49 2021 from 10.0.2.2
-bash: warning: setlocale: LC_CTYPE: cannot change locale (UTF-8): No such file or directory
[vagrant@RAIDZhukov ~] sudo -i
[root@RAIDZhukov ~] cat /proc/mdstat
Personalities : [raid0]
md0 : active raid0 sdb[0] sdc[1] sdd[2]
      761856 blocks super 1.2 512k chunks

unused devices: <none>
```
# Создание скрипта
Для всех вышеперечисленных операций добавляю скрипт, который будет создавать массив, добавлять его в mdadm.conf и монтировать непосредственно при создании виртуальной машины. Так же дописал создание пяти GPT партиций. В выводе ниже можно посмотреть ссостояние машины, которая была только что собрана. 
```ssh
maxmzukov@MaximZhukov-MBP DZ2:RAID  vagrant ssh
-bash: warning: setlocale: LC_CTYPE: cannot change locale (UTF-8): No such file or directory
[vagrant@RAIDZhukov ~] sudo -i
[root@RAIDZhukov ~] lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda      8:0    0   40G  0 disk
`-sda1   8:1    0   40G  0 part  /
sdb      8:16   0  250M  0 disk
`-md0    9:0    0  744M  0 raid0 /root/data
sdc      8:32   0  250M  0 disk
`-md0    9:0    0  744M  0 raid0 /root/data
sdd      8:48   0  250M  0 disk
`-md0    9:0    0  744M  0 raid0 /root/data
sde      8:64   0  250M  0 disk
|-sde1   8:65   0   10M  0 part
|-sde2   8:66   0   10M  0 part
|-sde3   8:67   0   10M  0 part
|-sde4   8:68   0   10M  0 part
`-sde5   8:69   0   10M  0 part
[root@RAIDZhukov ~] df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        489M     0  489M   0% /dev
tmpfs           496M     0  496M   0% /dev/shm
tmpfs           496M  6.7M  489M   2% /run
tmpfs           496M     0  496M   0% /sys/fs/cgroup
/dev/sda1        40G  5.1G   35G  13% /
/dev/md0        717M  1.5M  663M   1% /root/data
tmpfs           100M     0  100M   0% /run/user/1000
```
В репозиторий добавляю уже измененный Vagrantfile, скрипт, а также mdadm.conf.
