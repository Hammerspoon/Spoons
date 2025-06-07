# WindowManagerPlus

A window management spoon for [Hammerspoon](https://www.hammerspoon.org/) that provides tiling and floating window management for macOS.

## Overview

WindowManagerPlus offers four different layout modes and attempts to automatically handle common window management scenarios. It includes basic floating window controls and tries to intelligently detect settings windows and dialogs.

## Features

- **Multiple Layout Modes**: BSP tree, Master/Stack, Stacking, and Floating layouts
- **Floating Window Management**: Corner positioning and size cycling
- **Automatic Window Detection**: Attempts to identify and handle settings windows and dialogs
- **Per-Space Configuration**: Different layouts can be used for different macOS Spaces
- **Visual Indicators**: Optional window focus indicators and layout feedback

## Installation

### Requirements
- macOS 10.12 or later
- [Hammerspoon](https://www.hammerspoon.org/) 0.9.76 or later

### Installation Steps

1. Download the `WindowManagerPlus.spoon` file
2. Double-click to install, or manually copy to `~/.hammerspoon/Spoons/`
3. Add to your `~/.hammerspoon/init.lua`:

```lua
local wm = hs.loadSpoon("WindowManagerPlus")
wm:bindHotkeys({
    cycleLayout = {{"alt", "cmd"}, "space"},
    focus = {{"alt", "cmd"}, "j"},
    toggleFloatingWindow = {{"alt", "cmd"}, "f"},
}):start()
```

## Basic Usage

### Essential Hotkeys

```lua
wm:bindHotkeys({
    -- Core functions
    cycleLayout = {{"alt", "cmd"}, "space"},        -- Switch between layouts
    focus = {{"alt", "cmd"}, "j"},                  -- Focus next window
    toggleFloatingWindow = {{"alt", "cmd"}, "f"},   -- Float/unfloat window
    
    -- Layout adjustments
    toggleLayoutOrientation = {{"alt", "ctrl"}, "t"}, -- Toggle split/orientation
    balanceLayout = {{"alt", "ctrl"}, "b"},           -- Reset window sizes
    
    -- Window resizing (for tiled layouts)
    resizeLeft = {{"alt", "ctrl"}, "left"},
    resizeRight = {{"alt", "ctrl"}, "right"},
    resizeUp = {{"alt", "ctrl"}, "up"},
    resizeDown = {{"alt", "ctrl"}, "down"},
    
    -- Floating window positioning
    floatingPositionUp = {{"alt"}, "up"},             -- Top-left corner
    floatingPositionDown = {{"alt"}, "down"},         -- Bottom-right corner
    floatingPositionLeft = {{"alt"}, "left"},         -- Bottom-left corner
    floatingPositionRight = {{"alt"}, "right"},       -- Top-right corner
    floatingFullscreen = {{"alt"}, "return"},         -- Fullscreen cycling
})
```

## Layout Modes

### BSP (Binary Space Partitioning)
Recursively splits the screen space based on the number of windows. Works well when you have many windows of similar importance.

### Master/Stack
One primary window occupies the main area while other windows are stacked in the remaining space. The master window can be positioned on the left, top, right, or bottom of the screen.

### Stacking
All windows are layered full-screen. Navigate between them using the focus hotkey.

### Floating
Windows can be positioned manually. Includes corner positioning with automatic size cycling and fullscreen size options.

## Configuration

### Basic Configuration

```lua
wm:configure({
    gap = 8,                    -- Pixel gap between windows
    usePerSpaceLayouts = true,  -- Remember layout per Space
})
```

### Color Customization

```lua
wm:configure({
    modeColors = {
        bsp = "#FF6B35",
        master = "#004E98", 
        floating = "#A7C957",
        stacking = "#9B2226"
    }
})
```

### Window Detection

```lua
wm:configure({
    -- Add keywords for automatic settings window detection
    settingsKeywords = {
        "settings", "preferences", "config", "options"
    },
    
    -- Set threshold for small windows (auto-float)
    smallWindowThreshold = {
        width = 450,
        height = 320
    },
    
    -- Exclude specific applications
    excludedApps = {
        "Calculator",
        "Activity Monitor"
    }
})
```

### Performance Tuning

```lua
wm:configure({
    resizing = {
        step = 0.05,       -- Resize increment (5%)
        minRatio = 0.15,   -- Minimum split ratio
        maxRatio = 0.85    -- Maximum split ratio
    },
    
    timing = {
        layoutUpdateDelay = 0.08,  -- Layout update delay
        spaceChangeDelay = 0.12    -- Space change delay
    }
})
```

## Available Hotkey Functions

### Core Functions
- `cycleLayout` - Cycle through available layouts
- `chooseLayout` - Show layout selection menu
- `focus` - Focus next window
- `toggleFloatingWindow` - Toggle floating state for current window

### Layout Control
- `toggleLayoutOrientation` - Toggle split direction (BSP) or master orientation (Master)
- `toggleSplitDirection` - Change BSP split direction
- `toggleMasterOrientation` - Change master window position
- `balanceLayout` - Reset all splits to default ratios
- `showLayoutInfo` - Display current layout information

### Window Resizing
- `resizeLeft`, `resizeRight`, `resizeUp`, `resizeDown` - Resize current window

### Floating Window Management
- `floatingPositionUp/Down/Left/Right` - Position at screen corners with size cycling
- `floatingFullscreen` - Cycle through fullscreen sizes
- `floatingNextScreen` - Move to next screen
- `floatingHalfLeft/Right/Top/Bottom` - Standard half-screen positions
- `floatingCenter` - Center window
- `floatingMaximize` - Maximize window

### Window Arrangement
- `rotateWindowsClockwise/CounterClockwise` - Rotate window positions
- `moveToPosition1` through `moveToPosition6` - Move to specific positions

## Window Detection

WindowManagerPlus attempts to automatically identify certain types of windows:

- Settings and preferences windows (by title keywords)
- System dialogs and alerts
- Small windows that are likely popups or dialogs
- Applications that are better left unmanaged

The detection can be customized by adding keywords or adjusting size thresholds.

## Troubleshooting

**Windows not being managed:**
- Check if the application is in the excluded apps list
- Verify the window isn't being detected as a settings/dialog window
- Try manually toggling the floating state

**Layout not updating:**
- Restart Hammerspoon
- Check the Hammerspoon console for error messages
- Try using the balance function to force a layout refresh

**Performance issues:**
- Increase the layout update delay in configuration
- Add problematic applications to the excluded apps list
- Disable visual indicators if not needed

## Technical Notes

WindowManagerPlus saves its configuration and window state automatically. Settings persist across Hammerspoon restarts and macOS reboots.

The spoon uses Hammerspoon's window filtering and space management APIs. It attempts to be compatible with macOS's native window management features like Mission Control and Spaces.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

This project draws inspiration from other tiling window managers in the macOS ecosystem, particularly [Amethyst](https://github.com/ianyh/Amethyst), [yabai](https://github.com/koekeishiya/yabai), [AeroSpace](https://github.com/nikitabobko/AeroSpace) and [EnhancedSpaces](https://github.com/franzbu/EnhancedSpaces.spoon/tree/main). Built using the Hammerspoon automation platform.