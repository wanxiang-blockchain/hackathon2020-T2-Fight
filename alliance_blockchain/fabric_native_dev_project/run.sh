#!/bin/bash
modeno=
#single
remote_peer2=192.168.1.136
ssh_peer2="ssh $remote_peer2 "
peer_ca_port1=7054
peer_ca_port2=8054

peer_endorse_port1=7051
peer_endorse_port2=9051
yaml_root=${PWD}
no=2

function test() {
	echo "what!"
}

#export FABRIC_LOGGING_SPEC=DEBUG
#export PATH=$PATH:/root/PROJECTS/fabric_native_dev_project/fabric-2.2.1/build/bin

if [ -z $CHANNEL_NAME ]; then 
  CHANNEL_NAME=yiping
fi

function build_all() {
	
	mkdir -p build/bin 
	rm -rf build/bin/*
        make  clean
	make  configtxgen
       	make  configtxlator
       	make  cryptogen
       	make  discover
	make  idemixgen
	make  orderer
	make  peer
	cp -rf build/bin/* /usr/bin
}

function set_env() {
	node_num=$1
        eval org_port=\$peer_endorse_port${node_num}
	export FABRIC_CFG_PATH=/root/PROJECTS/fabric_native_dev_project  #core.yaml
	
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_LOCALMSPID="Org${node_num}MSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${node_num}.example.com/peers/peer0.org${node_num}.example.com/tls/ca.crt
	export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${node_num}.example.com/users/Admin@org${node_num}.example.com/msp
	export CORE_PEER_ADDRESS=localhost:${org_port}
}

#### FOR MULTIPLE 2 NODES #####

function remote_join_swarm() {
	echo>${PWD}/.env 
	echo "COMPOSE_PROJECT_NAME=net">>${PWD}/.env
	echo "IMAGE_TAG=latest">>${PWD}/.env
	echo "SYS_CHANNEL=system-channel">>${PWD}/.env

	. ${PWD}/.env
	
        echo "remote_join_swarm"
	peerNo=$1
	eval echo \${remote_peer${peerNo}}
	DockerLeave="docker swarm leave -f"
	DockerJoin=`docker swarm join-token manager |grep "docker swarm join "`
	
        echo "ping \${remote_peer${peerNo}} -c 1"
	eval ping \${remote_peer${peerNo}} -c 1
	if [ $? -ne 0 ]; then
		exec -c echo "wrong : remote cannot be reached."
	fi
	
	echo "NOW REMOTE LEAVE START"
	eval ssh \$remote_peer${peerNo} "$DockerLeave"
	echo "NOW REMOTE JOIN START"
	echo "eval ssh \$remote_peer${peerNo} \"$DockerJoin\""
	eval ssh \$remote_peer${peerNo} "$DockerJoin"
	echo "NOW REMOTE JOIN ALL DONE"
}

function remote_leave_swarm() {
	peerNo=$1
	DockerLeave="docker swarm leave -f"
	echo "ping \${remote_peer${peerNo}} -c 1"
	eval ping \${remote_peer${peerNo}} -c 1
	if [ $? -ne 0 ]; then
		exec -c echo "wrong : remote cannot be reached."
	fi
	echo "TRY LEAVE DOCKER REMOTE"
	eval ssh \${remote_peer${peerNo}} $DockerLeave
	docker swarm leave -f
	echo "TRY LEAVE DOCKER DONE"
}

function join_docker_swarm() {
	echo>${PWD}/.env 
	echo "COMPOSE_PROJECT_NAME=net">>${PWD}/.env
	echo "IMAGE_TAG=latest">>${PWD}/.env
	echo "SYS_CHANNEL=system-channel">>${PWD}/.env

	. ${PWD}/.env
	
	scp ${PWD}/.env $remote_peer2:${PWD}/

        docker swarm init
	peerNo=$1
	
	eval echo "ping \${remote_peer${peerNo}} -c 1"
	eval ping \${remote_peer${peerNo}} -c 1
	if [ $? -ne 0 ]; then
		exec -c echo "wrong : remote cannot be reached:\${remote_peer${peerNo}}"
	fi
	
	echo "NOW !!!! JOIN REMOTE DOCKER !!!!!"
	remote_join_swarm 2
}

function createOrg {
  set +x
  number=$1
  eval org_port=\$peer_ca_port${number}
  echo "HERE!!!!--->CREATE ORG"	
  echo
	echo "Enroll the CA admin"
  echo
	mkdir -p organizations/peerOrganizations/org${number}.example.com/

	export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/org${number}.example.com/
#  rm -rf $FABRIC_CA_CLIENT_HOME/fabric-ca-client-config.yaml
#  rm -rf $FABRIC_CA_CLIENT_HOME/msp

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:${org_port} --caname ca-org${number} --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-'${org_port}'-ca-org'${number}'.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-'${org_port}'-ca-org'${number}'.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-'${org_port}'-ca-org'${number}'.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-'${org_port}'-ca-org'${number}'.pem
    OrganizationalUnitIdentifier: orderer' > ${PWD}/organizations/peerOrganizations/org${number}.example.com/msp/config.yaml

  echo
	echo "Register peer0"
  echo
  set -x
	fabric-ca-client register --caname ca-org${number} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

  echo
  echo "Register user"
  echo
  set -x
  fabric-ca-client register --caname ca-org${number} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

  echo
  echo "Register the org admin"
  echo
  set -x
  fabric-ca-client register --caname ca-org${number} --id.name org${number}admin --id.secret org${number}adminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

	mkdir -p organizations/peerOrganizations/org${number}.example.com/peers
  mkdir -p organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com

  echo
  echo "## Generate the peer0 msp"
  echo
  set -x
	fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${org_port} --caname ca-org${number} -M ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/msp --csr.hosts peer0.org${number}.example.com --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/msp/config.yaml

  echo
  echo "## Generate the peer0-tls certificates"
  echo
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${org_port} --caname ca-org${number} -M ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls --enrollment.profile tls --csr.hosts peer0.org${number}.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x


  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/ca.crt
  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/signcerts/* ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/server.crt
  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/keystore/* ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/server.key

  mkdir ${PWD}/organizations/peerOrganizations/org${number}.example.com/msp/tlscacerts
  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/org${number}.example.com/msp/tlscacerts/ca.crt

  mkdir ${PWD}/organizations/peerOrganizations/org${number}.example.com/tlsca
  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/org${number}.example.com/tlsca/tlsca.org${number}.example.com-cert.pem

  mkdir ${PWD}/organizations/peerOrganizations/org${number}.example.com/ca
  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/peers/peer0.org${number}.example.com/msp/cacerts/* ${PWD}/organizations/peerOrganizations/org${number}.example.com/ca/ca.org${number}.example.com-cert.pem

  mkdir -p organizations/peerOrganizations/org${number}.example.com/users
  mkdir -p organizations/peerOrganizations/org${number}.example.com/users/User1@org${number}.example.com

  echo
  echo "## Generate the user msp"
  echo
  set -x
	fabric-ca-client enroll -u https://user1:user1pw@localhost:${org_port} --caname ca-org${number} -M ${PWD}/organizations/peerOrganizations/org${number}.example.com/users/User1@org${number}.example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/org${number}.example.com/users/User1@org${number}.example.com/msp/config.yaml

  mkdir -p organizations/peerOrganizations/org${number}.example.com/users/Admin@org${number}.example.com

  echo
  echo "## Generate the org admin msp"
  echo
  set -x
	fabric-ca-client enroll -u https://org${number}admin:org${number}adminpw@localhost:${org_port} --caname ca-org${number} -M ${PWD}/organizations/peerOrganizations/org${number}.example.com/users/Admin@org${number}.example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/org${number}/tls-cert.pem
  set +x

  cp ${PWD}/organizations/peerOrganizations/org${number}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/org${number}.example.com/users/Admin@org${number}.example.com/msp/config.yaml

}

function createOrgs() {
  echo "CREATE PLACE 1"
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi
  echo "CREATE PLACE 2"

  # Create crypto material using Fabric CAs
  if [ "$CRYPTO" == "Certificate Authorities" ]; then

    echo
    echo "##########################################################"
    echo "##### Generate certificates using Fabric CA's ############"
    echo "##########################################################"

    docker-compose -f $yaml_root/docker/docker-compose-ca.yaml up -d 2>&1

    . organizations/fabric-ca/registerEnroll.sh

    echo "##########################################################"
    echo "############ Create Org1 Identities ######################"
    echo "##########################################################"

    createOrg1

    echo "##########################################################"
    echo "############ Create Org2 Identities ######################"
    echo "##########################################################"

    createOrg2

    echo "##########################################################"
    echo "############ Create Orderer Org Identities ###############"
    echo "##########################################################"

    createOrderer

  fi
  
  #sleep 3
  #echo
  #echo "Generate CCP files for Org1 and Org2"
  #./organizations/ccp-generate.sh
}

function createOrgs_multiple() {
  echo "createOrgs_multiple 1!!!"
  
  cp /root/PROJECTS/fabric_native_dev_project/fabric-2.2.1/build/bin/* /usr/bin/
  cp /root/PROJECTS/fabric_native_dev_project/fabric-samples/bin/fabric-ca-* /usr/bin/
  scp /root/PROJECTS/fabric_native_dev_project/fabric-samples/bin/fabric-ca-* $remote_peer2:/usr/bin/
  scp /root/PROJECTS/fabric_native_dev_project/fabric-2.2.1/build/bin/* $remote_peer2:/usr/bin/

  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi
  echo "createOrgs_multiple 2!!!"
	
    if [ 1 -eq 2 ]; then	
	pushd ${PWD}/organizations/fabric-ca
	#make sure CN should be all the same
	sed -i 's/^\(.*cn: \).*/\1 fabric-ca-server/g' ordererOrg/fabric-ca-server-config.yaml
	sed -i 's/^\(.*- C: \).*/\1 US/g' ordererOrg/fabric-ca-server-config.yaml
	sed -i 's/^\(.*ST:\).*/\1 North Carolina/g' ordererOrg/fabric-ca-server-config.yaml
	sed -i 's/^\(.*L: \).*/\1 North Carolina/g' ordererOrg/fabric-ca-server-config.yaml
	sed -i 's/^\(.*O: \).*/\1 Hyperledger/g' ordererOrg/fabric-ca-server-config.yaml
	sed -i 's/^\(.*OU:\).*/\1 Fabric/g' ordererOrg/fabric-ca-server-config.yaml

	sed -i 's/^\(.*cn: \).*/\1 fabric-ca-server/g' org1/fabric-ca-server-config.yaml
	sed -i 's/^\(.*- C: \).*/\1 US/g' org1/fabric-ca-server-config.yaml
	sed -i 's/^\(.*ST: \).*/\1 North Carolina/g' org1/fabric-ca-server-config.yaml
	sed -i 's/^\(.*L: \).*/\1 North Carolina/g' org1/fabric-ca-server-config.yaml
	sed -i 's/^\(.*O: \).*/\1 Hyperledger/g' org1/fabric-ca-server-config.yaml
	sed -i 's/^\(.*OU:\).*/\1 Fabric/g' org1/fabric-ca-server-config.yaml

	sed -i 's/^\(.*cn: \).*/\1 fabric-ca-server/g' org2/fabric-ca-server-config.yaml
	sed -i 's/^\(.*- C: \).*/\1 US/g' org2/fabric-ca-server-config.yaml
	sed -i 's/^\(.*ST: \).*/\1 North Carolina/g' org2/fabric-ca-server-config.yaml
	sed -i 's/^\(.*L: \).*/\1 North Carolina/g' org2/fabric-ca-server-config.yaml
	sed -i 's/^\(.*O: \).*/\1 Hyperledger/g' org2/fabric-ca-server-config.yaml
	sed -i 's/^\(.*OU:\).*/\1 Fabric/g' org2/fabric-ca-server-config.yaml

	scp ordererOrg/fabric-ca-server-config.yaml $remote_peer2:${PWD}/ordererOrg/
	scp org1/fabric-ca-server-config.yaml $remote_peer2:${PWD}/org1/
	scp org2/fabric-ca-server-config.yaml $remote_peer2:${PWD}/org2/
	popd
   fi	
  # Create crypto material using Fabric CAs
  #if [ "$CRYPTO" == "Certificate Authorities" ]; then

    echo
    echo "##########################################################"
    echo "##### Generate certificates using Fabric CA's ############"
    echo "##########################################################"
    
    echo "docker-compose -f $yaml_root/docker/docker-compose-ca-orderer.yaml up -d 2>&1"
    docker-compose -f $yaml_root/docker/docker-compose-ca-orderer.yaml up -d 2>&1
    
    echo "docker-compose -f $yaml_root/docker/docker-compose-ca-peer1.yaml up -d 2>&1"
    docker-compose -f $yaml_root/docker/docker-compose-ca-peer1.yaml up -d 2>&1
    
    echo "$ssh_peer2 \"cd ${PWD}; docker-compose -f $yaml_root/docker/docker-compose-ca-peer2.yaml up -d 2>&1\" "
    $ssh_peer2 "cd ${PWD}; docker-compose -f $yaml_root/docker/docker-compose-ca-peer2.yaml up -d 2>&1"
    #$ssh_peer2 " . $yaml_root/organizations/fabric-ca/registerEnroll.sh"
    sleep 1

    . organizations/fabric-ca/registerEnroll.sh

    sleep 10

    echo "##########################################################"
    echo "############ Create Org1 Identities ######################"
    echo "##########################################################"

    createOrg 1

    echo "##########################################################"
    echo "############ Create Org2 Identities ######################"
    echo "##########################################################"
      
    #./run.sh remote_call createOrg 2 $remote_peer2
    echo "ssh $remote_peer2 \"${PWD}/./run.sh local_call createOrg 2\""
    ssh $remote_peer2 "cd ${PWD}; ./run.sh local_call createOrg 2"
    
    scp -r ./organizations/fabric-ca/org1 $remote_peer2:${PWD}/organizations/fabric-ca/
    scp -r $remote_peer2:${PWD}/organizations/fabric-ca/org2 ${PWD}/organizations/fabric-ca/

    scp -r ./organizations/fabric-ca/ordererOrg $remote_peer2:${PWD}/organizations/fabric-ca/
    
    scp -r ./organizations/peerOrganizations/org1.example.com $remote_peer2:${PWD}/organizations/peerOrganizations/
    scp -r $remote_peer2:${PWD}/organizations/peerOrganizations/org2.example.com ${PWD}/organizations/peerOrganizations
    
 
    echo "##########################################################"
    echo "############ Create Orderer Org Identities ###############"
    echo "##########################################################"

    createOrderer
    scp -r ./organizations/ordererOrganizations $remote_peer2:${PWD}/organizations/ 

  #fi

  echo
  echo "Generate CCP files for Org1 and Org2"
  ./organizations/ccp-generate.sh 1
  $ssh_peer2 "cd ${PWD}; ./organizations/ccp-generate.sh 2"
  scp $remote_peer2:${PWD}/organizations/peerOrganizations/org2.example.com/connection* ${PWD}/organizations/peerOrganizations/org2.example.com/
  scp ${PWD}/organizations/peerOrganizations/org1.example.com/connection* $remote_peer2:${PWD}/organizations/peerOrganizations/org1.example.com/
}

