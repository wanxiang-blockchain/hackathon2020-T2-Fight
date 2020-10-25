#!/bin/bash

force=0

function install_go {

is_installed=`dpkg -s go 2>&1|grep "not installed" |wc -l`
go_exist=`go version 2>&1| grep -E "not found|未找到命令" |wc -l`

if [ $go_exist -gt 0 -o $force -eq 1 ]; then
    echo "INSTALL GO"
    sudo rm -rf /usr/local/go	
    sudo yum -y update && sudo yum -y upgrade
    wget https://golang.google.cn/dl/go1.15.2.linux-amd64.tar.gz
    tar -zvxf go1.15.2.linux-amd64.tar.gz
    
    mv go /usr/local
    
    sed -i '/export GOROOT=\/usr\/local\/go/d' /etc/profile
    sed -i '/export PATH=$PATH:\/usr\/local\/go/d' /etc/profile
    sed -i '/export GOPATH=\/root\/go/d' /etc/profile
    sed -i '/export GOPROXY=https:\/\/goproxy.io/d' /etc/profile
    
    sed -i '$a\export GOROOT=/usr/local/go\' /etc/profile
    sed -i '$a\export PATH=$PATH:/usr/local/go/bin\' /etc/profile
    sed -i '$a\export GOPATH='$HOME'/go\' /etc/profile
    sed -i '$a\export GOPROXY=https://goproxy.io' /etc/profile

fi
}
install_go

if [ ! -d fabric-2.2.1 ]; then
	echo "Download fabric"
	wget https://github.com/hyperledger/fabric/archive/v2.2.1.tar.gz
	tar -zvxf v2.2.1.tar.gz
	./bootstrap.sh 2.2.1 1.4.9
	pushd fabric-samples
	git checkout v2.1.1
	popd	
fi

export PATH=$PATH:${PWD}/fabric-2.2.1/build/bin
