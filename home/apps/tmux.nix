{ pkgs, config, ... }:
{
  programs.tmux = {
    enable = true;
    shell = "/run/current-system/sw/bin/zsh";
    sensibleOnTop = false;
    extraConfig = ''
      bind s split-window -c "#{pane_current_path}"
      bind v split-window -h -c "#{pane_current_path}"
      bind z choose-session
      bind b last-window
      bind u join-pane -s !
      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",xterm-kitty:RGB"

# status bar (powerline style)
      set -g status-bg colour236
      set -g status-fg white
      set -g status-left-length 60
      set -g status-right-length 60
      set -g @ssh_bg "colour241"
      set -g @ssh_fg "white"
      set -g status-left '#[fg=colour236,bg=blue,bold] #S #[fg=blue,bg=colour236]'
      set -g status-right '#[fg=#{@ssh_bg},bg=colour236]#[fg=#{@ssh_fg},bg=#{@ssh_bg}] #H '
      set -g history-limit 100000

# remove delay when hitting esc in vim
      set -sg escape-time 0

# dont repeat
#set-option -g repeat-time 0

# make window size zmallest currently viewing it
      set-window-option -g aggressive-resize on

# smart pane switching with awareness of vim splits
      bind -n C-h run "(tmux display-message -p '#{pane_current_command}' | grep -iq vim && tmux send-keys C-h) || tmux select-pane -L"
      bind -n C-j run "(tmux display-message -p '#{pane_current_command}' | grep -iq vim && tmux send-keys C-j) || tmux select-pane -D"
      bind -n C-k run "(tmux display-message -p '#{pane_current_command}' | grep -iq vim && tmux send-keys C-k) || tmux select-pane -U"
      bind -n C-l run "(tmux display-message -p '#{pane_current_command}' | grep -iq vim && tmux send-keys C-l) || tmux select-pane -R"
      bind -n C-\\ run "(tmux display-message -p '#{pane_current_command}' | grep -iq vim && tmux send-keys 'C-\\') || tmux select-pane -l"

# theme
#if-shell "test -f .tmuxline.conf" "source .tmuxline.conf"

      setw -g aggressive-resize on

      set-option -g mouse on
      '';
  };
}
