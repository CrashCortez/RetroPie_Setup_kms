#!/usr/bin/env bash

# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#

rp_module_id="retroarch"
rp_module_desc="RetroArch - frontend to the libretro emulator cores - required by all lr-* emulators"
rp_module_licence="GPL3 https://raw.githubusercontent.com/libretro/RetroArch/master/COPYING"
rp_module_section="core"

function depends_retroarch() {
    local depends=(libudev-dev libxkbcommon-dev libsdl2-dev libasound2-dev libusb-1.0-0-dev)
    isPlatform "mali" && depends+=(mali-fbdev)
    isPlatform "x11" && depends+=(libx11-xcb-dev libpulse-dev libavcodec-dev libavformat-dev libavdevice-dev)
    if isPlatform "kms"; then 
        depends+=(libgbm-dev libdrm-dev libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev)
    else
        isPlatform "rpi" && depends+=(libraspberrypi-dev)
    fi

    # only install nvidia-cg-toolkit if it is available (as the non-free repo may not be enabled)
    if isPlatform "x86"; then
        if [[ -n "$(apt-cache search --names-only nvidia-cg-toolkit)" ]]; then
            depends+=(nvidia-cg-toolkit)
        fi
    fi

    getDepends "${depends[@]}"

    addUdevInputRules
}

function sources_retroarch() {
    if isPlatform "kms"; then
        gitPullOrClone "$md_build" https://github.com/gizmo98/RetroArch.git
    else
        gitPullOrClone "$md_build" https://github.com/libretro/RetroArch.git
    fi
    applyPatch "$md_data/01_hotkey_hack.diff"
    applyPatch "$md_data/02_disable_search.diff"
    #if isPlatform "kms"; then
    #    sed -i 's/"#extension GL_OES_standard_derivatives : enable\n" \/precision mediump float;\n/g' "$md_build/gfx/drivers/gl_shaders/shaders_common.h"
    #    sed -i 's/#define GL_FRAGMENT_PRECISION_HIGH 1/#define GL_FRAGMENT_PRECISION_HIGH 0/g' "$md_build/deps/glslang/glslang/glslang/MachineIndependent/Versions.cpp"
    #    sed -i 's/#define GL_OES_standard_derivatives 1/#define GL_OES_standard_derivatives 0/g' "$md_build/deps/glslang/glslang/glslang/MachineIndependent/Versions.cpp"
    #    #sed -i 's/#define GL_EXT_frag_depth 1/#define GL_EXT_frag_depth 0/g' "$md_build/deps/glslang/glslang/glslang/MachineIndependent/Versions.cpp"
    #    sed -i 's/precision highp float/precision mediump float/g' "$md_build/gfx/drivers/gl_shaders/shaders_common.h"
    #    rm "$md_build/gfx/drivers/gl_shaders/shaders_common.h"
    #    cp "$md_build/gfx/drivers/d3d_shaders/shaders_common.h" "$md_build/gfx/drivers/gl_shaders/shaders_common.h"
    #fi
}

function build_retroarch() {
    local params=(--enable-sdl2)
    ! isPlatform "x11" && params+=(--enable-opengles --disable-x11 --disable-ffmpeg --disable-sdl --enable-sdl2 --disable-oss --disable-pulse --disable-al --disable-jack)
    isPlatform "mali" && params+=(--enable-mali_fbdev)
    if isPlatform "kms"; then 
        params+=(--enable-kms --enable-egl --disable-videocore --enable-plain_drm)
        isPlatform "rpi" && params+=(--disable-opengles3)
    else
        isPlatform "rpi" && params+=(--enable-dispmanx)
    fi
    if isPlatform "arm"; then
        params+=(--enable-floathard)
        isPlatform "neon" && params+=(--enable-neon)
    fi
    ./configure --prefix="$md_inst" "${params[@]}"
    make clean
    make
    md_ret_require="$md_build/retroarch"
}

function install_retroarch() {
    make install
    md_ret_files=(
        'retroarch.cfg'
    )
}

function update_shaders_retroarch() {
    local dir="$configdir/all/retroarch/shaders"
    local branch=""
    isPlatform "rpi" && branch="rpi"
    # remove if not git repository for fresh checkout
    [[ ! -d "$dir/.git" ]] && rm -rf "$dir"
    if isPlatform "kms"; then
        gitPullOrClone "$dir" https://github.com/libretro/glsl-shaders.git
    else
        gitPullOrClone "$dir" https://github.com/RetroPie/common-shaders.git "$branch"
    fi
    chown -R $user:$user "$dir"
}

