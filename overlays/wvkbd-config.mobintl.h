#ifndef config_h_INCLUDED
#define config_h_INCLUDED

#define DEFAULT_FONT "Montserrat 14"
#define DEFAULT_ROUNDING 6
#define SHIFT_SPACE_IS_TAB
static const int transparency = 255;

struct clr_scheme schemes[] = {
{
  /* colors */
  /* Catppuccin Mocha */
  .bg = {.bgra = {46, 30, 30, transparency}},      // base #1e1e2e
  .fg = {.bgra = {68, 50, 49, transparency}},      // surface0 #313244
  .high = {.bgra = {90, 71, 69, transparency}},    // surface1 #45475a
  .swipe = {.bgra = {247, 166, 203, 96}},          // mauve #cba6f7
  .text = {.color = 0xFFCDD6F4},                   // text #cdd6f4
  .font = DEFAULT_FONT,
  .rounding = DEFAULT_ROUNDING,
},
{
  /* colors */
  /* Catppuccin Mocha (special keys) */
  .bg = {.bgra = {46, 30, 30, transparency}},      // base #1e1e2e
  .fg = {.bgra = {90, 71, 69, transparency}},      // surface1 #45475a
  .high = {.bgra = {112, 91, 88, transparency}},   // surface2 #585b70
  .swipe = {.bgra = {137, 180, 250, 96}},          // blue #89b4fa
  .text = {.color = 0xFFCDD6F4},                   // text #cdd6f4
  .font = DEFAULT_FONT,
  .rounding = DEFAULT_ROUNDING,
}
};

/* layers is an ordered list of layouts, used to cycle through */
static enum layout_id layers[] = {
  Full, // First layout is the default layout on startup
  HhkbFn,
  Special,
  NumLayouts // signals the last item, may not be omitted
};

/* layers is an ordered list of layouts, used to cycle through */
static enum layout_id landscape_layers[] = {
  Landscape, // First layout is the default layout on startup
  HhkbFn,
  LandscapeSpecial,
  NumLayouts // signals the last item, may not be omitted
};

#endif // config_h_INCLUDED
