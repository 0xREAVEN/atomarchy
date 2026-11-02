# vim: set ft=make :
# Atomarchy Gaming recipes, imported by 60-custom.just.

# Unlock or lock AMD GPU overdrive (ppfeaturemask) for LACT
[group("atomarchy-gaming")]
toggle-amdgpu-overdrive:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    # Same method as Bazzite's hardware setup: only the overdrive bit (0x4000) is
    # added to the driver mask; the other PowerPlay features keep their defaults.
    PARAM=/sys/module/amdgpu/parameters/ppfeaturemask
    if [ ! -r "$PARAM" ]; then
        echo "amdgpu driver not loaded: no AMD GPU to configure."
        exit 1
    fi
    MASK=$(( $(cat "$PARAM") ))
    KARG=$(rpm-ostree kargs | grep -oE 'amdgpu\.ppfeaturemask=[^ ]+' | head -n1 || true)
    if (( MASK & 0x4000 )); then
        STATUS="${green}${bold}enabled${normal}"
    else
        STATUS="${yellow}${bold}disabled${normal}"
    fi
    echo -e "AMD GPU overdrive: $STATUS (mask $(printf '0x%x' "$MASK"))"
    echo "Required for LACT to change clocks, voltages (undervolt) and fan curves."
    echo ""
    ACTION=$(ugum choose "Enable overdrive" "Disable overdrive" "Cancel")
    case "$ACTION" in
        "Enable overdrive")
            if [ -n "$KARG" ]; then
                OLD=${KARG#*=}
                if (( OLD & 0x4000 )); then
                    echo "Overdrive already in the kernel arguments ($KARG)."
                    exit 0
                fi
                NEW=$(printf '0x%x' $(( OLD | 0x4000 )))
                sudo rpm-ostree kargs --delete="$KARG" --append="amdgpu.ppfeaturemask=$NEW"
            else
                NEW=$(printf '0x%x' $(( MASK | 0x4000 )))
                sudo rpm-ostree kargs --append-if-missing="amdgpu.ppfeaturemask=$NEW"
            fi
            echo -e "${green}${bold}Enabled.${normal} amdgpu.ppfeaturemask=$NEW: reboot to apply."
            ;;
        "Disable overdrive")
            if [ -z "$KARG" ]; then
                echo "No amdgpu.ppfeaturemask argument: nothing to remove."
                exit 0
            fi
            sudo rpm-ostree kargs --delete-if-present="$KARG"
            echo -e "${yellow}${bold}Disabled.${normal} $KARG removed: reboot to apply."
            ;;
        *) echo "Nothing changed." ;;
    esac

# Proton native Wayland + HDR for every game (Hyprland passes HDR through)
[group("atomarchy-gaming")]
toggle-proton-hdr:
    #!/usr/bin/bash
    set -euo pipefail
    file="$HOME/.config/environment.d/99-proton-wayland-hdr.conf"
    if [[ -f $file ]]; then
      echo "Proton Wayland + HDR is enabled globally."
      gum confirm "Disable it?" || exit 0
      rm -f "$file"
      echo "Disabled. Log out and back in to apply."
    else
      echo "Enables PROTON_ENABLE_WAYLAND=1 and PROTON_ENABLE_HDR=1 for every game."
      echo "Per game instead: add them to the Steam launch options."
      gum confirm "Enable it globally?" || exit 0
      mkdir -p "$(dirname "$file")"
      printf 'PROTON_ENABLE_WAYLAND=1\nPROTON_ENABLE_HDR=1\n' >"$file"
      echo "Enabled. Log out and back in to apply."
    fi
