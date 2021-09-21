# В качестве Vagrantfile использую этот [образ](https://github.com/nixuser/virtlab/tree/main/nfs_server)
Для начала устанавливаю на сервер nfs 
```ssh
[root@server ~]# yum install nfs-utils -y
...
Upgraded:
  nfs-utils-1:2.3.3-41.el8_4.2.x86_64

Complete!
```
Включаю firewall и добавляю в конфиг сервисы и порты для использования NSF
```ssh
[root@server ~]# firewall-cmd --permanent --add-service=nfs --zone=public
success
[root@server ~]# firewall-cmd --permanent --add-service=mountd --zone=public
success
[root@server ~]# firewall-cmd --permanent --add-service=rpc-bind --zone=public
success
[root@server ~]# firewall-cmd --permanent --add-port=4001/udp --zone=public
success
[root@server ~]# firewall-cmd --permanent --add-port=4001/tcp --zone=public
success
[root@server ~]# firewall-cmd --permanent --add-port=2049/tcp --zone=public
success
[root@server ~]# firewall-cmd --permanent --add-port=2049/udp --zone=public
success
[root@server ~]# firewall-cmd --reload
success
[root@server ~]# firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0 eth1
  sources:
  services: cockpit dhcpv6-client mountd nfs rpc-bind ssh
  ports: 4001/udp 4001/tcp 2049/tcp 2049/udp
  protocols:
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
  ```
Создаю шаренную директорию /data/nfs_share. Так как использовать буду 4ю версию NFS, то сервис включать не нужно. Включаю только nfs-server
```ssh
[root@server ~]# mkdir /data/nfs_share
[root@server ~]# systemctl enable nfs-server
Created symlink /etc/systemd/system/multi-user.target.wants/nfs-server.service → /usr/lib/systemd/system/nfs-server.service.
[root@server ~]# systemctl start nfs-server
```
В файл конфигурации добавляю запись
``ssh 
/data/nfs_share *(rw)
```
Применяю настройки сервера и проверяю их применение

```ssh
[root@server ~]# exportfs -s
/data/nfs_share  *(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
[root@server ~]# exportfs -rav
exporting *:/data/nfs_share
[root@server ~]# showmount -e
Export list for server:
/data/nfs_share *
[root@server ~]# ps axf | grep nfs
  23966 ?        S      0:00  \_ [nfsd]
  23967 ?        S      0:00  \_ [nfsd]
  23968 ?        S      0:00  \_ [nfsd]
  23969 ?        S      0:00  \_ [nfsd]
  23970 ?        S      0:00  \_ [nfsd]
  23971 ?        S      0:00  \_ [nfsd]
  23972 ?        S      0:00  \_ [nfsd]
  23973 ?        S      0:00  \_ [nfsd]
  23987 pts/0    S+     0:00                      \_ grep --color=auto nfs
  23646 ?        Ss     0:00 /usr/sbin/nfsdcld
[root@server ~]# showmount --exports
Export list for server:
/data/nfs_share *
```
Далее на клиенте так же устанавливаю NFS и включаю сервис. После этого создаю директорию и монтирую в ней NFS c созданием записи в /etc/fstab/
```ssh
 mount -t nfs 10.0.0.41:/data/nfs_share /data/share/
 [root@client share]# showmount -e 10.0.0.41
Export list for 10.0.0.41:
/data/nfs_share *
[root@client share]# mount | grep nfs
sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw,relatime)
nfsd on /proc/fs/nfsd type nfsd (rw,relatime)
10.0.0.41:/data/nfs_share on /data/share type nfs4 (rw,relatime,vers=4.2,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.0.0.40,local_lock=none,addr=10.0.0.41)
[root@client share]# echo "10.0.0.41:/data/nfs_share /data/share nfs defaults 0 0">>/etc/fstab
[root@client share]# cat /etc/fstab
...
10.0.0.41:/data/nfs_share /data/share nfs defaults 0 0
[root@client share]
```
Проверяю работоспособность 
```ssh 
[root@server ~]# touch /data/nfs_share/file
[root@client share]# ls -l /data/share/
total 0
-rw-r--r--. 1 root root 0 Sep 19 21:01 file
```

