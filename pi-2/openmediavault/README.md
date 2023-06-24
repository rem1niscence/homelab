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

## Useful random info

After creating a shared folder with SMB/CIFS, you can connect to it as the root omv user by running 
```bash
 sudo mount -t cifs  //{hostname/ip}/{shared_folder} /{mount_folder}
``` 
