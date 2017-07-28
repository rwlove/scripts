#!/bin/bash -x

echo "OPTERR is: $OPTERR"

while getopts "n:b:m:v:" opt; do
    case $opt in
	n)
	    CONTAINER_NAME=$OPTARG
	    ;;
	b)
	    BRIDGE=$OPTARG
	    ;;
	m)
	    MAC_ADDRESS=$OPTARG
	    ;;
	v)
	    VETH_NAME=$OPTARG
	    ;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	    ;;
    esac
done

echo "Name is: $CONTAINER_NAME"
echo "Bridge is: $BRIDGE"
echo "MAC Address is: $MAC_ADDRESS"

if [ "${VETH_NAME}" == "" ] ; then
    VETH_NAME=${CONTAINER_NAME}
fi

echo "veth name is: $VETH_NAME"

##
# TODO
#
# - Put settings.conf file with MAC_ADDRESS in the continer's
#   root directory.
#
# - error handling
#
# - more elegant handling of MAC_ADDRESS
## 

ID=`docker ps | grep Up | grep "$CONTAINER_NAME" | cut -d ' ' -f 1`

echo "ID is: $ID"

# Delete previous veth pair
echo "Deleting $VETH_NAME-ext"
ip link delete $VETH_NAME-ext
echo "Deleting $VETH_NAME-int"
ip link delete $VETH_NAME-int

# Create veth pair
echo "Creating the veth pair"
ip link add $VETH_NAME-int type veth peer name $VETH_NAME-ext

# Remove the defaut route in the container
#echo "Remove the default route in the container"
#nsenter -t $(docker-pid $ID) -n ip route del default

# Add the internal interface to the container
echo "Add the internal interface to the container"
ip link set netns $(docker-pid $ID) dev $VETH_NAME-int

# Set the internal MAC Address
echo "Set the internal MAC Address"
nsenter -t $(docker-pid $ID) -n ip link set $VETH_NAME-int address $MAC_ADDRESS

# Bring the container's internal veth interface up
echo "Bring the container's internal veth interface up"
nsenter -t $(docker-pid $ID) -n ip link set $VETH_NAME-int up

# Add the external veth to the bridge
echo "Add the external veth to the bridge"
brctl addif $BRIDGE $VETH_NAME-ext

# Bring the external veth interface up
echo "Bring the external veth interface up"
ip link set $VETH_NAME-ext up

# Get DHCP Address in the container
echo "Get DHCP Address in the container"
nsenter -t $(docker-pid $ID) -n -- dhclient $VETH_NAME-int

# Kill the dhclient process (dhcp server (dhcpd) is configured to give a negative
# renewal peroid to containers so they should never need to renew their IPs.
echo "Kill dhclient"
pkill -f "dhclient $VETH_NAME-int"
