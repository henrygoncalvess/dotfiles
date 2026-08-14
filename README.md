<h1 align=center>📂 dotfiles</h1>

## 📋 Conteúdo

- [Visão Geral](#overview)
- [Objetivo](#objective)
- [Requisitos](#prerequisites)
- [Clonando Repositório](#cloning-repo)
- [Instrução de uso ( Stow )](#use1)
- [Explicação](#explanation)
- [Uso dos scripts](#use3)
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
| Lock / idle | Hypridle + **qylock** (temas de lockscreen em Quickshell), com Hyprlock como fallback. Ponto de entrada único: `~/.config/hypr/scripts/system-lock.sh`; tema em `~/.config/qylock/theme` (ou `random`) |
| Wallpaper | [awww](https://github.com/LGFae/swww) (ex-swww) + [matugen](https://github.com/InioX/matugen) (troca dinâmica e paleta gerada do wallpaper) |
| Clipboard | [cliphist](https://github.com/sentriz/cliphist) + wl-clipboard |
| Screenshot / gravação | grim + slurp / [wf-recorder](https://github.com/ammen99/wf-recorder) |
| Editores | Neovim, VS Code |
| Navegador | Firefox (userChrome customizado) |
| Home lab | [Frigate](https://frigate.video/) NVR + Mosquitto + Home Assistant (Docker) |

<br>

<a name="objective"></a>
### 🎯 Objetivo

Versionar minhas preferências de desenvolvimento, garantindo consistência e produtividade em qualquer ambiente.

<br>

<a name="prerequisites"></a>
### 📦 Pré-Requisitos

Para **aplicar** os dotfiles você só precisa das ferramentas abaixo — todo o restante do stack (Quickshell, Rofi, Kitty, etc.) é instalado automaticamente pelo script de instalação da sua distro: [`install_softwares_ubuntu.sh`](scripts/install_softwares_ubuntu.sh) ou [`install_softwares_arch.sh`](scripts/install_softwares_arch.sh).

- **Linux** (testado em Ubuntu 24.04 com sessão Wayland; script dedicado para Arch/Omarchy)
- **Git**
- [**GNU stow**](https://www.gnu.org/software/stow/) - para gerenciar links simbólicos

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

(passos opcionais, pois o script `import_conf.sh` já cria Symlinks automaticamente)

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

<a name="use3"></a>
### 📜 Uso dos scripts

_para executar um script: `./script.sh` ou `bash script.sh`_

> [!IMPORTANT]
> #### Ordem de execução em uma máquina nova
> **1º** — `install_softwares_<distro>.sh` → instala todos os programas do stack.
> **2º** — `import_conf.sh` → cria os symlinks (Stow) das configurações.

**1º passo** — instale os programas com o script da sua distro:

`~/.dotfiles/scripts`
```bash
# Ubuntu 24.04
./install_softwares_ubuntu.sh

# Arch / Omarchy
./install_softwares_arch.sh
```

**2º passo** — aplique os dotfiles:

```bash
./import_conf.sh
```

**3º passo (Opcional)** — gerencie a sessão do seu Firefox (abas e grupos):

O script `firefox_session_sync.py` permite que você faça o backup da sua sessão atual (removendo cookies e dados sensíveis) e restaure-a em outra máquina.

```bash
# Para salvar a sua sessão atual nos dotfiles (backup limpo)
./scripts/firefox_session_sync.py backup

# Para restaurar o backup na máquina nova (FECHE O FIREFOX ANTES!)
./scripts/firefox_session_sync.py restore
```

> [!NOTE]
> O `import_conf.sh` aplica **todos** os pacotes, inclusive `conf_hypr` e
> `conf_nvim` — no Omarchy o Hyprland daqui é sobreposto por cima dos defaults
> da distro (via `unbind`/`source`), não em vez deles.
>
> Os alvos de `CONF_TARGETS` são apagados com `rm -rf` antes do stow, então só
> entram ali diretórios cujo conteúdo é 100% deste repo. Diretórios
> compartilhados com **a distro, com outro app ou com estado de runtime** são
> tratados como **overlay** (`OVERLAY_PACKAGES`): só os arquivos fornecidos pelo
> pacote são substituídos, com `stow --no-folding`.
>
> | Pacote overlay | Por que o destino é compartilhado |
> |---|---|
> | `conf_omarchy` | `~/.config/omarchy` guarda `current/theme`, `themes/`, `hooks/` |
> | `conf_walker` | recebe arquivos gerados pelo `omarchy refresh walker` |
> | `conf_systemd` | o systemd não segue diretório de drop-in que seja symlink |
> | `conf_qs-vpets` | o qs-vpets grava `state-<Pet>.json` ao lado do `config.json` |
> | `conf_easyeffects` | a UI do EasyEffects cria outros presets no mesmo diretório |
> | `conf_pipewire` | `~/.config/pipewire` pode conter outros drop-ins locais do usuário |
> | `conf_autostart` | `~/.config/autostart` recebe `.desktop` instalados pelos apps |
>
> O `conf_code` é stowado duas vezes: em `~/.config/Code` e, como overlay, em
> `~/.config/Antigravity IDE/User` — o Antigravity é um fork do VS Code e lê o
> mesmo `settings.json`/`keybindings.json`, só que sob outro nome de diretório.
> Não existe segunda cópia dos arquivos: os dois editores seguem o mesmo link.
>
> Ao final o script roda `systemctl --user enable brainshell quickshell` e
> `mask mako` — sem isso o Brain_Shell não sobe no login de uma máquina nova.

> [!TIP]
> **Personalizações do Omarchy vão em `~/.config/`, nunca em
> `~/.local/share/omarchy/`** — aquilo é a árvore git da distro e qualquer
> edição é desfeita (ou vira conflito) no próximo `omarchy update`. Exemplos
> aqui: o tema do walker vive em `conf_walker/.config/walker/themes/omarchy-custom/`
> em vez de editar o `omarchy-default`, e o bloqueio de tela passa por
> `conf_hypr/.config/hypr/scripts/system-lock.sh` em vez de patchear o
> `omarchy-system-lock`. Pro menu do Omarchy existe o ponto de extensão oficial
> `~/.config/omarchy/extensions/menu.sh`.

<br>

<a name="license"></a>
## 📄 Licença

Este projeto está licenciado sob a [MIT License](https://github.com/henrygoncalvess/dotfiles/blob/main/LICENSE).

---

<div align="center">
  <p>Feito com ❤️ por <a href="https://github.com/henrygoncalvess">Henry Gonçalves</a></p>
  <p>Deixe uma ⭐ no repositório se ele for útil para você!</p>
</div>
