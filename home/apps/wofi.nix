{
  programs.wofi = {
    enable = true;
    settings = {
      matching = "fuzzy";
      image_size = 28;
      allow_markup = true;
      allow_images = true;
      width = 420;
      height = 550;
      no_actions = true;
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      layerrule = "animation fade, ^(wofi)$";
    };
  };
}
