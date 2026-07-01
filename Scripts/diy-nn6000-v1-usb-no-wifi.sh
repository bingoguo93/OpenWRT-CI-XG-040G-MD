#!/usr/bin/env bash
# scripts/diy-nn6000-v1-usb-no-wifi.sh

set -e

# Remove default wireless packages if selected by target defaults.
./scripts/config --disable PACKAGE_wpad-basic-mbedtls || true
./scripts/config --disable PACKAGE_wpad-openssl || true
./scripts/config --disable PACKAGE_wpad-wolfssl || true
./scripts/config --disable PACKAGE_hostapd || true
./scripts/config --disable PACKAGE_hostapd-common || true
./scripts/config --disable PACKAGE_wireless-regdb || true
./scripts/config --disable PACKAGE_iw || true
./scripts/config --disable PACKAGE_iwinfo || true

./scripts/config --disable PACKAGE_kmod-mt76 || true
./scripts/config --disable PACKAGE_kmod-mt76-core || true
./scripts/config --disable PACKAGE_kmod-mt76-connac || true
./scripts/config --disable PACKAGE_kmod-mt7915e || true
./scripts/config --disable PACKAGE_kmod-mt7981-firmware || true
./scripts/config --disable PACKAGE_kmod-mt7986-firmware || true
./scripts/config --disable PACKAGE_kmod-mt7996-firmware || true

make defconfig
