#!/usr/bin/env bash
#
# (C) Copyright 2019, Xilinx, Inc.
#
#!/usr/bin/env bash

install_xrt() {
    echo "Download XRT installation package"
    wget -cO - "https://www.xilinx.com/bin/public/openDownload?filename=$XRT_PACKAGE" > /tmp/$XRT_PACKAGE
    
    echo "Install XRT"
    if [[ "$OSVERSION" == "ubuntu-16.04" ]] || [[ "$OSVERSION" == "ubuntu-18.04" ]] || [[ "$OSVERSION" == "ubuntu-20.04" ]]; then
        echo "Ubuntu XRT install"
        echo "Installing XRT dependencies..."
        apt update
        echo "Installing XRT package..."
        apt install -y /tmp/$XRT_PACKAGE
    elif [[ "$OSVERSION" == "centos-7" ]] ; then
        echo "CentOS 7 XRT install"
        echo "Installing XRT dependencies..."
        yum install -y epel-release
        echo "Installing XRT package..."
        yum install -y /tmp/$XRT_PACKAGE
    elif [[ "$OSVERSION" == "centos-8" ]]; then
        echo "CentOS 8 XRT install"
        echo "Installing XRT dependencies..."
        #sudo yum remove -y xrt
        yum config-manager --set-enabled powertools
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        yum config-manager --set-enabled appstream
        echo "Installing XRT package..."
        sudo yum install -y /tmp/$XRT_PACKAGE
    fi
    #rm /tmp/$XRT_PACKAGE
}

check_xrt() {
    if [[ "$OSVERSION" == "ubuntu-16.04" ]] || [[ "$OSVERSION" == "ubuntu-18.04" ]] || [[ "$OSVERSION" == "ubuntu-20.04" ]]; then
        XRT_INSTALL_INFO=`apt list --installed 2>/dev/null | grep "xrt" | grep "$XRT_VERSION"`
    elif [[ "$OSVERSION" == "centos-7" ]] || [[ "$OSVERSION" == "centos-8" ]]; then
        XRT_INSTALL_INFO=`yum list installed 2>/dev/null | grep "xrt" | grep "$XRT_VERSION"`
    fi
}

install_xbflash() {
    cp -r /proj/oct-fpga-p4-PG0/tools/xbflash/${OSVERSION} /tmp
    echo "Installing xbflash."
    if [[ "$OSVERSION" == "ubuntu-18.04" ]] || [[ "$OSVERSION" == "ubuntu-20.04" ]]; then
        apt install /tmp/${OSVERSION}/*.deb
    elif [[ "$OSVERSION" == "centos-7" ]] || [[ "$OSVERSION" == "centos-8" ]]; then
        yum install /tmp/${OSVERSION}/*.rpm
    fi    
}

verify_install() {
    errors=0
    check_xrt
    if [ $? == 0 ] ; then
        echo "XRT installation verified."
    else
        echo "XRT installation could not be verified."
        errors=$((errors+1))
    fi
    return $errors
}
SHELL=1
OSVERSION=`grep '^ID=' /etc/os-release | awk -F= '{print $2}'`
OSVERSION=`echo $OSVERSION | tr -d '"'`
VERSION_ID=`grep '^VERSION_ID=' /etc/os-release | awk -F= '{print $2}'`
VERSION_ID=`echo $VERSION_ID | tr -d '"'`
OSVERSION="$OSVERSION-$VERSION_ID"
TOOLVERSION=$1
SCRIPT_PATH=/local/repository
COMB="${TOOLVERSION}_${OSVERSION}"
XRT_PACKAGE=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $1}' | awk -F= '{print $2}'`
XRT_VERSION=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $7}' | awk -F= '{print $2}'`

install_xrt
install_xbflash
verify_install
if [ $? == 0 ] ; then
    echo "XRT and shell package installation successful."
else
    echo "XRT installation failed."
    exit 1
fi
