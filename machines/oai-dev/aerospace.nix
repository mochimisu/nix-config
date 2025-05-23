{
  services.aerospace = {
    enable  = true;                   # toggles all launchd glue
    settings = {
      # start-at-login = true;          # auto-launch on login
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      accordion-padding = 10;
      
      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      on-focus-changed = ["move-mouse window-lazy-center"];

      mode.main.binding = {

        ## layout toggles
        "alt-m"        = "enable toggle";                    # suspend tiling
        # "alt-r"        = "layout accordion horizontal vertical"; # accordion
        "alt-r"        = "fullscreen"; # accordion
        "alt-f"        = "layout tiles horizontal vertical";     # tiles

        ## focus (movefocus)
        "alt-w"        = "focus up";
        "alt-a"        = "focus left";
        "alt-s"        = "focus down";
        "alt-d"        = "focus right";

        ## swap window (swapwindow)
        "alt-shift-w"  = "move up";
        "alt-shift-a"  = "move left";
        "alt-shift-s"  = "move down";
        "alt-shift-d"  = "move right";

        ## move window (movewindow)
        "alt-ctrl-w"   = "join-with up";
        "alt-ctrl-a"   = "join-with left";
        "alt-ctrl-s"   = "join-with down";
        "alt-ctrl-d"   = "join-with right";

        ## workspaces
        "alt-1"        = "workspace 1";
        "alt-2"        = "workspace 2";
        "alt-3"        = "workspace 3";
        "alt-4"        = "workspace 4";
        "alt-5"        = "workspace 5";
        "alt-6"        = "workspace 6";
        "alt-7"        = "workspace 7";
        "alt-8"        = "workspace 8";
        "alt-9"        = "workspace 9";
        "alt-0"        = "workspace 10";
        "alt-shift-1"  = ["move-node-to-workspace 1" "workspace 1"];
        "alt-shift-2"  = ["move-node-to-workspace 2" "workspace 2"];
        "alt-shift-3"  = ["move-node-to-workspace 3" "workspace 3"];
        "alt-shift-4"  = ["move-node-to-workspace 4" "workspace 4"];
        "alt-shift-5"  = ["move-node-to-workspace 5" "workspace 5"];
        "alt-shift-6"  = ["move-node-to-workspace 6" "workspace 6"];
        "alt-shift-7"  = ["move-node-to-workspace 7" "workspace 7"];
        "alt-shift-8"  = ["move-node-to-workspace 8" "workspace 8"];
        "alt-shift-9"  = ["move-node-to-workspace 9" "workspace 9"];
        "alt-shift-0"  = ["move-node-to-workspace 10" "workspace 10"];

      };
    };
  };
}
