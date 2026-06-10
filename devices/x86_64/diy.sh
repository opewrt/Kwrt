#!/bin/bash

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

#bash $SHELL_FOLDER/../common/kernel_6.6.sh

LEDE_REPO="${LEDE_REPO:-https://github.com/opewrt/lede}"
LEDE_REF="${LEDE_REF:-19978f14dceb8a3e6e63c8eb1d30e2052738add3}"
LEDE_RAW="${LEDE_RAW:-https://raw.githubusercontent.com/opewrt/lede/${LEDE_REF}}"

git_clone_path "${LEDE_REF}" "${LEDE_REPO}" target/linux/x86/files target/linux/x86/patches-6.6

wget -N "${LEDE_RAW}/target/linux/x86/base-files/etc/board.d/02_network" -P target/linux/x86/base-files/etc/board.d/

wget -N "${LEDE_RAW}/target/linux/x86/64/config-6.6" -P target/linux/x86/64/

wget -N "${LEDE_RAW}/package/firmware/linux-firmware/intel.mk" -P package/firmware/linux-firmware/

sed -i 's/kmod-r8169/kmod-r8168/' target/linux/x86/image/64.mk

sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += kmod-usb-hid kmod-mmc kmod-sdhci usbutils pciutils lm-sensors-detect kmod-atlantic kmod-vmxnet3 kmod-igbvf kmod-iavf kmod-bnx2x kmod-pcnet32 kmod-tulip kmod-r8101 kmod-r8125 kmod-r8126 kmod-8139cp kmod-8139too kmod-i40e kmod-drm-i915 kmod-drm-amdgpu kmod-mlx4-core kmod-mlx5-core fdisk lsblk kmod-phy-broadcom kmod-ixgbevf/' target/linux/x86/Makefile

mv -f tmp/r81* feeds/kiddin9/

sed -i 's/256/1024/g' target/linux/x86/image/Makefile

