{ config, lib, pkgs, ... }:
let
  variables = config.variables or {};
  kittyVars = variables.kitty or {};
  sshBg = kittyVars.sshBackground or "";
  sshFg = kittyVars.sshForeground or "";
  isLinuxGui = pkgs.stdenv.isLinux && (variables.isGui or true);
in {
  programs.kitty = lib.mkIf isLinuxGui {
    enable = true;
    font = {
      name = "Cascadia Code";
      size = 10;
    };
    settings = {
      background_opacity = 0.6;
      # Show a brief trail when the cursor moves to a new location
      cursor_trail = 1;
      # Wheel-based scrolling (low precision devices like synthetic wheel events)
      wheel_scroll_multiplier = "1.0";
      wheel_scroll_min_lines = "1";
    };
  };

  programs.zsh.initContent = lib.mkOrder 1500 ''
    # Per-SSH kitty styling based on hostname hash (or per-machine override).
    if [[ -n "$KITTY_WINDOW_ID" || "$TERM" == "xterm-kitty" ]] \
      && [[ -n "$SSH_CONNECTION" || -n "$SSH_TTY" || -n "$SSH_CLIENT" || -n "$MOSH_CLIENT" ]]; then
      _kitty_ssh_tty="/dev/tty"
      if [[ -w "$_kitty_ssh_tty" ]]; then
        _kitty_ssh_bg_cfg=${lib.escapeShellArg sshBg}
        _kitty_ssh_fg_cfg=${lib.escapeShellArg sshFg}
        if [[ -n "$_kitty_ssh_bg_cfg" ]]; then
          _kitty_bg_hex="$_kitty_ssh_bg_cfg"
          [[ "$_kitty_bg_hex" != \#* ]] && _kitty_bg_hex="#$_kitty_bg_hex"
        else
          _kitty_ssh_host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo ssh)
          _kitty_ssh_hash=$(printf '%s' "$_kitty_ssh_host" | cksum | awk '{print $1}')
          _kitty_bg=$(( _kitty_ssh_hash & 0xFFFFFF ))
          _kitty_bg_r=$(( (_kitty_bg >> 16) & 255 ))
          _kitty_bg_g=$(( (_kitty_bg >> 8) & 255 ))
          _kitty_bg_b=$(( _kitty_bg & 255 ))
          # Darken so backgrounds stay readable.
          _kitty_bg_r=$(( (_kitty_bg_r + 40) / 2 ))
          _kitty_bg_g=$(( (_kitty_bg_g + 48) / 2 ))
          _kitty_bg_b=$(( (_kitty_bg_b + 56) / 2 ))
          _kitty_bg_hex=$(printf '#%02x%02x%02x' $_kitty_bg_r $_kitty_bg_g $_kitty_bg_b)
        fi
        if [[ -n "$_kitty_ssh_fg_cfg" ]]; then
          _kitty_fg="$_kitty_ssh_fg_cfg"
          [[ "$_kitty_fg" != \#* ]] && _kitty_fg="#$_kitty_fg"
        else
          if [[ -z "$_kitty_bg_r" ]]; then
            _kitty_bg_hex_clean="''${_kitty_bg_hex#\#}"
            _kitty_bg=$((16#$_kitty_bg_hex_clean))
            _kitty_bg_r=$(( (_kitty_bg >> 16) & 255 ))
            _kitty_bg_g=$(( (_kitty_bg >> 8) & 255 ))
            _kitty_bg_b=$(( _kitty_bg & 255 ))
          fi
          _kitty_luma=$(( (_kitty_bg_r * 299 + _kitty_bg_g * 587 + _kitty_bg_b * 114) / 1000 ))
          if (( _kitty_luma < 128 )); then
            _kitty_fg="#e6e6e6"
          else
            _kitty_fg="#111111"
          fi
        fi
        _kitty_osc() { printf '\e]%s\a' "$1" >"$_kitty_ssh_tty"; }
        _kitty_osc "11;$_kitty_bg_hex"
        _kitty_osc "10;$_kitty_fg"
        _kitty_ssh_applied=1

        _kitty_ssh_reset() {
          [[ -n "$_kitty_ssh_applied" ]] || return 0
          _kitty_osc "111"
          _kitty_osc "110"
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook zshexit _kitty_ssh_reset
      fi
    fi
  '';
}
