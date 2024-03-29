#!/usr/bin/env bash

# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#

rp_module_id="reicast"
rp_module_desc="Dreamcast emulator Reicast"
rp_module_help="ROM Extensions: .cdi .gdi\n\nCopy your Dremcast roms to $romdir/dreamcast\n\nCopy the required BIOS files dc_boot.bin and dc_flash.bin to $biosdir"
rp_module_licence="GPL2 https://raw.githubusercontent.com/reicast/reicast-emulator/master/LICENSE"
rp_module_section="opt"
rp_module_flags="!armv6 !mali"

function depends_reicast() {
    getDepends libsdl1.2-dev python-dev python-pip alsa-oss python-setuptools libevdev-dev
    pip install evdev
}

function sources_reicast() {
    if isPlatform "x11"; then
        gitPullOrClone "$md_build" https://github.com/reicast/reicast-emulator.git
    else
        gitPullOrClone "$md_build" https://github.com/gizmo98/reicast-emulator.git vc4-omx
    fi
    
    #if isPlatform "kms"; then
        #sed -i "s|LIBS += -L/opt/vc/lib/  -L../linux-deps/lib -lbcm_host|USE_SDL := 1|g" "$md_build/shell/linux/Makefile"
        #sed -i "s|LIBS += -L/opt/vc/lib/ -lbcm_host|USE_SDL := 1|g" "$md_build/shell/linux/Makefile"
        #sed -i "s|LIBS += -L/opt/vc/lib/ -lbcm_host|LIBS += -L/opt/vc/lib/ -lopenmaxil|g" "$md_build/shell/linux/Makefile"
        #sed -i "s|INCS += -I/opt/vc/include/ -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/interface/vcos/pthreads -I../linux-deps/include||g" "$md_build/shell/linux/Makefile"
        #sed -i "s|INCS += -I/opt/vc/include/ -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/interface/vcos/pthreads||g" "$md_build/shell/linux/Makefile"
        #sed -i 's|enable_runfast();|//enable_runfast();|g' "$md_build/core/linux/common.cpp"
        #sed -i 's|linux_rpi2_init();|//linux_rpi2_init();|g' "$md_build/core/linux/common.cpp"
        #sed -i "s|USE_DISPMANX := 1|USE_SDL := 1|g" "$md_build/shell/linux/Makefile"
        #sed -i "s|USE_OMX := 1||g" "$md_build/shell/linux/Makefile"
        #sed -i "s| Bool| Enable|g" "$md_build/core/cfg/cfg.h"
        #sed -i "s| Bool| Enable|g" "$md_build/core/cfg/cfg.cpp"
        #sed -i "s|settings.aica.BufferSize=1024;|settings.aica.BufferSize=2048;|g" "$md_build/core/nullDC.cpp"
    #fi
    sed -i "s/CXXFLAGS += -fno-rtti -fpermissive -fno-operator-names/CXXFLAGS += -fno-rtti -fpermissive -fno-operator-names -D_GLIBCXX_USE_CXX11_ABI=0/g" shell/linux/Makefile

}

function build_reicast() {
    cd shell/linux
    if isPlatform "rpi"; then
        if isPlatform "kms"; then
            make platform=rpi2mesa clean
            make platform=rpi2mesa
        else
            make platform=rpi2 clean
            make platform=rpi2
        fi
    else
        make clean
        make
    fi
    md_ret_require="$md_build/shell/linux/reicast.elf"
}

function install_reicast() {
    cd shell/linux
    if isPlatform "rpi"; then
        if isPlatform "kms"; then
            make platform=rpi2mesa PREFIX="$md_inst" install
        else
            make platform=rpi2 PREFIX="$md_inst" install
        fi
    else
        make PREFIX="$md_inst" install
    fi
    md_ret_files=(
        'LICENSE'
        'README.md'
    )
}

function configure_reicast() {
    # copy hotkey remapping start script
    cp "$md_data/reicast.sh" "$md_inst/bin/"
    chmod +x "$md_inst/bin/reicast.sh"

    mkRomDir "dreamcast"

    # move any old configs to the new location
    moveConfigDir "$home/.reicast" "$md_conf_root/dreamcast/"

    # Create home VMU, cfg, and data folders. Copy dc_boot.bin and dc_flash.bin to the ~/.reicast/data/ folder.
    mkdir -p "$md_conf_root/dreamcast/"{data,mappings}

    # symlink bios
    ln -sf "$biosdir/"{dc_boot.bin,dc_flash.bin} "$md_conf_root/dreamcast/data"

    # copy default mappings
    cp "$md_inst/share/reicast/mappings/"*.cfg "$md_conf_root/dreamcast/mappings/"

    chown -R $user:$user "$md_conf_root/dreamcast"

    cat > "$romdir/dreamcast/+Start Reicast.sh" << _EOF_
#!/bin/bash
$md_inst/bin/reicast.sh
_EOF_
    chmod a+x "$romdir/dreamcast/+Start Reicast.sh"
    chown $user:$user "$romdir/dreamcast/+Start Reicast.sh"

    # remove old systemManager.cdi symlink
    rm -f "$romdir/dreamcast/systemManager.cdi"

    # add system
    # possible audio backends: alsa, oss, omx
    if isPlatform "rpi"; then
        if isPlatform "kms"; then
            addEmulator 1 "${md_id}-audio-oss" "dreamcast" "CON:$md_inst/bin/reicast.sh oss %ROM%"
            addEmulator 0 "${md_id}-audio-alsa" "dreamcast" "CON:$md_inst/bin/reicast.sh alsa %ROM%"
            addEmulator 0 "${md_id}-audio-omx" "dreamcast" "CON:$md_inst/bin/reicast.sh omx %ROM%"
        else
            addEmulator 1 "${md_id}-audio-omx" "dreamcast" "CON:$md_inst/bin/reicast.sh omx %ROM%"
            addEmulator 0 "${md_id}-audio-oss" "dreamcast" "CON:$md_inst/bin/reicast.sh oss %ROM%"
        fi
    else
        addEmulator 1 "$md_id" "dreamcast" "CON:$md_inst/bin/reicast.sh oss %ROM%"
    fi
    addSystem "dreamcast"

    addAutoConf reicast_input 1
}

function input_reicast() {
    local temp_file="$(mktemp)"
    cd "$md_inst/bin"
    ./reicast-joyconfig -f "$temp_file" >/dev/tty
    iniConfig " = " "" "$temp_file"
    iniGet "mapping_name"
    local mapping_file="$configdir/dreamcast/mappings/controller_${ini_value// /}.cfg"
    mv "$temp_file" "$mapping_file"
    chown $user:$user "$mapping_file"
}

function gui_reicast() {
    while true; do
        local options=(
            1 "Configure input devices for Reicast"
        )
        local cmd=(dialog --backtitle "$__backtitle" --menu "Choose an option" 22 76 16)
        local choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        [[ -z "$choice" ]] && break
        case "$choice" in
            1)
                clear
                input_reicast
                ;;
        esac
    done
}