function update_overlays_retroarch() {
    local dir="$configdir/all/retroarch/overlay"
    # remove if not a git repository for fresh checkout
    [[ ! -d "$dir/.git" ]] && rm -rf "$dir"
    gitPullOrClone "$configdir/all/retroarch/overlay" https://github.com/libretro/common-overlays.git
    chown -R $user:$user "$dir"
}

function update_assets_retroarch() {
    local dir="$configdir/all/retroarch/assets"
    # remove if not a git repository for fresh checkout
    [[ ! -d "$dir/.git" ]] && rm -rf "$dir"
    gitPullOrClone "$dir" https://github.com/libretro/retroarch-assets.git
    chown -R $user:$user "$dir"
}

function install_xmb_monochrome_assets_retroarch() {
    local dir="$configdir/all/retroarch/assets"
    [[ -d "$dir/.git" ]] && return
    [[ ! -d "$dir" ]] && mkUserDir "$dir"
    downloadAndExtract "$__archive_url/retroarch-xmb-monochrome.tar.gz" "$dir"
    chown -R $user:$user "$dir"
}

function configure_retroarch() {
    [[ "$md_mode" == "remove" ]] && return

    # move / symlink the retroarch configuration
    mkUserDir "$home/.config"
    moveConfigDir "$home/.config/retroarch" "$configdir/all/retroarch"

    # move / symlink our old retroarch-joypads folder
    moveConfigDir "$configdir/all/retroarch-joypads" "$configdir/all/retroarch/autoconfig"

    # move / symlink old assets / overlays and shader folder
    moveConfigDir "$md_inst/assets" "$configdir/all/retroarch/assets"
    moveConfigDir "$md_inst/overlays" "$configdir/all/retroarch/overlay"
    moveConfigDir "$md_inst/shader" "$configdir/all/retroarch/shaders"

    # install shaders by default
    update_shaders_retroarch

    # install minimal assets
    install_xmb_monochrome_assets_retroarch

    local config="$(mktemp)"

    cp "$md_inst/retroarch.cfg" "$config"

    # query ES A/B key swap configuration
    local es_swap="false"
    getAutoConf "es_swap_a_b" && es_swap="true"

    # configure default options
    iniConfig " = " '"' "$config"
    iniSet "cache_directory" "/tmp/retroarch"
    iniSet "system_directory" "$biosdir"
    iniSet "config_save_on_exit" "false"
    iniSet "video_aspect_ratio_auto" "true"
    iniSet "video_smooth" "false"
    iniSet "video_threaded" "true"
    iniSet "video_font_size" "12"
    iniSet "core_options_path" "$configdir/all/retroarch-core-options.cfg"
    isPlatform "x11" && iniSet "video_fullscreen" "true"

    # set default render resolution to 640x480 for rpi1
    if isPlatform "rpi1"; then
        iniSet "video_fullscreen_x" "640"
        iniSet "video_fullscreen_y" "480"
    fi

    # enable hotkey ("select" button)
    iniSet "input_enable_hotkey" "nul"
    iniSet "input_exit_emulator" "escape"

    # enable and configure rewind feature
    iniSet "rewind_enable" "false"
    iniSet "rewind_buffer_size" "10"
    iniSet "rewind_granularity" "2"
    iniSet "input_rewind" "r"

    # enable gpu screenshots
    iniSet "video_gpu_screenshot" "true"

    # enable and configure shaders
    iniSet "input_shader_next" "m"
    iniSet "input_shader_prev" "n"

    # configure keyboard mappings
    iniSet "input_player1_a" "x"
    iniSet "input_player1_b" "z"
    iniSet "input_player1_y" "a"
    iniSet "input_player1_x" "s"
    iniSet "input_player1_start" "enter"
    iniSet "input_player1_select" "rshift"
    iniSet "input_player1_l" "q"
    iniSet "input_player1_r" "w"
    iniSet "input_player1_left" "left"
    iniSet "input_player1_right" "right"
    iniSet "input_player1_up" "up"
    iniSet "input_player1_down" "down"

    # input settings
    iniSet "input_autodetect_enable" "true"
    iniSet "auto_remaps_enable" "true"
    iniSet "input_joypad_driver" "udev"
    iniSet "all_users_control_menu" "true"

    # rgui by default
    iniSet "menu_driver" "rgui"

    # hide online updater menu options
    iniSet "menu_show_core_updater" "false"
    iniSet "menu_show_online_updater" "false"

    # disable unnecessary xmb menu tabs
    iniSet "xmb_show_add" "false"
    iniSet "xmb_show_history" "false"
    iniSet "xmb_show_images" "false"
    iniSet "xmb_show_music" "false"

    # disable xmb menu driver icon shadows
    iniSet "xmb_shadows_enable" "false"

    # swap A/B buttons based on ES configuration
    iniSet "menu_swap_ok_cancel_buttons" "$es_swap"

    copyDefaultConfig "$config" "$configdir/all/retroarch.cfg"
    rm "$config"

    # if no menu_driver is set, force RGUI, as the default has now changed to XMB.
    iniConfig " = " '"' "$configdir/all/retroarch.cfg"
    iniGet "menu_driver"
    [[ -z "$ini_value" ]] && iniSet "menu_driver" "rgui"

    # if no menu_unified_controls is set, force it on so that keyboard player 1 can control
    # the RGUI menu which is important for arcade sticks etc that map to keyboard inputs
    iniGet "menu_unified_controls"
    [[ -z "$ini_value" ]] && iniSet "menu_unified_controls" "true"

    # remapping hack for old 8bitdo firmware
    addAutoConf "8bitdo_hack" 0
}

