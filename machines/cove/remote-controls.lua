-- Cove's CEC remote is a keyboard: arrows, Enter and Escape.
local mp = require 'mp'
local utils = require 'mp.utils'
local function menu()
    local paused = mp.get_property_bool('pause', false)
    local items = {
        {title = paused and 'Resume' or 'Pause', value = 'cycle pause'},
        {title = 'Back 10 seconds', value = 'seek -10 relative+exact'},
        {title = 'Forward 10 seconds', value = 'seek 10 relative+exact'},
        {title = 'Back 1 minute', value = 'seek -60 relative+exact'},
        {title = 'Forward 1 minute', value = 'seek 60 relative+exact'},
        {title = 'Subtitles', value = 'script-binding uosc/subtitles'},
        {title = 'Audio tracks', value = 'script-binding uosc/audio'},
        {title = 'Browse files', value = 'script-binding uosc/open-file'},
        {title = 'Quit to Steam', value = 'quit'},
    }
    mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json({
        type = 'cove-playback', title = 'Playback', items = items,
        search_style = 'disabled', selected_index = 1,
    }))
end
-- uosc's forced menu bindings take priority while any menu is open.
-- This leaves Escape as close/back and arrows/Enter as menu navigation there.
mp.add_key_binding(nil, 'menu', menu)