function createConsortium() {

  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "#########  Generating Orderer Genesis block ##############"

  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  export FABRIC_CFG_PATH=${PWD}/configtx
  #mkdir -p ./organizations/peerOrganizations/org2.example.com/msp/cacerts
  #scp $remote_peer2:${PWD}/organizations/peerOrganizations/org2.example.com/msp/cacerts/* ./organizations/peerOrganizations/org2.example.com/msp/cacerts/
  #scp $remote_peer2:${PWD}/organizations/peerOrganizations/org2.example.com/msp/*.yaml ./organizations/peerOrganizations/org2.example.com/msp/
  
  #scp -r $remote_peer2:${PWD}/organizations/peerOrganizations/org2.example.com ./organizations/peerOrganizations/
  #scp -r ./organizations/peerOrganizations/org1.example.com $remote_peer2:${PWD}/organizations/peerOrganizations/
  #scp -r ./organizations/ordererOrganizations $remote_peer2:${PWD}/organizations/

  set -x
  configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  scp -r ./system-genesis-block $remote_peer2:${PWD}
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
}

function install_seperate_2_nodes () {
	join_docker_swarm 2
        
        createOrgs_multiple

  
  	createConsortium
	docker-compose -f docker/docker-compose-orderer.yaml up -d 2>&1
        docker-compose -f docker/docker-compose-peer1.yaml up -d 2>&1
	$ssh_peer2 "cd ${PWD}; docker-compose -f docker/docker-compose-peer2.yaml up -d 2>&1"
}

