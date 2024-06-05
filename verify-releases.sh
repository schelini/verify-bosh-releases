#!/bin/bash

# change these to your BOSH IP and SSH key (https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/install-ssh-login.html#log-in-to-the-bosh-director-vm-with-ssh-6)
BOSH_IP=10.225.52.65
BOSH_KEY=/home/ubuntu/bbr.pem

#colors
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

# SSH's into the BOSH director and calculates the shasum for a release
get_shasum () {
  # figure out which shasum to run based on the digest
  case ${2%:*} in

    sha256)
      COMMAND=sha256sum
      ;;

    sha512)
      COMMAND=sha512sum
      ;;

    *)
      COMMAND=shasum
      ;;
  esac

  # gets the shasum
  ssh bbr@$BOSH_IP -i $BOSH_KEY -n 'sudo '"$COMMAND"' $(sudo find /var/vcap/store/blobstore -name '"$BLOB_ID"')' 2>/dev/null | awk '{print $1}'
}

# loops over bosh releases/blobs and checks if the digest equals the shasum
RELEASES=$(bosh releases | awk '{print $1"/"$2}' | tr -d '*')
for release in $RELEASES
do
  echo "RELEASE: $release"
  BLOBS=$(bosh inspect-release $release --column={"Blobstore ID","Digest"} | grep '.*-.*-.*-')

  while IFS= read -r line
  do
    BLOB_ID=$(awk '{print $1}' <<< $line)
    DIGEST=$(awk '{print $2}' <<< $line | cut -f1 -d";")
    echo -n "Checking BLOB $BLOB_ID with DIGEST $DIGEST ... "
    SHASUM=$(get_shasum $BLOB_ID $DIGEST)

    # check if the digest from 'bosh inspect-release' matches the shasum
    if [ $SHASUM = ${DIGEST#*:} ];
    then
      echo -e "${GREEN}SUCCESS!${RESET}"
    else
      echo -e "${RED}FAILED!${RESET}"
    fi
  done <<< $BLOBS
  echo
done
