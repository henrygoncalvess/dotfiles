#!/usr/bin/env bash

# Lança o quickshell com o build que a máquina tiver:
#   - pacote nativo (arch/omarchy): quickshell direto
#   - perfil nix (ubuntu):          via nixGLIntel, senão o binário nix não
#                                   enxerga o driver OpenGL do sistema
# Chamado pelo exec-once e pelos binds de IPC do hyprland.conf.

if command -v quickshell &> /dev/null; then
  exec quickshell "$@"
fi

exec "$HOME/.nix-profile/bin/nixGLIntel" "$HOME/.nix-profile/bin/quickshell" "$@"