function set_chaincode_env() {
    org=$1 
    if [ $org -eq 1 ]; then
        PEER_PORT=7051
    else
        PEER_PORT=9051
    fi
    
    export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org${org}MSP
    eval export CORE_PEER_TLS_ROOTCERT_FILE=\$PEER0_ORG${org}_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${org}.example.com/users/Admin@org${org}.example.com/msp
    export CORE_PEER_ADDRESS=peer0.org${org}.example.com:$PEER_PORT

    if [ ! -z $2 ]; then
	    echo "export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
	    echo "export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

	    echo "export CORE_PEER_TLS_ENABLED=true"
	    echo "export CORE_PEER_LOCALMSPID=Org${org}MSP"
	    eval echo "export CORE_PEER_TLS_ROOTCERT_FILE=\$PEER0_ORG${org}_CA"
	    echo "export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${org}.example.com/users/Admin@org${org}.example.com/msp"
	    echo "export CORE_PEER_ADDRESS=peer0.org${org}.example.com:$PEER_PORT"
    fi	
}



WORK_DIR=${PWD}
if [ ! -z $modeno ]; then
    WORK_DIR=./fabric-samples/test-network
fi

case $1 in
"build")
	pushd fabric-2.2.1
	build_all
	popd
;;
 "up" ) #single mode
	pushd $WORK_DIR;
	./network.sh up -ca -verbose
	popd
