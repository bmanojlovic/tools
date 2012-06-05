#!/bin/sh
OLDPWD=$(pwd)
if [ $# -lt 2 ]; then
	echo "####################################################"
	echo "### Please provide git url and tag name/checksum ###"
	echo "####################################################"
	echo "Example usage:"
	echo
	echo "	$0 http://gerrit.ovirt.org/p/vdsm v4.9.6"
	echo
	exit
fi
set -x
TEMPDIR=$(mktemp -d /tmp/export-git-tag-XXXXXXX)
GIT_REPO=$1
GIT_VERSION=$2

GIT_NAME=$(basename ${GIT_REPO}|sed -e 's/.git$//g')
GIT_VERSION_CLEAN=$(echo $2|sed -e 's/^v//g'|cut -c -6) # it is ok for git tags and for git checksum as sum is hex...

cd ${TEMPDIR}
git clone ${GIT_REPO} ${GIT_NAME}
mkdir -p ${GIT_NAME}-${GIT_VERSION_CLEAN}
(cd ${GIT_NAME}; git archive ${GIT_VERSION} |tar -vxf - -C ../${GIT_NAME}-${GIT_VERSION_CLEAN})
tar -cvzf ${OLDPWD}/${GIT_NAME}-${GIT_VERSION_CLEAN}.tar.gz ${GIT_NAME}-${GIT_VERSION_CLEAN}

echo rm -rf ${TEMPDIR}
