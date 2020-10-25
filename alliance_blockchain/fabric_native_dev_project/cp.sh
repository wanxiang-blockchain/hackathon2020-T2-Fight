ROOT=/root/PROJECTS/fabric_native_dev_project/fabric-samples/test-network/organizations/fabric-ca

cp -rf $ROOT/ordererOrg/fabric-ca-server-config.yaml ${PWD}/organizations/fabric-ca/ordererOrg/
cp -rf $ROOT/org1/fabric-ca-server-config.yaml ${PWD}/organizations/fabric-ca/org1/
cp -rf $ROOT/org2/fabric-ca-server-config.yaml ${PWD}/organizations/fabric-ca/org2/