;;
 "sp_up") # multi-vm mode
	install_seperate_2_nodes 2
	exec -c echo ""
;;
 "sp_down") # multi-vm mode
	remote_leave_swarm 2
        $ssh_peer2 "cd ${PWD} && ./run.sh down"
	./network.sh down
	docker ps -aq|xargs docker rm -f
	$ssh_peer2 "docker ps -aq|xargs docker rm -f; rm -rf ${PWD}/system-genesis-block"
	$ssh_peer2 "cd ${PWD}; ./network.sh down"
	rm -rf system-genesis-block
	rm -rf /var/lib/docker/volumes/docker_*
	rm -rf /var/lib/docker/volumes/net_*
	$ssh_peer2 "cd /var/lib/docker/volumes; rm -rf docker_*; rm -rf net_*"
	mkdir -p /var/lib/docker/volumes/net_orderer.example.com/_data
	mkdir -p /var/lib/docker/volumes/net_peer0.org1.example.com/_data
	mkdir -p /var/lib/docker/volumes/net_peer0.org2.example.com/_data
	$ssh_peer2 "cd /var/lib/docker/volumes;  mkdir -p /var/lib/docker/volumes/net_orderer.example.com/_data"
	$ssh_peer2 "cd /var/lib/docker/volumes;  mkdir -p /var/lib/docker/volumes/net_peer0.org1.example.com/_data"
	$ssh_peer2 "cd /var/lib/docker/volumes; mkdir -p /var/lib/docker/volumes/net_peer0.org2.example.com/_data"
	
