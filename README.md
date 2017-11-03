# VietCLI-D
 
VietCLID is an edition of VietCLI for Docker container. It used vietduong/centos-nginx-phpfpm as default docker image.

### Installation

```
$ sudo bash -c "curl -sSL https://raw.githubusercontent.com/vietcli/vietclid-docker-controller/master/vietcli-d.sh > /usr/local/sbin/vietcli-d"
``` 
OR
```
$ wget -q --no-check-certificate https://raw.githubusercontent.com/vietcli/vietclid-docker-controller/master/vietcli-d.sh
$ chmod +x vietcli-d.sh
$ sudo mv vietcli-d.sh /usr/local/sbin/vietcli-d
```

### Usage

```
$ sudo vietcli-d create www.my-domain.com
```
**Hope it useful!**

