# Notes

* OMV may change your hostname and change some network entries, make sure to check where your network connections are up for whatever you need

To change OMV port:
1. login via SSH
2. run `omv-firstaid`
3. Option-3 "configure workbench settings"
4. select port

## Plugins I'm using

* compose
* downloader
* flashmemory
* filebrowser
* usbbackup
* onedrive

### Mount Samba share in linux

1. `sudo apt install smbclient cifs-utils`
2. `smbclient -L //ip` See which shares are avaiable
3. `mkidr /mnt/mountFolder`

Mount one time
4. `sudo mount -t cifs -o username=serverUserName,password=password //myServerIpAdress/sharename /mnt/myFolder/`

Mount permanently

4. `sudo vi /etc/fstab`
5. `//{ip}/{mount-name} /mnt/myFolder/ cifs uid={user},gid={user},username={usermane},password={password},iocharset=utf8,file_mode=0777,dir_mode=0777`

Note: Remember to add the guest device's IP before attempting to connect