;;
 "down") #single mode
	pushd $WORK_DIR;
	./network.sh down
	docker ps -aq|xargs docker rm -f
	$ssh_peer2 "docker ps -aq|xargs docker rm -f"
	popd
;;
 "new_ch")
	pushd $WORK_DIR;
	if [ ! -z $2 ]; then
		CHANNEL_NAME=$2
	fi 
	pushd $WORK_DIR;
	export FABRIC_CFG_PATH=${PWD}/configtx
	echo "==== CREATE CHANNEL : $CHANNEL_NAME ===="
	scripts/./createChannel.sh $CHANNEL_NAME
	popd
;;
"sp_new_ch")
	pushd $WORK_DIR;
	if [ ! -z $2 ]; then
		CHANNEL_NAME=$2
	fi 
	pushd $WORK_DIR;
	#. sp_createChannel.sh $CHANNEL_NAME
	export FABRIC_CFG_PATH=${PWD}/configtx
	echo "==== CREATE CHANNEL : $CHANNEL_NAME ===="
	. sp_createChannel.sh run $CHANNEL_NAME
	popd
	
;;
"info")
	pushd $WORK_DIR;
	
	if [ ! -z $2 ]; then
		CHANNEL_NAME=$2
	fi 
	set_env 1
	echo
	echo "====PPER 1: GET CHANNEL: $CHANNEL_NAME ===="
	echo
	peer channel getinfo -c $CHANNEL_NAME
	echo
	set_env 2
	echo
	echo "====PEER 2: GET CHANNEL: $CHANNEL_NAME ===="
	echo

	if [ ! -z $modeno ]; then
		peer channel getinfo -c $CHANNEL_NAME
	else
		echo "$ssh_peer2 \"cd ${PWD};. org2_env.sh && peer channel getinfo -c $CHANNEL_NAME\" "
		$ssh_peer2 "cd ${PWD};. org2_env.sh && peer channel getinfo -c $CHANNEL_NAME"
	fi

	echo

	popd
