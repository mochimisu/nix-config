{ pkgs, config, ... }:
{
  programs.tmux = {
    enable = true;
    extraConfig = ''
      bind s split-window -c "#{pane_current_path}"
      bind v split-window -h -c "#{pane_current_path}"
      bind z choose-session
      bind b last-window
      bind u join-pane -s !
      set -g default-terminal "screen-256color"

# status bar
      set -g status-bg colour236
      set -g status-fg white
      set -g status-left '#[fg=blue]#S'

# add load information to the right
      set -g status-right '#[fg=gray]#(uptime | cut -d "," -f 2-)'
      set -g history-limit 100000

# use zsh as startup shell
# set-option -g default-shell /data/data/com.termux/files/usr/bin/zsh
#set-option -g default-shell /bin/zsh

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
