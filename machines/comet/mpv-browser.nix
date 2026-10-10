# Pointer-aware browser supplied by the Nix-packaged uosc script in home.nix.
{...}: {
  xdg.configFile = {
    "mpv/mpv.conf".text = ''
      osc=no
      osd-bar=no
    '';
    "mpv/scripts/comet-browser.lua".text = ''
      local mp = require 'mp'
      local utils = require 'mp.utils'
      local card = '/run/media/steamos/USD00'
      mp.observe_property('idle-active', 'bool', function(_, idle)
        if not idle then return end
        mp.add_timeout(0.5, function()
          if not mp.get_property_bool('idle-active') or mp.get_property_number('playlist-count', 0) ~= 0 then return end
          local info = utils.file_info(card)
          local opts = mp.get_property_native('script-opts') or {}
          opts['uosc-default_directory'] = info and info.is_dir and card or '/run/media/steamos'
          mp.set_property_native('script-opts', opts)
          mp.add_timeout(0.1, function() mp.commandv('script-binding', 'uosc/open-file') end)
          if not (info and info.is_dir) then mp.osd_message('SD card is not mounted. Browsing mount directory.', 5) end
        end)
      end)
    '';
    "mpv/script-opts/uosc.conf".text = ''
      default_directory=/run/media/steamos/USD00
      menu_item_height=48
      menu_min_width=900
    '';
    "mpv/input.conf".text = ''
      b script-binding uosc/open-file
      B script-binding uosc/open-file
      GAMEPAD_START script-binding uosc/open-file
      GAMEPAD_DPAD_UP script-binding uosc/menu-prev
      GAMEPAD_DPAD_DOWN script-binding uosc/menu-next
      GAMEPAD_DPAD_LEFT script-binding uosc/menu-back
      GAMEPAD_ACTION_DOWN script-binding uosc/menu-activate
    '';
  };
}