;;
"get_chs")
	pushd $WORK_DIR;
	
	if [ ! -z $2 ]; then
		CHANNEL_NAME=$2
	fi 
	set_env 1
	echo
	echo "====PPER 1: GET EXISTING CHANNELS: $CHANNEL_NAME ===="
	echo
	peer channel list
	echo
	set_env 2
	echo
	echo "====PEER 2: GET EXISTING CHANNELS: $CHANNEL_NAME ===="
	echo
	if [ ! -z mode ]; then
		peer channel list
	else
		$ssh_peer2 "peer channel list"
	fi
	echo

	popd
;;
"get_block")
	return
	pushd $WORK_DIR;
	
	if [ ! -z $2 ]; then
		CHANNEL_NAME=$2
	fi 
	
	echo
	echo "====GET CHANNEL: $CHANNEL_NAME ===="
	echo
	echo "====PPER 1: GET CHANNEL: $CHANNEL_NAME ===="
	echo
	set_env 1
	peer channel getinfo -c $CHANNEL_NAME
	echo
	echo "====PPER 2: GET CHANNEL: $CHANNEL_NAME ===="
	echo
	set_env 2

	if [ ! -z $modeno ]; then
		peer channel getinfo -c $CHANNEL_NAME
	else
		echo "$ssh_peer2 \"cd ${PWD};. org2_env.sh && peer channel getinfo -c $CHANNEL_NAME\" "
		$ssh_peer2 "cd ${PWD};. org2_env.sh && peer channel getinfo -c $CHANNEL_NAME"
	fi
	echo
	popd
