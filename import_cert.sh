#!/bin/sh
# Copyright Boris Manojlovic boris@steki.net
# License WTFPL
function linkit() {
CERT=$1
(cd /etc/ssl/certs/; ln -sf ${CERT}  $(openssl x509 -hash -noout -in ${CERT}).0)
}

if [ $# -lt 1 ]; then
	echo "#################################################################"
	echo "########## ONLY ADD TRUSTED ROOT CERTIFICATES ###################"
	echo "#################################################################"
	echo "Usage:"
	echo "       $0 pem-certificate.crt"
	exit -1
fi
FULL_PATH_CERT=$1
CERT=$(basename $1)

MD5CERT=$(md5sum ${FULL_PATH_CERT})
if [ -e /etc/ssl/certs/${CERT} ]; then
	echo "Copying file into /etc/ssl/certs/${CERT} and linking"
	if [ ${MD5CERT} = $(md5sum /etc/ssl/certs/${CERT}) ]; then
		echo "Files are same not overwriting"
	else
		echo "#################################################################"
		echo "##### REPLACING EXISTING FILE PLEASE CONFIGRM THIS IS WANTED ####"
		echo "#################################################################"
		echo -n "Yes/[N]o: "
		read -n 1 answer
		echo
		case $answer in
			y|Y)
				set -x
				echo "Replacing CA certificate"
				cp ${FULL_PATH_CERT} /etc/ssl/certs/${CERT}
				linkit ${CERT}
				;;
			*)

				echo "NOT replacing exiting..."
				exit -1
				;;
		esac
	fi
else
	set -x
	cp ${FULL_PATH_CERT} /etc/ssl/certs/${CERT}
	linkit ${CERT}
fi

