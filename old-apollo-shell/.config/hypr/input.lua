hl.config({
 input = {
  kb_layout = "us",
  follow_mouse = 1,
  sensitivity = 0,
  touchpad = {
   natural_scroll = false, -- traditional scroll direction
   tap_to_click = true,
   disable_while_typing = false,
   clickfinger_behavior = true,
  },
 },
})

-- 3-finger horizontal swipe to switch workspaces
hl.gesture({
 fingers = 3,
 direction = "horizontal",
 action = "workspace",
})
