<h1 align=center>📂 dotfiles</h1>

## 📋 Conteúdo

- [Visão Geral](#overview)
- [Objetivo](#objective)
- [Requisitos](#prerequisites)
- [Clonando Repositório](#cloning-repo)
- [Instrução de uso ( Stow )](#use1)
- [Explicação](#explanation)
- [Instrução de uso ( Dconf )](#use2)
- [Uso dos scripts e Import\Export das Configurações](#use3)
- [Licença](#license)

<br>

<a name="overview"></a>
## 🔍 Visão Geral

Configurações pessoais do meu ambiente **Hyprland (Wayland)**, versionadas para backup, organização e replicação rápida em novas máquinas. Testado em **Ubuntu 24.04**; em migração para **Arch (Omarchy)** — há um script de instalação para cada distro.

| Categoria | Ferramenta |
| --- | --- |
| Window Manager | [Hyprland](https://hypr.land/) (Wayland) |
| Shell / barra / widgets | [Quickshell](https://quickshell.org/) (QML) — **Brain_Shell**: barra, app launcher, clipboard, notificações, música, rede, calendário |
| Launcher / menus extras | [Rofi](https://github.com/davatorium/rofi) (temas [adi1090x](https://github.com/adi1090x/rofi)) — goanime, powermenu |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Shell / prompt | Zsh + [Oh My Zsh](https://ohmyz.sh/) + [Oh My Posh](https://ohmyposh.dev/) |
| Lock / idle | Hyprlock + Hypridle / **qylock** — temas de lockscreen em Quickshell |
| Wallpaper | [swww](https://github.com/LGFae/swww) + [matugen](https://github.com/InioX/matugen) (troca dinâmica e paleta gerada do wallpaper) |
| Clipboard | [cliphist](https://github.com/sentriz/cliphist) + wl-clipboard |
| Screenshot / gravação | grim + slurp / [wf-recorder](https://github.com/ammen99/wf-recorder) |
| Editores | Neovim, VS Code |
| Navegador | Firefox (userChrome customizado) |
| Config. do sistema | GNOME via [dconf](https://wiki.gnome.org/Projects/dconf) |
| Home lab | [Frigate](https://frigate.video/) NVR + Mosquitto + Home Assistant (Docker) |

<br>

<a name="objective"></a>
### 🎯 Objetivo

Versionar minhas preferências de desenvolvimento, garantindo consistência e produtividade em qualquer ambiente.

<br>

<a name="prerequisites"></a>
### 📦 Pré-Requisitos

Para **aplicar** os dotfiles você só precisa das ferramentas abaixo — todo o restante do stack (Quickshell, Rofi, Kitty, etc.) é instalado automaticamente pelo script de instalação da sua distro: [`install-softwares-ubuntu.sh`](scripts/install-softwares-ubuntu.sh) ou [`install-softwares-arch.sh`](scripts/install-softwares-arch.sh).

- **Linux** (testado em Ubuntu 24.04 com sessão Wayland, mas deve funcionar em qualquer distribuição)
- **Git**
- [**GNU stow**](https://www.gnu.org/software/stow/) - para gerenciar links simbólicos
- [**Dconf**](https://wiki.gnome.org/Projects/dconf) e/ou [**Dconf Editor**](https://wiki.gnome.org/Apps(2f)DconfEditor.html) -  para armazenar configurações de sistema (GNOME) em um banco de dados binário eficiente

<br>

<a name="cloning-repo"></a>
### 💻 Clonando Repositório

No Terminal, certifique de que você está no diretório **HOME** (~/)

`~/usuario`
```bash
git clone https://github.com/henrygoncalvess/dotfiles.git
```

Renomeie a pasta:

```bash
mv ~/dotfiles ~/.dotfiles
```

<br>

<a name="use1"></a>
### 📜 Instrução de uso ( Stow )

(passos opcionais, pois o script `import-dconf.sh` já cria Symlinks automaticamente)

1. Entre na pasta

```bash
cd ~/.dotfiles
```  
<br>

> [!IMPORTANT]
> #### Atenção antes de utilizar o Stow.
> Mova os arquivos em que deseja criar os links simbólicos para as pastas correspondentes.  
> Estrutura "espelhada" (modo tradicional)
>  
> _EXEMPLO 1:_ se quiser criar um link para `~/.config/oh_my_posh_config/theme.omp.json`  
> Mova o arquivo para `~/.dotfiles/conf_posh/.config/oh_my_posh_config/theme.omp.json`
> 
> _EXEMPLO 2:_ se quiser criar um link para `~/.config/Code/User/settings.json`  
> Mova o arquivo para `~/.dotfiles/conf_code/.config/Code/User/settings.json`

<br>

2. Após organizar os arquivos desejados, crie Symlinks com Stow

`~/.dotfiles`
```bash
stow -v -t ~ conf_posh/ conf_code/ conf_shell/ conf_git/
```

<br>

<a name="explanation"></a>
### 💡 Explicação

**Sintaxe:** `stow [opções] -t <destino> <pacote>`

`-v` → verbose, ou seja, vai mostrar na saída o que ele está fazendo.

`-t ~` → define o _target directory_ (`~/`, o diretório home do usuário). É para lá que os links simbólicos serão criados.

`conf_posh/ conf_code/ conf_bash/ conf_git/` → são os pacotes (pastas) que você quer "stowar". Cada pasta representa um conjunto de arquivos de configuração.

Suponha que você tem a seguinte estrutura dentro de `~/.dotfiles/`:

```bash
.dotfiles/
├── conf_posh/
│   └── .config/oh_my_posh_config/theme.omp.json
└── conf_code/
    └── .config/Code/User/settings.json
```

Ao rodar o comando, O Stow cria Symlinks dentro de `~/` que apontam  
para os arquivos dentro de `~/.dotfiles/conf_posh`:

```bash
~/.dotfiles/conf_posh/.config/oh_my_posh_config/theme.omp.json
 ↓
~/.config/oh_my_posh_config/theme.omp.json
```
```bash
~/.dotfiles/conf_code/.config/Code/User/settings.json
 ↓
~/.config/Code/User/settings.json
```

<br>

<a name="use2"></a>
### 📜 Instrução de uso ( Dconf )

```bash
# Exportar configurações (exemplo)
dconf dump /org/gnome/path/example > ~/.dotfiles/my-backup.ini

# Carregar configurações (exemplo)
dconf load /org/gnome/path/example < ~/.dotfiles/my-backup.ini

# Resetar configurações (exemplo)
dconf reset -f /org/gnome/path/example
```

<a name="use3"></a>
### 📜 Uso dos scripts e Import\Export das Configurações

_para executar um script: `./script.sh` ou `bash script.sh`_

> [!IMPORTANT]
> #### Ordem de execução em uma máquina nova
> **1º** — `install-softwares-<distro>.sh` → instala todos os programas do stack.
> **2º** — `import-dconf.sh` → cria os symlinks (Stow) e aplica as configurações do sistema.

**1º passo** — instale os programas com o script da sua distro:

`~/.dotfiles/scripts`
```bash
# Ubuntu 24.04
./install-softwares-ubuntu.sh

# Arch / Omarchy
./install-softwares-arch.sh
```

**2º passo** — aplique os dotfiles e as configurações:

```bash
./import-dconf.sh
```

Execute um dos scripts para manipular as configurações do Dconf:

`~/.dotfiles/scripts`
```bash
# Aplicar configurações
./import-dconf.sh

# Salvar configurações
./export-dconf.sh
```

<br>

<a name="license"></a>
## 📄 Licença

Este projeto está licenciado sob a [MIT License](https://github.com/henrygoncalvess/dotfiles/blob/main/LICENSE).

---

<div align="center">
  <p>Feito com ❤️ por <a href="https://github.com/henrygoncalvess">Henry Gonçalves</a></p>
  <p>Deixe uma ⭐ no repositório se ele for útil para você!</p>
</div>
