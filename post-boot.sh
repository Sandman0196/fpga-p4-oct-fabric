#!/usr/bin/env bash

# Install XRT function from oct-u280 profile
install_xrt() {
    echo "Install XRT"
    if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
        echo "Ubuntu XRT install"
        echo "Installing XRT dependencies..."
        apt update
        echo "Installing XRT package..."
        apt install -y $XRT_BASE_PATH/$TOOLVERSION/$OSVERSION/$XRT_PACKAGE
    fi
    sudo bash -c "echo 'source /opt/xilinx/xrt/setup.sh' >> /etc/profile"
    sudo bash -c "echo 'source $VITIS_BASE_PATH/$VITISVERSION/settings64.sh' >> /etc/profile"
}

# Check if XRT is already installed (from oct-u280)
check_xrt() {
    if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
        XRT_INSTALL_INFO=`apt list --installed 2>/dev/null | grep "xrt" | grep "$XRT_VERSION"`
    elif [[ "$OSVERSION" == "centos-8" ]]; then
        XRT_INSTALL_INFO=`yum list installed 2>/dev/null | grep "xrt" | grep "$XRT_VERSION"`
    fi
}

# Install Shell Package (from oct-u280)
install_shellpkg() {
    echo "Install Shell Package"
    if [[ "$FPGA_DETECTED" == 0 ]]; then
        echo "[WARNING] No FPGA Board Detected."
        exit 1
    fi
    echo "Detected $FPGA_DETECTED FPGA(s)."
    PLATFORM=`echo "alveo-$FPGA_MODEL" | awk '{print tolower($0)}'`
    check_shellpkg
    if [[ $? != 0 ]]; then
        echo "Shell package not installed. Installing..."
        tar xzvf $SHELL_BASE_PATH/$TOOLVERSION/$OSVERSION/$SHELL_PACKAGE -C /tmp/
        echo "Installing shell package"
        apt-get install -y /tmp/xilinx*
        rm /tmp/xilinx*
    else
        echo "Shell package is already installed."
    fi
}

# Check if the shell package is already installed (from oct-u280)
check_shellpkg() {
    if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
        PACKAGE_INSTALL_INFO=`apt list --installed 2>/dev/null | grep "$PACKAGE_NAME" | grep "$PACKAGE_VERSION"`
    elif [[ "$OSVERSION" == "centos-8" ]]; then
        PACKAGE_INSTALL_INFO=`yum list installed 2>/dev/null | grep "$PACKAGE_NAME" | grep "$PACKAGE_VERSION"`
    fi
}

# Install xbflash utility (from oct-u280)
install_xbflash() {
    cp -r $XBFLASH_BASE_PATH/${OSVERSION} /tmp
    echo "Installing xbflash."
    if [[ "$OSVERSION" == "ubuntu-18.04" ]] || [[ "$OSVERSION" == "ubuntu-20.04" ]]; then
        apt install /tmp/${OSVERSION}/*.deb
    elif [[ "$OSVERSION" == "centos-7" ]] || [[ "$OSVERSION" == "centos-8" ]]; then
        yum install /tmp/${OSVERSION}/*.rpm
    fi    
}

# Check if requested FPGA shell is installed (from oct-u280)
check_requested_shell() {
    SHELL_INSTALL_INFO=`/opt/xilinx/xrt/bin/xbmgmt examine | grep "$DSA"`
}

# Flash the FPGA card (from oct-u280)
flash_card() {
    echo "Flash Card(s)."
    /opt/xilinx/xrt/bin/xbmgmt program --base --device $PCI_ADDR
}

# Detect FPGA cards (from oct-u280)
detect_cards() {
    lspci > /dev/null
    if [[ $? != 0 ]]; then
        if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
            apt-get install -y pciutils
        elif [[ "$OSVERSION" == "centos-7" ]] || [[ "$OSVERSION" == "centos-8" ]]; then
            yum install -y pciutils
        fi
    fi
    PCI_ADDR=$(lspci -d 10ee: | awk '{print $1}' | head -n 1)
    if [ -n "$PCI_ADDR" ]; then
        FPGA_DETECTED=1
    else
        echo "Error: No FPGA detected."
        FPGA_DETECTED=0
    fi
}

# Install configuration files for FPGA (from oct-u280)
install_config_fpga() {
    echo "Installing config-fpga."
    cp $CONFIG_FPGA_PATH/* /usr/local/bin
}

# Install necessary libraries (from oct-u280)
install_libs() {
    echo "Installing libs."
    sudo $VITIS_BASE_PATH/$VITISVERSION/scripts/installLibs.sh
}

# Verify installation
verify_install() {
    errors=0
    check_xrt
    if [ $? == 0 ]; then
        echo "XRT installation verified."
    else
        echo "XRT installation could not be verified."
        errors=$((errors+1))
    fi
    return $errors
}

# Disable PCIe fatal error reporting (from oct-u280)
disable_pcie_fatal_error() {
    echo "Disabling PCIe fatal error reporting for node: $NODE_ID"
    sudo /proj/octfpga-PG0/tools/pcie_disable_fatal.sh $PCI_ADDR
}

# Initialize environment variables
XRT_BASE_PATH="/proj/oct-fpga-p4-PG0/tools/deployment/xrt"
SHELL_BASE_PATH="/proj/oct-fpga-p4-PG0/tools/deployment/shell"
XBFLASH_BASE_PATH="/proj/oct-fpga-p4-PG0/tools/xbflash"
VITIS_BASE_PATH="/proj/oct-fpga-p4-PG0/tools/Xilinx/Vitis"
CONFIG_FPGA_PATH="/proj/oct-fpga-p4-PG0/tools/post-boot"
OSVERSION=$(grep '^ID=' /etc/os-release | awk -F= '{print $2}' | tr -d '"')
VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | awk -F= '{print $2}' | tr -d '"')
OSVERSION="$OSVERSION-$VERSION_ID"
WORKFLOW=$1
TOOLVERSION=$2
VITISVERSION="2023.1"
SCRIPT_PATH=/local/repository
COMB="${TOOLVERSION}_${OSVERSION}"
XRT_PACKAGE=$(grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $1}' | awk -F= '{print $2}')
SHELL_PACKAGE=$(grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $2}' | awk -F= '{print $2}')
DSA=$(grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $3}' | awk -F= '{print $2}')
PACKAGE_NAME=$(grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $5}' | awk -F= '{print $2}')
PACKAGE_VERSION=$(grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $6}' | awk -F= '{print $2}')
XRT_VERSION=$(grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $7}' | awk -F= '{print $2}')
FACTORY_SHELL="xilinx_u280_GOLDEN_8"
NODE_ID=$(hostname | cut -d'.' -f1)

# Execute installation and configuration
echo "Detecting FPGA cards..."
detect_cards
check_xrt
if [ $? == 0 ]; then
    echo "XRT is already installed."
else
    echo "XRT is not installed. Attempting to install XRT..."
    install_xrt

    check_xrt
    if [ $? == 0 ]; then
        echo "XRT was successfully installed."
    else
        echo "Error: XRT installation failed."
        exit 1
    fi
fi

install_libs
disable_pcie_fatal_error
install_config_fpga

if [ "$WORKFLOW" = "Vitis" ] ; then
    check_shellpkg
    if [ $? == 0 ]; then
        echo "Shell is already installed."
    else
        echo "Shell is not installed. Installing shell..."
        install_shellpkg
        check_shellpkg
        if [ $? == 0 ]; then
            echo "Shell was successfully installed. Flashing
