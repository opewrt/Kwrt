#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

#bash $SHELL_FOLDER/../common/kernel_6.1.sh

LEDE_REPO="${LEDE_REPO:-https://github.com/opewrt/lede}"
LEDE_REF="${LEDE_REF:-19978f14dceb8a3e6e63c8eb1d30e2052738add3}"

git_clone_path "${LEDE_REF}" "${LEDE_REPO}" target/linux/amlogic package/boot/uboot-amlogic

sed -i "s/wpad-openssl/wpad-basic-mbedtls/" target/linux/amlogic/image/mesongx.mk


