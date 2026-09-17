-- The Hyprland config must load on a machine that has none of the optional
-- pieces.
--
-- This exists because it did not. gestures.lua called
-- `hl.plugin.hyprgrass.gesture()` unguarded, carrying a comment claiming that
-- errored out "harmlessly" when the plugin was missing. It does not: Hyprland
-- reports "Your config has errors", stops loading, and falls back to a handful
-- of emergency binds. And because `require` does not contain an error, every
-- module after the failing one — rules, keybinds, autostart — never ran either.
-- A missing *touchscreen* plugin took out the touchpad, the keybinds and the
-- window rules.
--
-- `luac -p` cannot see any of that: indexing a nil field is valid syntax. So
-- each module is actually executed here, twice: once with everything present,
-- and once on a machine with no plugins loaded at all, which is what a cold
-- boot looks like before autostart's `hyprpm reload` has run.
--
-- Run: lua5.4 scripts/test-hypr-lua.lua

local failures = 0

local function ok(label, cond, detail)
    if cond then
        print("  ok   " .. label)
    else
        print("  FAIL " .. label .. (detail and (": " .. tostring(detail)) or ""))
        failures = failures + 1
    end
end

-- A stub that answers to anything: hl.bind(...), hl.dsp.window.close(),
-- hl.layer_rule{...}. Indexing returns another one, calling returns another
-- one, so a module can walk as deep as it likes.
local function anything()
    local t = {}
    return setmetatable(t, {
        __index = function() return anything() end,
        __call = function() return anything() end,
        __concat = function() return "" end,
        __tostring = function() return "" end,
    })
end

local MODULES = {
    "env", "monitors", "appearance", "animations", "input",
    "gestures", "rules", "keybinds", "autostart",
}

-- Modules are required by name, so the loader has to find them the way
-- Hyprland does, from the config directory.
package.path = "config/hypr/?.lua;" .. package.path

local function run(label, makeHl)
    print(label .. ":")
    for _, name in ipairs(MODULES) do
        -- Fresh globals and a cleared cache per module: require() memoises, and
        -- a module that loaded under the permissive stub would otherwise be
        -- reported as passing under the bare one without running again.
        _G.hl = makeHl()
        package.loaded["lua." .. name] = nil
        package.loaded["lua.config"] = nil
        local good, err = pcall(require, "lua." .. name)
        ok(name .. ".lua loads", good, err)
    end
end

run("with every plugin present", anything)

-- The case that actually broke: Hyprland is up, the plugin table exists, and
-- nothing is in it.
run("with no plugins loaded (cold boot, or hyprpm not rebuilt)", function()
    local h = anything()
    return setmetatable({ plugin = {} }, {
        __index = function(_, k)
            if k == "plugin" then return {} end
            return h[k]
        end,
    })
end)

-- And the case where the host does not offer a plugin table at all.
run("with no plugin table at all", function()
    local h = anything()
    return setmetatable({}, {
        __index = function(_, k)
            if k == "plugin" then return nil end
            return h[k]
        end,
    })
end)

if failures > 0 then
    print(string.format("\n%d failure(s)", failures))
    os.exit(1)
end
print("\nok - the Hyprland config loads with and without its optional plugins")
