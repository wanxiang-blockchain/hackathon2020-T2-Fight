#!/bin/bash 


# MUST REBOOT AFTER USE THIS, TO AVOID DOCKER DAEMON CANNOT WORK DUE TO IPTABLES WAS CLEANED
systemctl stop firewalld
systemctl stop firewalld.service
systemctl disable firewalld.service