;;
"deploy")
	 export FABRIC_CFG_PATH=${PWD}
         shift
         CHANNEL=$1
         CONTRACT=$2
	 ORG=$3
	 PACKID=$4
         
	 if [ -z $CHANNEL ]; then
             CHANNEL=yiping
	 fi
	 if [ -z $CONTRACT ]; then
             CONTRACT=yiping
	 fi
         if [ -z $ORG ]; then
             ORG=1
         fi 
          
	 export GO111MODULE=on                                                                                        
         go env -w GO111MODULE=on                                                                                     
         unset GOPROXY
         go env -w GOPROXY=https://goproxy.cn,direct                                                                  
         export GOPROXY=https://goproxy.cn
         
         pushd contract
             rm -rf go.sum go.mod *.tar.gz
             #go mod init github.com/lyp830414/repo_fabric_v221
	     go mod init github.com/hyperledger/fabric
             go mod vendor
 	 popd
	 set_chaincode_env $ORG verbose
                 echo "===========NOW DO ON NODE PEER${ORG}=============================="
		 if [ $ORG -eq 1 ]; then
			 echo "peer lifecycle chaincode package $CONTRACT.tar.gz --path contract --lang golang --label $CONTRACT"
			 peer lifecycle chaincode package ${CONTRACT}.tar.gz --path contract --lang golang --label $CONTRACT
			 if [ ! -f ${CONTRACT}.tar.gz ]; then
			      exec -c echo "package contract failed!!!! not found ${CONTRACT}.tar.gz"
			 fi
			
		         scp $CONTRACT.tar.gz $remote_peer2:${PWD}
		 fi
		
		 echo "peer lifecycle chaincode install ${CONTRACT}.tar.gz" #--peerAddresses peer0.org1.example.com:7051"
		 #peer lifecycle chaincode install ${CONTRACT}.tar.gz #--peerAddresses peer0.org1.example.com:7051 
		 pack_id_tmp=`peer lifecycle chaincode install ${CONTRACT}.tar.gz 2>&1 | grep "Chaincode code package identifier: "|awk '{print $NF}'`
		   
           	 pack_id=`peer lifecycle chaincode queryinstalled|grep ${CHANNEL}|awk '{print $3}'| sed 's/','//g'`
		 #newversion=`peer lifecycle chaincode querycommitted -C ${CHANNEL}|awk  '{if(NR==2)print $6}' | awk -F ',' '{print $1}'`
		     
		     if [ -z "$pack_id" ]; then
			  echo "HERE 1"
		          if [ ! -z "$pack_id_tmp" ]; then
			      echo "HERE 2"
			      pack_id=$pack_id_tmp
			  else
			        echo "HERE 3"
			        peer lifecycle chaincode install ${CONTRACT}.tar.gz
				exec -c echo "pack id failed: peer lifecycle chaincode install ${CONTRACT}.tar.gz"
                          fi
			  
		     fi
			
		     if [ $ORG -eq 2 ] && [ ! -z $PACKID ];then
		         pack_id=$PACKID
                     fi
		     newversion=`peer lifecycle chaincode querycommitted -C ${CHANNEL}| awk  '{if(NR==2)print $6}' | awk -F ',' '{print $1}'`
	            if [ -z $newversion ]; then
			 #not committed
			 newversion=1
		     else
			#has been committed before
		        let newversion+=1
		     fi

                 echo "peer lifecycle chaincode queryinstalled | grep $CONTRACT"
		 peer lifecycle chaincode queryinstalled | grep $CONTRACT
		 
		 peer channel getinfo -c $CHANNEL
	         orderer_msp=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp
		 echo "peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $orderer_msp/tlscacerts/tlsca.example.com-cert.pem --channelID $CHANNEL --name $CONTRACT --version 1  --init-required --package-id $pack_id --sequence $newversion"
                 peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $orderer_msp/tlscacerts/tlsca.example.com-cert.pem --channelID $CHANNEL --name $CONTRACT --version 1 --init-required --package-id $pack_id --sequence $newversion
                 echo "+++++ CHECK COMMITS ++++++"
		 peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL --name $CONTRACT --version 1 --sequence $newversion --output json --init-required

		 #echo "===========NOW DO ON NODE PEER2=============================="
	         if [ $ORG -eq 1 ]; then
		    	 scp $CONTRACT.tar.gz $remote_peer2:${PWD}
			 $ssh_peer2 "cd ${PWD} && . run.sh deploy $CHANNEL $CONTRACT 2 $pack_id"
	         fi
		 
		 if [ $ORG -eq 2 ]; then
			 echo "+++++ NOW DO COMMITS ++++++"
			 PEER_ADDR_CERTS=" --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
			 PEER_ADDR_CERTS+=" --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
			 peer lifecycle chaincode commit -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $orderer_msp/tlscacerts/tlsca.example.com-cert.pem --channelID ${CHANNEL} --name ${CONTRACT} $PEER_ADDR_CERTS --version 1 --sequence $newversion --init-required
		         
			 echo "+++++ NOW CHECK AGAIN ++++++"
		         peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL --name $CONTRACT --version 1 --sequence $newversion --output json --init-required
		 fi
