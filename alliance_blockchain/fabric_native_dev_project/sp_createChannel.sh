#!/bin/bash

echo "----------------------------->remote_peer2: $remote_peer2"

#CHANNEL_NAME="$1"
#echo "$1...$2...$3 !!!!!!!!!!!!!!!!!!!!!!!!"

#if [ $CHANNEL_NAME == "run" ] && [ ! -z $2 ]; then
#    CHANNEL_NAME=$2
#fi

DELAY=3 #"$2"
MAX_RETRY=5 #"$3"
VERBOSE=false #"$4"
#: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

if [ -z $CHANNEL_NAME ]; then
	CHANNEL_NAME=yiping
fi

echo "--------------------CHANNEL: $CHANNEL_NAME!!!--------------------"

# import utils
. envVar.sh

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
	$ssh_peer2 "mkdir -p ${PWD}/channel-artifacts"
fi

createChannelTx() {
	set -x
	configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate channel configuration transaction..."
		exit 1
	fi
	echo

}

createAncorPeerTx() {
        
	for orgmsp in Org1MSP Org2MSP; do
      
	echo "#######    Generating anchor peer update transaction for ${orgmsp}  ##########"
	set -x
	configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${orgmsp}anchors.tx -channelID $CHANNEL_NAME -asOrg ${orgmsp}
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate anchor peer update transaction for ${orgmsp}..."
		exit 1
	fi
	echo
	done
}

createChannel() {
	setGlobals 1
	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block --tls --cafile $ORDERER_CA >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo
	echo "===================== Channel '$CHANNEL_NAME' created ===================== "
	echo
}

# queryCommitted ORG
joinChannel() {
  ORG=$1
  setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block >&log.txt
    res=$?
    set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	echo
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

updateAnchorPeers() {
  ORG=$1
  setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
		peer channel update -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile $ORDERER_CA >&log.txt
    res=$?
    set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
  verifyResult $res "Anchor peer update failed"
  echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME' ===================== "
  sleep $DELAY
  echo
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

function run() {
	export FABRIC_CFG_PATH=${PWD}/configtx  #configtx.yaml

	## Create channeltx
	echo "### Generating channel create transaction '${CHANNEL_NAME}.tx' ###"
	createChannelTx

	## Create anchorpeertx
	echo "### Generating anchor peer update transactions ###"
	createAncorPeerTx

	export FABRIC_CFG_PATH=/root/PROJECTS/fabric_native_dev_project  #core.yaml

	## Create channel
	echo "Creating channel "$CHANNEL_NAME
	createChannel
        
	echo "scp -r channel-artifacts $remote_peer2:${PWD}"
	scp -r channel-artifacts $remote_peer2:${PWD}

	## Join all the peers to the channel
	echo "Join Org1 peers to the channel..."
	joinChannel 1
	echo "Join Org2 peers to the channel..."
	#joinChannel 2
	echo "ssh $remote_peer2 \"cd ${PWD}; export CHANNEL_NAME=$CHANNEL_NAME && . run.sh local_call joinChannel 2\""
	ssh $remote_peer2 "cd ${PWD}; export CHANNEL_NAME=$CHANNEL_NAME && . run.sh local_call joinChannel 2"

	## Set the anchor peers for each org in the channel
	echo "Updating anchor peers for org1..."
	updateAnchorPeers 1
	echo "Updating anchor peers for org2..."
	#updateAnchorPeers 2
	echo "ssh $remote_peer2 \"cd ${PWD};export CHANNEL_NAME=$CHANNEL_NAME && . run.sh local_call updateAnchorPeers 2\""
	ssh $remote_peer2 "cd ${PWD};export CHANNEL_NAME=$CHANNEL_NAME && .  run.sh local_call updateAnchorPeers 2"

	echo
	echo "========= Channel successfully joined =========== "
	echo

	exit 0
}

if [ $1 == "run" ]; then
	run
fi
