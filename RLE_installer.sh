#!/usr/bin/env bash
#
# This file is created by bio.logis GIM to setup all dependencies for the Report Layout Engine (RLE).
# It also prepares the rancher client for the deployment to be done.
# Currently only debian and ubuntu is supported!
# Example usage:
# wget https://raw.githubusercontent.com/biologisGIM/rle_setup/master/RLE_installer.sh && sudo bash RLE_installer.bash
#

EXTERNAL_IP=`curl -q https://reg.biologis.com/myip`

echo "If not already done, please provide biologis with your external IP: $EXTERNAL_IP"

if [ -z $1 ]; then
  read -p "Rancher URL: " RANCHER_URL
else
  RANCHER_URL=$1
fi

echo "Installing and setup of the Report Layout Engine. Using $RANCHER_URL"
echo "This takes a moment"

RANCHER_AGENT_VERSION="v1.2.10"

# Stop on any error
set -e

# Update index files to download dependencies
apt-get update
# Install lsb-release, this is usually installed only in some very minimal images this is missing.
apt-get install -y lsb-release

OSNAME=`lsb_release -si`
OSNAME=${OSNAME,,} # to lowerstring (debian, ubuntu)

if [ "$OSNAME" != "ubuntu" ] && [ "$OSNAME" != "debian" ]; then
  echo "Not supported OS ($OSNAME) for this installer script."
  echo "Currently only Debian (>=Wheezy) and Ubuntu (>=16.04) is supported."
  exit
fi

#
# Install dependencies
#

if [ "$OSNAME" == "ubuntu" ]; then
    # Ubuntu 16.04
    echo "Install dependencies for Ubuntu"
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
elif [ "$OSNAME" == "debian" ]; then
    # Debian wheezy
    echo "Install dependencies for Debian"
    apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
fi

echo "Add public key from docker.com"
curl -fsSL https://download.docker.com/linux/$OSNAME/gpg | apt-key add -
apt-key fingerprint 0EBFCD88 | grep "0EBF CD88" # this will fail if nothing returns

echo "Add docker.com repository"
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$OSNAME $(lsb_release -cs) stable"

echo "Installing docker-ce"
apt-get update
apt-get install -y docker-ce

#
# Add biologis_rle user, group and prepare working directories
#
echo "Creating user and prepare working directories"
set +e # Allow "errors" here if the script is called a second time (user/group already exists)
groupadd -g 2000 biologis_rle
useradd -u 2000 -g 2000 -s /usr/sbin/nologin biologis_rle
mkdir -p /mnt/biologis/rle_working_directory
set -e
chown -R biologis_rle:biologis_rle /mnt/biologis/

#
# Install RLE deployment container
#
echo "Deploy docker container to be able to deploy RLE"
docker run -d -e CATTLE_AGENT_IP=${EXTERNAL_IP} --rm --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:${RANCHER_AGENT_VERSION} ${RANCHER_URL}
