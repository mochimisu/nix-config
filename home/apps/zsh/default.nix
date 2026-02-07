{
  pkgs,
  lib,
  ...
}: let
  thinFastfetch = pkgs.writeShellScriptBin "thin-fastfetch" ''
    #!/bin/bash

    # Set the minimum terminal width required to display the logo
    MIN_WIDTH=80

    # Safely detect terminal width; fall back if tput is unavailable
    TERM_WIDTH=0
    if command -v tput >/dev/null 2>&1; then
      TERM_OUTPUT=$(tput cols 2>/dev/null || true)
      if [[ "$TERM_OUTPUT" =~ ^[0-9]+$ ]]; then
        TERM_WIDTH=$TERM_OUTPUT
      fi
    fi

    # Check if the terminal width meets the minimum requirement
    if [ "$TERM_WIDTH" -ge "$MIN_WIDTH" ]; then
        # Run Fastfetch with the logo
        fastfetch
    else
        # Run Fastfetch without the logo
        fastfetch --logo none
    fi'';
in {
  imports = [
    ./p10k.nix
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    zplug = {
      enable = true;
      plugins = [
        {
          name = "zsh-users/zsh-history-substring-search";
          tags = ["as:plugin" "depth:1"];
        }
        {
          name = "chisui/zsh-nix-shell";
          tags = ["as:plugin" "depth:1"];
        }
      ];
    };
    sessionVariables = {
      SDL_VIDEODRIVER = "wayland";
      # for gnome-keyring
      SSH_AUTH_SOCK = lib.optionalString pkgs.stdenv.isLinux "/run/user/$(id -u)/gcr/ssh";
    };

    shellAliases = {
      cdx = "codex --search --dangerously-bypass-approvals-and-sandbox";
      cdxr = "cdx resume";
    };

    initContent = ''
      bindkey "^[[A" up-line-or-search
      bindkey "^[[B" down-line-or-search
      # disable ctrl s/q
      stty -ixon
      export PATH="$HOME/.npm-global/bin:$PATH"
      # local zsh for things like keys
      [ -f ~/.zshrc-local ] && source ~/.zshrc-local

      # Buffer input while fastfetch runs so early typing isn't lost.
      __fastfetch_input_buffer=""
      __fastfetch_input_accept=0

      __fastfetch_run_with_input_buffer() {
        emulate -L zsh
        setopt local_options no_shwordsplit no_aliases

        local buf="" key="" _="" tty_state=""
        local accept=0

        tty_state=$(stty -g </dev/tty 2>/dev/null || true)
        if [[ -n $tty_state ]]; then
          stty -echo </dev/tty 2>/dev/null || true
        fi

        __fastfetch_drain_escape() {
          emulate -L zsh
          local ch=""

          if ! read -r -t 0.01 -k 1 ch </dev/tty; then
            return
          fi

          case $ch in
            '[')
              # CSI: consume until a final byte in @-~
              while read -r -t 0.001 -k 1 ch </dev/tty; do
                case $ch in
                  [@-~]) break ;;
                esac
              done
              ;;
            ']'|'P'|'^'|'_')
              # OSC/DCS/PM/APC: consume until BEL or ESC \
              while read -r -t 0.001 -k 1 ch </dev/tty; do
                if [[ $ch == $'\a' ]]; then
                  break
                elif [[ $ch == $'\e' ]]; then
                  read -r -t 0.001 -k 1 ch </dev/tty || true
                  break
                fi
              done
              ;;
            *)
              ;;
          esac
        }

        ${thinFastfetch}/bin/thin-fastfetch </dev/null &
        local ff_pid=$!

        while kill -0 $ff_pid 2>/dev/null; do
          if read -r -t 0.05 -k 1 key </dev/tty; then
            case $key in
              $'\r'|$'\n')
                accept=1
                break
                ;;
              $'\003')
                # Ctrl-C: abort fastfetch and drop buffered input.
                buf=""
                accept=0
                kill -TERM $ff_pid 2>/dev/null || true
                break
                ;;
              $'\177'|$'\b')
                buf=''${buf%?}
                ;;
              $'\e')
                __fastfetch_drain_escape
                ;;
              [[:cntrl:]])
                ;;
              *)
                buf+=$key
                ;;
            esac
          fi
        done

        if (( accept )); then
          kill -TERM $ff_pid 2>/dev/null || true
        fi

        wait $ff_pid 2>/dev/null || true

        if [[ -n $tty_state ]]; then
          stty $tty_state </dev/tty 2>/dev/null || true
        fi

        __fastfetch_input_buffer=$buf
        __fastfetch_input_accept=$accept
      }

      __fastfetch_apply_buffer() {
        emulate -L zsh

        if [[ -n $__fastfetch_input_buffer || $__fastfetch_input_accept -eq 1 ]]; then
          BUFFER=$__fastfetch_input_buffer
          CURSOR=''${#BUFFER}
          __fastfetch_input_buffer=""

          if (( __fastfetch_input_accept )); then
            __fastfetch_input_accept=0
            zle accept-line
          else
            __fastfetch_input_accept=0
          fi
        fi
      }

      autoload -Uz add-zle-hook-widget
      add-zle-hook-widget zle-line-init __fastfetch_apply_buffer

      if [[ -t 0 && -t 1 ]]; then
        __fastfetch_run_with_input_buffer
      else
        ${thinFastfetch}/bin/thin-fastfetch
      fi
    '';
  };
}