function keyboard_retroarch() {
    if [[ ! -f "$configdir/all/retroarch.cfg" ]]; then
        printMsgs "dialog" "No RetroArch configuration file found at $configdir/all/retroarch.cfg"
        return
    fi
    local input
    local options
    local i=1
    local key=()
    while read input; do
        local parts=($input)
        key+=("${parts[0]}")
        options+=("${parts[0]}" $i 2 "${parts[*]:2}" $i 26 16 0)
        ((i++))
    done < <(grep "^[[:space:]]*input_player[0-9]_[a-z]*" "$configdir/all/retroarch.cfg")
    local cmd=(dialog --backtitle "$__backtitle" --form "RetroArch keyboard configuration" 22 48 16)
    local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    if [[ -n "$choices" ]]; then
        local value
        local values
        readarray -t values <<<"$choices"
        iniConfig " = " "" "$configdir/all/retroarch.cfg"
        i=0
        for value in "${values[@]}"; do
            iniSet "${key[$i]}" "$value" >/dev/null
            ((i++))
        done
    fi
}

function hotkey_retroarch() {
    iniConfig " = " '"' "$configdir/all/retroarch.cfg"
    cmd=(dialog --backtitle "$__backtitle" --menu "Choose the desired hotkey behaviour." 22 76 16)
    options=(1 "Hotkeys enabled. (default)"
             2 "Press ALT to enable hotkeys."
             3 "Hotkeys disabled. Press ESCAPE to open RGUI.")
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    if [[ -n "$choices" ]]; then
        case $choices in
            1)
                iniSet "input_enable_hotkey" "nul"
                iniSet "input_exit_emulator" "escape"
                iniSet "input_menu_toggle" "F1"
                ;;
            2)
                iniSet "input_enable_hotkey" "alt"
                iniSet "input_exit_emulator" "escape"
                iniSet "input_menu_toggle" "F1"
                ;;
            3)
                iniSet "input_enable_hotkey" "escape"
                iniSet "input_exit_emulator" "nul"
                iniSet "input_menu_toggle" "escape"
                ;;
        esac
    fi
}

function gui_retroarch() {
    while true; do
        local names=(shaders overlays assets)
        local dirs=(shaders overlay assets)
        local options=()
        local name
        local dir
        local i=1
        for name in "${names[@]}"; do
            if [[ -d "$configdir/all/retroarch/${dirs[i-1]}/.git" ]]; then
                options+=("$i" "Manage $name (installed)")
            else
                options+=("$i" "Manage $name (not installed)")
            fi
            ((i++))
        done
        options+=(
            4 "Configure keyboard for use with RetroArch"
            5 "Configure keyboard hotkey behaviour for RetroArch"
        )
        local cmd=(dialog --backtitle "$__backtitle" --menu "Choose an option" 22 76 16)
        local choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        case "$choice" in
            1|2|3)
                name="${names[choice-1]}"
                dir="${dirs[choice-1]}"
                options=(1 "Install/Update $name" 2 "Uninstall $name" )
                cmd=(dialog --backtitle "$__backtitle" --menu "Choose an option for $dir" 12 40 06)
                choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

                case "$choice" in
                    1)
                        "update_${name}_retroarch"
                        ;;
                    2)
                        rm -rf "$configdir/all/retroarch/$dir"
                        [[ "$dir" == "assets" ]] && install_xmb_monochrome_assets_retroarch
                        ;;
                    *)
                        continue
                        ;;

                esac
                ;;
            4)
                keyboard_retroarch
                ;;
            5)
                hotkey_retroarch
                ;;
            *)
                break
                ;;
        esac

    done
}
