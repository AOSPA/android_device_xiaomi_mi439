#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2022 The LineageOS Project
# Copyright (C) 2023 Paranoid Android
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=mi439
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/bin/sensors.qti.pine)
            sed -i 's|sensor_def_|pine___def_|g' "${2}"
            ;;
        vendor/bin/sensors.qti.olive)
            sed -i 's|sensor_def_|olive__def_|g' "${2}"
            ;;
        vendor/lib/libmmcamera2_sensor_modules.so)
            # Allow up to 0xFF CameraModuleConfig nodes on camera_config.xml
            sed -i -e 's|\x68\x1e\x15\x28|\x68\x1e\xff\x28|g' "${2}"
            PATTERN_FOUND=$(hexdump -ve '1/1 "%.2x"' "${2}" | grep -E -o "681eff28" | wc -l)
            if [ $PATTERN_FOUND != "1" ]; then
                echo "Critical blob modification weren't applied on ${2}!"
                exit;
            fi
            ;;
        product/etc/permissions/vendor.qti.hardware.data.connection-V1.0-java.xml \
        | product/etc/permissions/vendor.qti.hardware.data.connection-V1.1-java.xml)
            sed -i 's|version="2.0"|version="1.0"|g' "${2}"
            ;;
        system_ext/lib64/lib-imscamera.so)
            for LIBSHIM_IMSVIDEOCODEC in $(grep -L "libshim_imscamera.so" "${2}"); do
                "${PATCHELF}" --add-needed "libshim_imscamera.so" "${2}"
            done
            ;;
    esac
}

# Initialize the helper for device
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${MY_DIR}/proprietary-files-qc-sys.txt" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${MY_DIR}/proprietary-files-qc-vndr-64.txt" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${MY_DIR}/proprietary-files-qc-vndr-32.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
