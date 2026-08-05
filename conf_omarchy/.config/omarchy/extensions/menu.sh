# Overwrite parts of the omarchy-menu with user-specific submenus.
# See $OMARCHY_PATH/bin/omarchy-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when Omarchy changes.

# Redireciona o "Lock" do menu pro nosso wrapper (qylock supervisionado), mesmo
# alvo do SUPER+CTRL+L e do hypridle. É este o ponto de extensão suportado —
# editar bin/omarchy-system-lock direto seria desfeito no próximo omarchy update.
#
# Cópia do show_system_menu upstream com uma linha trocada; se o Omarchy mudar
# esse menu, revisar aqui.
show_system_menu() {
  local options="󱄄  Screensaver\n  Lock"
  ! omarchy-toggle-enabled suspend-off && options="$options\n󰒲  Suspend"
  omarchy-hibernation-available && options="$options\n󰤁  Hibernate"
  options="$options\n󰍃  Logout\n󰜉  Restart\n󰐥  Shutdown"

  case $(menu "System" "$options") in
  *Screensaver*) omarchy-launch-screensaver force ;;
  *Lock*) ~/.config/hypr/scripts/system-lock.sh ;;
  *Suspend*) systemctl suspend ;;
  *Hibernate*) systemctl hibernate ;;
  *Logout*) omarchy-system-logout ;;
  *Restart*) omarchy-system-reboot ;;
  *Shutdown*) omarchy-system-shutdown ;;
  *) back_to show_main_menu ;;
  esac
}
