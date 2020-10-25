org_port=9051
node_num=2
export FABRIC_CFG_PATH=/root/PROJECTS/fabric_native_dev_project  #core.yaml

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org${node_num}MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${node_num}.example.com/peers/peer0.org${node_num}.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${node_num}.example.com/users/Admin@org${node_num}.example.com/msp
export CORE_PEER_ADDRESS=peer0.org${node_num}.example.com:${org_port}
