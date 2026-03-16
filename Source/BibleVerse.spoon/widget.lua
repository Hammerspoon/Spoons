--- Widget rendering functions.
local M = {}

function M.calculate_position(screen_frame, config, screen_name)
    local pos = config.position[screen_name] or config.position.default
    local x = pos.x >= 0 and pos.x or (screen_frame.w + pos.x - config.width)
    local y = pos.y >= 0 and pos.y or (screen_frame.h + pos.y - config.height)
    return { x = screen_frame.x + x, y = screen_frame.y + y }
end

function M.create_elements(text, reference, config)
    local bg = config.background
    local font = config.font
    return {
        { id = "bg", type = "rectangle", action = "fill", trackMouseUp = true, roundedRectRadii = { xRadius = bg.corner_radius, yRadius = bg.corner_radius }, fillColor = { red = bg.color.red, green = bg.color.green, blue = bg.color.blue, alpha = bg.alpha } },
        { type = "rectangle", action = "stroke", roundedRectRadii = { xRadius = bg.corner_radius, yRadius = bg.corner_radius }, strokeColor = { red = 0.3, green = 0.4, blue = 0.5, alpha = 0.5 }, strokeWidth = 1 },
        { type = "text", text = text, textColor = font.color, textSize = font.size, textFont = font.name, textAlignment = "left", frame = { x = "5%", y = "8%", w = "90%", h = "68%" } },
        { type = "text", text = "— " .. reference, textColor = font.reference_color, textSize = font.reference_size, textFont = font.name, textAlignment = "right", frame = { x = "5%", y = "78%", w = "90%", h = "18%" } }
    }
end

function M.render(state, text, reference, config, verse_data)
    if state.canvas then state.canvas:delete() end
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()
    local pos = M.calculate_position(frame, config, screen:name())
    local canvas = hs.canvas.new({ x = pos.x, y = pos.y, w = config.width, h = config.height })
    canvas:appendElements(M.create_elements(text, reference, config))
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    canvas:mouseCallback(function(c, msg, id, x, y)
        if msg == "mouseUp" and verse_data then
            local url = "https://bolls.life/" .. verse_data.translation .. "/" .. verse_data.book .. "/" .. verse_data.chapter .. "/"
            hs.urlevent.openURL(url)
        end
    end)
    canvas:canvasMouseEvents(false, true, false, false)
    canvas:show()
    return canvas
end

function M.destroy(canvas)
    if canvas then canvas:delete() end
end

return M