#;;
#"call")
	set_chaincode_env 1 verbose
        orderer_msp=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp
	PEER_ADDR_CERTS=" --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
	PEER_ADDR_CERTS+=" --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
	CORE_PEER_TLS_ENABLED=true
       echo "peer chaincode invoke -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $orderer_msp/tlscacerts/tlsca.example.com-cert.pem -C ${CHANNEL} -n ${CONTRACT} $PEER_ADDR_CERTS --isInit -c '{\"Args\":[\"Init\",\"\"]}'"
        eval "peer chaincode invoke -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls $CORE_PEER_TLS_ENABLED --cafile $orderer_msp/tlscacerts/tlsca.example.com-cert.pem -C ${CHANNEL} -n ${CONTRACT} $PEER_ADDR_CERTS --isInit -c '{\"Args\":[\"Init\",\"\"]}'"
	# peer chaincode invoke -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile /root/PROJECTS/fabric_native_dev_project/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C yiping -n yipinga  --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /root/PROJECTS/fabric_native_dev_project/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /root/PROJECTS/fabric_native_dev_project/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --isInit -c '{"Args":["set","A","5"]}'
	#  peer chaincode query -C yiping -n yipinga -c '{"Args": ["get","A"]}' 
;;
"query")
	CHANNEL=$2
	CONTRACT=$3
	PARAM="{\"Args\": [\"get_table\",\"cc\",\"abc\"]}"
	set_chaincode_env 1 verbose
	eval echo "peer chaincode query -C $CHANNEL -n $CONTRACT -c '$PARAM'"
	eval "peer chaincode query -C $CHANNEL -n $CONTRACT -c '$PARAM'"
;;
"system")
	shift
	case $1 in
	"cscc")
		pushd $WORK_DIR;
		
		if [ ! -z $2 ]; then
			CHANNEL_NAME=$2
		fi 
		
		echo
		echo "====PPER 1: GET CSCC ON CHANNEL : $CHANNEL_NAME ===="
		echo
		set_env 1
			#get last configured block
			peer chaincode query -C "$CHANNEL_NAME" -n cscc -c '{"Args":["GetConfigBlock", "'$CHANNEL_NAME'"]}'
		echo
		echo "====PPER 2: GET CSCC ON CHANNEL: $CHANNEL_NAME ===="
		echo
		set_env 2
			#get last configured block
			peer chaincode query -C "$CHANNEL_NAME" -n cscc -c '{"Args":["GetConfigBlock", "'$CHANNEL_NAME'"]}'
		echo
		popd
		;;
	"qscc")
		pushd $WORK_DIR;
		
		if [ ! -z $2 ]; then
			CHANNEL_NAME=$2
		fi 
		
		echo
		echo "====PPER 1: GET QSCC ON CHANNEL : $CHANNEL_NAME ===="
		echo
		set_env 1
		#get last configured block
		peer chaincode query -C "$CHANNEL_NAME" -n qscc -c '{"Args":["GetBlockByNumber", "'$CHANNEL_NAME'", "2"]}'
		echo
		echo "====PPER 2: GET QSCC ON CHANNEL: $CHANNEL_NAME ===="
		echo
		set_env 2
		#get last configured block
		peer chaincode query -C "$CHANNEL_NAME" -n qscc -c '{"Args":["GetBlockByNumber", "'$CHANNEL_NAME'", "2"]}'
		echo
		popd
		;;
	esac
    ;;
    "local_call")
	echo "here!!"
	funcname=$2
	orgno=$3
	orgip=$4
	. $yaml_root/organizations/fabric-ca/registerEnroll.sh
	. sp_createChannel.sh $2 $3
        $funcname $orgno
        ;;
    "remote_call")
	funcname=$1
	orgno=$2
	orgip=$3
	echo "-->ssh $orgip 'cd ${PWD}; ./run.sh local_call $funcname $orgno'"
	set +x
	ssh $orgip "cd ${PWD}; ./run.sh local_call $funcname $orgno"
	#ssh $orgip 'ifconfig|grep 192'
	set -x
	;;
esac
