--[[
    KiciaLib-Bundle.lua  -  reine GUI-Bibliothek, gibt Library zurueck
    =========================================================================
    Version 1.0

    In dieser Datei steckt NICHTS von deinem Code. Sie endet mit
    "return Library" und ist gedacht fuer das LinoriaLib-Muster:

        local Library = loadstring(game:HttpGet('RAW_URL/KiciaLib-Bundle.lua'))()
        -- >>> ab hier dein Code mit den Buttons <<<

    Ohne Hosting stattdessen direkt ausfuehren:
        lokale Variante ohne Workspace:  MEIN-SCRIPT.LUA  (alles in einer Datei)
        zwei Dateien im Workspace:       KiciaLib.lua + KiciaUI.lua

    Dokumentation:  KiciaLib-Doku.txt
    Tutorial:       KiciaLib-Tutorial.txt
--]]

-- ============================================================================
--  TEIL 1  -  Kicia-UI-Engine (extrahiert, 501.738 Bytes)
-- ============================================================================
local __KICIA_UI_SRC = [=[
-- KiciaUI.lua -- extracted GUI library
-- source: sigmakicia.txt lines 1-18833 (Kicia's menu, widgets, theme, config layer)
-- load:  local UI = loadstring(readfile('KiciaUI.lua'))()
-- entry: local A = UI.aE(); local menu = A.Menu.new{ Title=..., Directory=... }
-- note:  this file creates no menu; your script owns the menu and must tear it
--        down itself: menu:Unload() fires Menu.new's OnUnload, then menu:Destroy().
-- patch: display-only, in fn37 at line 4634 (the slider): values are formatted to
--        their Step's decimals, so 0.35 prints as 0.35 not 0.35000000000000003.
-- map:   source = sigmakicia.txt 1-18833; offset N-10 for N<4634, N-21 for N>4648.

if getgenv().KiciaRebuild and getgenv().KiciaRebuild.Unload then
    pcall(getgenv().KiciaRebuild.Unload)
end
if not game:IsLoaded() then game.Loaded:Wait() end
print("[Kicia] script file executing, PlaceId=" .. tostring(game.PlaceId))

local K: { [string]: any } = { connections = {}, cleanups = {}, destroyed = false }
getgenv().KiciaRebuild = K

local Players = game:GetService("Players")
local _ReplicatedStorage = game:GetService("ReplicatedStorage")
local _RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local _CollectionService = game:GetService("CollectionService")
local _HttpService = game:GetService("HttpService")
local _SoundService = game:GetService("SoundService")
local _Lighting = game:GetService("Lighting")
local _player = Players.LocalPlayer

local rawget, rawset = rawget, rawset

function K.fn(name)
    local v
    pcall(function() v = getgenv()[name] end)
    if type(v) ~= "function" then pcall(function() v = getgenv()[name] end) end
    return type(v) == "function" and v or nil
end

local getthreadidentity_ = K.fn("getthreadidentity") or K.fn("getidentity")
local setthreadidentity_ = K.fn("setthreadidentity") or K.fn("setidentity")
local _sethiddenproperty = K.fn("sethiddenproperty")
local gethui_ = K.fn("gethui")
local function identity(n)
    if not setthreadidentity_ then return function() end end
    local old = getthreadidentity_ and getthreadidentity_() or nil
    pcall(setthreadidentity_, n)
    return function() if old then pcall(setthreadidentity_, old) end end
end
K.identity = identity
local function hudParent()
    local ok, h = pcall(function() return gethui_ and gethui_() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end
K.hudParent = hudParent

function K.track(c) K.connections[#K.connections + 1] = c; return c end
function K.onUnload(f) K.cleanups[#K.cleanups + 1] = f end

--==========================================================================
--  Signal / Trove (Kicia's own small versions)
--==========================================================================
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _handlers = {} }, Signal) end
function Signal:Connect(fn)
    local h = { fn = fn, connected = true }
    table.insert(self._handlers, h)
    local sig = self
    return {
        Connected = true,
        Disconnect = function(c)
            if not h.connected then return end
            h.connected = false
            c.Connected = false
            local i = table.find(sig._handlers, h)
            if i then table.remove(sig._handlers, i) end
        end,
    }
end
function Signal:Once(fn)
    local c
    c = self:Connect(function(...) c:Disconnect(); fn(...) end)
    return c
end
function Signal:Fire(...)
    local list = table.clone(self._handlers)
    for _, h in ipairs(list) do
        if h.connected then task.spawn(h.fn, ...) end
    end
end
function Signal:FireSync(...)
    for _, h in ipairs(table.clone(self._handlers)) do
        if h.connected then h.fn(...) end
    end
end
function Signal:Destroy() table.clear(self._handlers) end
K.Signal = Signal

local Trove = {}
Trove.__index = Trove
function Trove.new(name) return setmetatable({ _name = name, _items = {} }, Trove) end
local function cleanItem(o)
    local t = typeof(o)
    if t == "RBXScriptConnection" then o:Disconnect()
    elseif t == "Instance" then pcall(function() o:Destroy() end)
    elseif t == "thread" then pcall(task.cancel, o)
    elseif type(o) == "function" then pcall(o)
    elseif type(o) == "table" then
        --  some objects (Kicia's signal connections) error on unknown fields
        local function member(k)
            local ok, v = pcall(function() return o[k] end)
            return ok and type(v) == "function" and v or nil
        end
        local cancel, getStatus = member("cancel"), member("getStatus")
        if cancel and getStatus then pcall(cancel, o); return end
        local destroy = member("Destroy")
        if destroy then pcall(destroy, o); return end
        local disconnect = member("Disconnect")
        if disconnect then pcall(disconnect, o) end
    end
end
function Trove:Add(o) table.insert(self._items, o); return o end
function Trove:Connect(sig, fn) return self:Add(sig:Connect(fn)) end
function Trove:Extend() return self:Add(Trove.new(self._name)) end
function Trove:Remove(o, keep)
    local i = table.find(self._items, o)
    if i then
        table.remove(self._items, i)
        if not keep then cleanItem(o) end
    end
end
--  Promise held until it settles; cancelled if the trove is cleaned first.
function Trove:AddPromise(promise)
    if tostring(promise:getStatus()) == "Started" then
        self:Add(promise)
        promise:finally(function()
            if not self._cleaning then self:Remove(promise, true) end
        end)
    end
    return promise
end
--  Sub-trove that cleans itself up when `instance` is destroyed.
function Trove:AttachExtend(instance)
    local sub = self:Extend()
    sub:Connect(instance.Destroying, function() self:Remove(sub) end)
    return sub
end
function Trove:Clean()
    local items = self._items
    self._items = {}
    self._cleaning = true
    for i = #items, 1, -1 do cleanItem(items[i]) end
    self._cleaning = false
end
Trove.Destroy = Trove.Clean
K.Trove = Trove

--==========================================================================
--  Kicia's constant pool (v86[...]) as recovered from usage in the dump
--==========================================================================
local C = {
    [3] = "Toggle", [9] = 20, [12] = 12, [18] = "0", [26] = 4, [34] = true, [44] = "Enabled",
    [45] = 90, [48] = 2, [53] = 20, [55] = "Mode", [56] = 2, [62] = 0.1, [63] = 1, [68] = "table",
    [75] = "None", [83] = 64, [91] = 100, [95] = "number", [101] = 0.5, [108] = 255, [116] = "boolean",
    [118] = 16, [122] = 8, [126] = 0.15, [127] = "CFrame", [128] = "Frame", [133] = 10, [137] = 256,
    [147] = 0.1, [149] = 1, [153] = false, [155] = 3, [160] = 50, [162] = 8, [165] = "string",
    [170] = 9, [173] = 0.88, [175] = 5, [186] = 0, [192] = 30, [195] = 0.7,
}
K.C = C

--==========================================================================
--  Kicia's own UI, settings store and Combat menu (lifted from the dump)
--==========================================================================
local v86 = {
    [2] = "ReactiveStore",
    [3] = "Toggle",
    [4] = "UIListLayout",
    [5] = "BackgroundColor3",
    [6] = 0,
    [7] = 60,
    [8] = 60,
    [9] = 20,
    [12] = 12,
    [13] = 14,
    [14] = "Settings",
    [15] = 120,
    [16] = "min",
    [17] = 200,
    [18] = "0",
    [19] = 200,
    [20] = "Vector3",
    [21] = "Always",
    [22] = "",
    [23] = 1.4707963267948965,
    [24] = "Roboto",
    [25] = 24,
    [26] = 4,
    [27] = "Color",
    [28] = 0.2,
    [29] = "Size",
    [30] = 0.35,
    [31] = 29,
    [32] = 24,
    [33] = "Button",
    [34] = true,
    [35] = "ConfigManager",
    [36] = "ApplyMigrations",
    [37] = "TextBounds",
    [38] = "DeleteFile",
    [39] = "Slider",
    [40] = "...",
    [42] = "left",
    [43] = "Proggy Clean",
    [44] = "Enabled",
    [45] = 90,
    [46] = "UIGradient",
    [47] = "CanvasGroup",
    [48] = 0.3,
    [49] = 2,
    [50] = "Side",
    [51] = " ",
    [52] = "BottomRight",
    [53] = 92,
    [54] = 6,
    [55] = "Mode",
    [56] = 2,
    [57] = "TextColor",
    [58] = 80,
    [59] = "Font",
    [60] = 29,
    [61] = 20,
    [62] = 0.1,
    [63] = 1,
    [64] = "ScrollingFrame",
    [65] = 200,
    [66] = 0.5,
    [67] = 100,
    [68] = "table",
    [69] = "Catalog unavailable",
    [70] = "GradientDark",
    [71] = 10,
    [72] = 12,
    [73] = "Keybind",
    [74] = 0.9,
    [75] = "None",
    [76] = "LoadFromFile",
    [77] = "FireServer",
    [78] = 720,
    [79] = 255,
    [80] = "Text",
    [81] = 1,
    [82] = "Realize() can only be called on the root",
    [83] = 64,
    [84] = 0.5,
    [85] = "UIStroke",
    [87] = 0.8,
    [88] = "TabHighlight",
    [89] = "Loading",
    [90] = "Gradient",
    [91] = 100,
    [92] = "TextButton",
    [93] = "ColorSequence",
    [94] = "Options",
    [95] = "number",
    [96] = "Unselected",
    [97] = "Mode",
    [98] = "UICorner",
    [99] = "ExportToJson",
    [100] = 14,
    [101] = 0.5,
    [102] = 231,
    [103] = 52,
    [104] = "Fonts",
    [105] = 0.85,
    [106] = "Menu Keybind",
    [107] = 40,
    [108] = 255,
    [109] = 77,
    [110] = 70,
    [111] = "Fetching items...",
    [112] = "Invisible",
    [113] = "UIPadding",
    [114] = "primary",
    [115] = "Color3",
    [116] = "boolean",
    [118] = 16,
    [119] = 159,
    [120] = "Outline",
    [121] = "ImageButton",
    [122] = 8,
    [123] = 19,
    [124] = "X",
    [125] = "Proggy Tiny",
    [126] = 0.15,
    [127] = "CFrame",
    [128] = "Frame",
    [129] = "Show Watermark",
    [131] = "AbsoluteSize",
    [132] = "Breathing",
    [133] = 10,
    [134] = "GradientTop",
    [135] = "TextLabel",
    [136] = "Unselected Text",
    [137] = 256,
    [138] = 0.85,
    [139] = "Accent",
    [140] = "danger",
    [141] = "GradientDeep",
    [142] = "Silent Load",
    [143] = 32,
    [144] = 20,
    [145] = "Dialog has been destroyed",
    [146] = "ImageLabel",
    [147] = 0.1,
    [148] = "TextBox",
    [149] = 1,
    [150] = "stop",
    [151] = "family",
    [153] = false,
    [154] = "ScrollBarImageColor3",
    [155] = 3,
    [156] = "ImageColor3",
    [157] = 20,
    [158] = "secondary",
    [159] = 20,
    [160] = 50,
    [161] = 0.5,
    [162] = 8,
    [163] = 80,
    [164] = "hue",
    [165] = "string",
    [166] = "family",
    [167] = "TextColor3",
    [168] = "ElementBackground",
    [169] = "FromJson",
    [170] = 9,
    [172] = "none",
    [173] = 0.88,
    [174] = "Unselected",
    [175] = 5,
    [176] = "UISizeConstraint",
    [177] = "Try a different search.",
    [178] = "ElementBackground",
    [181] = 10,
    [182] = "HttpService",
    [183] = 72,
    [184] = "Color",
    [186] = 0,
    [187] = "GradientMid",
    [189] = "Position",
    [190] = "Search...",
    [191] = "TabShadow",
    [192] = 30,
    [193] = 0,
    [194] = "Hold",
    [195] = 0.7,
    [196] = "Viewport",
    [197] = "Y",
    [198] = 400,
    [199] = "Unload",
    [200] = 26,
}
--  Environment Kicia's modules expect: the module table and the aliases its
--  loader set up before them (v102 = rawget, v103 = rawset, v107 = pcall).
local tbl17: { [string]: any } = { cache = {} }
local v102, v103, v107 = rawget, rawset, pcall
--  The obfuscator's integrity counters. Every check in the lifted code has one
--  branch that hangs and one that runs the real code; these values sit inside
--  the window where all of them take the real branch (n26 in [4790, 4809),
--  n25 in [3866, 3887]).
local n25, n26 = 3870, 4800
local flag2, flag3 = true, true
local function n29(...) return 0 end
local cloneref = K.fn("cloneref") or function(x) return x end
local gethui = K.fn("gethui") or function() return game:GetService("CoreGui") end
local getthreadidentity = K.fn("getthreadidentity") or K.fn("getidentity") or function() return 8 end
local setthreadidentity = K.fn("setthreadidentity") or K.fn("setidentity") or function() end
--  The rest of the loader's locals (clonefunction'd so hooks on them can't see us).
local function clonefn(f)
    local c = K.fn("clonefunction")
    if c and f then
        local ok, r = pcall(c, f)
        if ok and r then return r end
    end
    return f
end
local fireServer = clonefn(Instance.new("RemoteEvent").FireServer)
local fireServer2 = clonefn(Instance.new("UnreliableRemoteEvent").FireServer)
local v104 = clonefn(K.fn("sethiddenproperty"))
local v108 = clonefn(K.fn("setfflag")) or function() end
local v109 = clonefn(K.fn("isexecutorclosure")) or function() return false end
local v110 = clonefn(K.fn("setrawmetatable")) or setmetatable
local v111 = clonefn(K.fn("getrawmetatable")) or getmetatable
local v112 = clonefn(v111(game).__newindex)
local v113 = clonefn(v111(game).__index)
local v114 = clonefn(game.FindFirstChildOfClass)
local function _n27() return 0 end
local firetouchinterest = K.fn("firetouchinterest") or function() end
local getconnections = K.fn("getconnections") or function() return {} end
local setclipboard = K.fn("setclipboard") or K.fn("toclipboard") or function() end
local InstanceHandle
pcall(function() InstanceHandle = getgenv().InstanceHandle end)
if InstanceHandle == nil then pcall(function() InstanceHandle = getgenv().InstanceHandle end) end
if InstanceHandle == nil then InstanceHandle = { new = function(x) return x end } end
--  The modules the decompiler lost (their bodies are `fn35(...) end` in
--  the dump), rebuilt from how the rest of Kicia's code calls them.

--  k: Trove
tbl17.k = function() return { new = function(name) return Trove.new(name) end } end

--  w: viewport / pointer / key / path helpers
do
    local UIS = UserInputService
    local _GuiService = game:GetService("GuiService")
    local function camera() return workspace.CurrentCamera end
    local W = {}
    function W.appendPath(path, key)
        local p = table.clone(path)
        table.insert(p, key)
        return p
    end
    function W.currentViewportSize()
        local c = camera()
        return c and c.ViewportSize or Vector2.new(1920, 1080)
    end
    function W.connectCurrentCameraViewport(trove, cb)
        local inner = trove:Extend()
        local function bind()
            inner:Clean()
            local c = camera()
            if c == nil then return end
            inner:Connect(c:GetPropertyChangedSignal("ViewportSize"), function() cb(c.ViewportSize) end)
            cb(c.ViewportSize)
        end
        trove:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bind)
        bind()
    end
    function W.absoluteToLayerOffset(layer, pos)
        return pos - layer.AbsolutePosition
    end
    function W.clampOffsetToViewport(x, y, size)
        local vp = W.currentViewportSize()
        return math.clamp(x, 0, math.max(0, vp.X - size.X)), math.clamp(y, 0, math.max(0, vp.Y - size.Y))
    end
    function W.clampGuiToViewport(gui)
        local vp = W.currentViewportSize()
        local ap, as = gui.AbsolutePosition, gui.AbsoluteSize
        local dx = math.clamp(ap.X, 0, math.max(0, vp.X - as.X)) - ap.X
        local dy = math.clamp(ap.Y, 0, math.max(0, vp.Y - as.Y)) - ap.Y
        if dx ~= 0 or dy ~= 0 then
            local p = gui.Position
            gui.Position = UDim2.new(p.X.Scale, p.X.Offset + dx, p.Y.Scale, p.Y.Offset + dy)
        end
    end
    function W.snapPosition(u)
        return UDim2.new(u.X.Scale, math.round(u.X.Offset), u.Y.Scale, math.round(u.Y.Offset))
    end
    function W.onScreenKeyboardTop()
        local ok, visible = pcall(function() return UIS.OnScreenKeyboardVisible end)
        if not ok or not visible then return nil end
        local ok2, pos = pcall(function() return UIS.OnScreenKeyboardPosition end)
        return ok2 and pos and pos.Y or nil
    end
    function W.connectOnScreenKeyboard(trove, cb)
        pcall(function() trove:Connect(UIS:GetPropertyChangedSignal("OnScreenKeyboardVisible"), cb) end)
        pcall(function() trove:Connect(UIS:GetPropertyChangedSignal("OnScreenKeyboardPosition"), cb) end)
    end
    function W.getPointerPosition()
        return UIS:GetMouseLocation()
    end
    function W.matchesPointerDrag(input, started, movement)
        if started ~= nil and started.UserInputType == Enum.UserInputType.Touch then return input == started end
        return input.UserInputType == movement
    end
    function W.round(v, step)
        if step == nil or step == 0 then return v end
        return math.round(v / step) * step
    end
    W.KeyNames = {
        [Enum.UserInputType.MouseButton1] = "MB1", [Enum.UserInputType.MouseButton2] = "MB2",
        [Enum.UserInputType.MouseButton3] = "MB3", [Enum.KeyCode.LeftShift] = "LShift",
        [Enum.KeyCode.RightShift] = "RShift", [Enum.KeyCode.LeftControl] = "LCtrl",
        [Enum.KeyCode.RightControl] = "RCtrl", [Enum.KeyCode.LeftAlt] = "LAlt", [Enum.KeyCode.RightAlt] = "RAlt",
    }
    function W.serializeKey(key)
        if typeof(key) ~= "EnumItem" then return nil end
        return tostring(key.EnumType) .. "." .. key.Name
    end
    function W.deserializeKey(s)
        if type(s) ~= "string" then return nil end
        local kind, name = s:match("^(%w+)%.(%w+)$")
        if kind == nil then return nil end
        local ok, v = pcall(function() return Enum[kind][name] end)
        return ok and v or nil
    end
    function W.findScrollingAncestor(inst)
        local p = inst and inst.Parent
        while p ~= nil do
            if p:IsA("ScrollingFrame") then return p end
            p = p.Parent
        end
        return nil
    end
    function W.isEffectivelyVisible(gui)
        local p = gui
        while p ~= nil and p ~= game do
            if p:IsA("GuiObject") and not p.Visible then return false end
            if p:IsA("LayerCollector") then return p.Enabled end
            p = p.Parent
        end
        return false
    end
    function W.ensureStorageDirectories(dir)
        local isf, mkf = K.fn("isfolder"), K.fn("makefolder")
        if not (isf and mkf) or type(dir) ~= "string" then return end
        local function make(path)
            local acc
            for part in path:gmatch("[^/]+") do
                acc = acc and (acc .. "/" .. part) or part
                pcall(function() if not isf(acc) then mkf(acc) end end)
            end
        end
        make(dir)
        make(dir .. "/configs")
    end
    tbl17.w = function() return W end
end

--  P: two-way link between a control and a settings path. Sliders ask for
--  Debounce so dragging writes once per short burst instead of every frame.
do
    local P = {}
    function P.bind(trove, config, control, path, opts)
        local debounce = opts ~= nil and opts.Debounce == true
        local writeBack = opts ~= nil and opts.WriteBack or nil
        control:Set(config:Get(path), true)
        trove:Connect(config:Changed(path), function(v) control:Set(v, true) end)
        local pending, scheduled = nil, false
        local function write(v)
            if writeBack then writeBack(v) else config:Set(path, v) end
        end
        trove:Connect(control.Changed, function(v)
            if not debounce then write(v); return end
            pending = v
            if scheduled then return end
            scheduled = true
            task.delay(0.05, function()
                scheduled = false
                write(pending)
            end)
        end)
    end
    tbl17.P = function() return P end
end

--  c5: the critically damped Spring (Position, Velocity, Target, Speed, Damper).
do
    local Spring = {}
    local function posVel(self, now)
        local p0, v0, p1, d, s = self._p0, self._v0, self._target, self._damper, self._speed
        local t = s * (now - self._t0)
        local d2 = d * d
        local h, si, co
        if d2 < 1 then
            h = math.sqrt(1 - d2)
            local ep = math.exp(-d * t) / h
            co, si = ep * math.cos(h * t), ep * math.sin(h * t)
        elseif d2 == 1 then
            h = 1
            local ep = math.exp(-d * t) / h
            co, si = ep, ep * t
        else
            h = math.sqrt(d2 - 1)
            local u, v = math.exp((-d + h) * t) / (2 * h), math.exp((-d - h) * t) / (2 * h)
            co, si = u + v, u - v
        end
        local a0, a1 = h * co + d * si, 1 - (h * co + d * si)
        local a2 = si / s
        local b0, b1, b2 = -s * si, s * si, h * co - d * si
        return a0 * p0 + a1 * p1 + a2 * v0, b0 * p0 + b1 * p1 + b2 * v0
    end
    function Spring.new(initial, clock)
        initial = initial or 0
        clock = clock or os.clock
        return setmetatable({ _clock = clock, _t0 = clock(), _p0 = initial, _v0 = 0 * initial, _target = initial,
            _damper = 1, _speed = 1 }, Spring)
    end
    function Spring:Impulse(v) self.Velocity = self.Velocity + v end
    function Spring:SetTarget(value, doNotAnimate)
        if doNotAnimate then
            self._p0, self._v0, self._target, self._t0 = value, 0 * value, value, self._clock()
        else
            self.Target = value
        end
    end
    function Spring:TimeSkip(delta)
        local now = self._clock()
        local p, v = posVel(self, now + delta)
        self._p0, self._v0, self._t0 = p, v, now
    end
    Spring.__index = function(self, k)
        if Spring[k] then return Spring[k] end
        if k == "Value" or k == "Position" or k == "p" then local p = posVel(self, self._clock()); return p
        elseif k == "Velocity" or k == "v" then local _, v = posVel(self, self._clock()); return v
        elseif k == "Target" or k == "t" then return self._target
        elseif k == "Damper" or k == "d" then return self._damper
        elseif k == "Speed" or k == "s" then return self._speed
        elseif k == "Clock" then return self._clock end
        return nil
    end
    Spring.__newindex = function(self, k, v)
        local now = self._clock()
        if k == "Value" or k == "Position" or k == "p" then
            local _, vel = posVel(self, now)
            self._p0, self._v0 = v, vel
        elseif k == "Velocity" or k == "v" then
            local pos = posVel(self, now)
            self._p0, self._v0 = pos, v
        elseif k == "Target" or k == "t" then
            local pos, vel = posVel(self, now)
            self._p0, self._v0, self._target = pos, vel, v
        elseif k == "Damper" or k == "d" then
            local pos, vel = posVel(self, now)
            self._p0, self._v0, self._damper = pos, vel, v
        elseif k == "Speed" or k == "s" then
            local pos, vel = posVel(self, now)
            self._p0, self._v0, self._speed = pos, vel, v < 0 and 0 or v
        elseif k == "Clock" then
            local pos, vel = posVel(self, now)
            self._clock, self._t0, self._p0, self._v0 = v, v(), pos, vel
            return
        else
            rawset(self, k, v)
            return
        end
        self._t0 = now
    end
    tbl17.c5 = function() return Spring end
end

--  ca: the AI aim mode's network weights. They are not in the dump; cc falls
--  back to Linear movement without them.
tbl17.ca = function() return nil end

--  hH: weather emitter specs and lightning / thunder constants. Kicia's own
--  values are not in the dump; these fit every field the weather module reads
--  and use particle textures that ship with Roblox.
do
    local soft = "rbxasset://textures/particles/smoke_main.dds"
    local sparkle = "rbxasset://textures/particles/sparkles_main.dds"
    local function spec(t)
        t.RotationMin, t.RotationMax = t.RotationMin or 0, t.RotationMax or 360
        t.RotationSpeedMin, t.RotationSpeedMax = t.RotationSpeedMin or -40, t.RotationSpeedMax or 40
        return t
    end
    local W = {
        EmitterSpecsByPreset = {
            Snow = {
                spec({ Texture = soft, TransparencyMax = 0.15, LifetimeMin = 6, LifetimeMax = 9, BaseRate = 220,
                    SpeedMin = 6, SpeedMax = 10, SizeStart = 0.35, SizeEnd = 0.25, BaseSpread = 0.4, BaseAccelerationY = -1 }),
                spec({ Texture = sparkle, TransparencyMax = 0.35, LifetimeMin = 6, LifetimeMax = 9, BaseRate = 60,
                    SpeedMin = 5, SpeedMax = 8, SizeStart = 0.2, SizeEnd = 0.15, BaseSpread = 0.6, BaseAccelerationY = -0.5 }),
            },
            Rain = {
                spec({ Texture = soft, TransparencyMax = 0.35, LifetimeMin = 1.2, LifetimeMax = 1.8, BaseRate = 600,
                    SpeedMin = 70, SpeedMax = 90, SizeStart = 0.12, SizeEnd = 0.1, BaseSpread = 0.05, BaseAccelerationY = -40,
                    RotationMin = 0, RotationMax = 0, RotationSpeedMin = 0, RotationSpeedMax = 0,
                    Orientation = Enum.ParticleOrientation.VelocityParallel }),
            },
            Blizzard = {
                spec({ Texture = soft, TransparencyMax = 0.1, LifetimeMin = 3, LifetimeMax = 5, BaseRate = 700,
                    SpeedMin = 18, SpeedMax = 28, SizeStart = 0.3, SizeEnd = 0.2, BaseSpread = 0.8, BaseAccelerationY = -6 }),
                spec({ Texture = soft, TransparencyMax = 0.75, LifetimeMin = 3, LifetimeMax = 5, BaseRate = 120,
                    SpeedMin = 14, SpeedMax = 22, SizeStart = 3, SizeEnd = 5, BaseSpread = 1, BaseAccelerationY = -2 }),
            },
        },
        LightningPresetSet = { Rain = true },
        LightningRadiusMin = 20,
        LightningGroundDrop = 40,
        LightningRayLength = 1000,
        LightningJitter = 30,
        ThunderSoundId = "",
        ThunderSpeed = 340,
        ThunderVolumeFloor = 0.2,
        ThunderFalloff = 600,
        ThunderPitchMin = 0.85,
        ThunderPitchMax = 1.1,
    }
    tbl17.hH = function() return W end
end

--  iQ: the Visuals > Player ESP page. Its builder is lost; rebuilt with the
--  same menu calls Kicia's other pages use, over Kicia's own Esp settings.
tbl17.iQ = function()
    return function(_, _, grid)
        local enable = tbl17.h6()
        local fonts = tbl17.az().Order
        local function P(...) return { "Esp", ... } end

        local main = grid:AddSection({ Title = "Player ESP", Side = "left" })
        enable(main, "Enable ESP", { "Always", "Toggle", "Hold" }, P("Main"), true)
        main:AddDropdown({ Label = "Box Fit", Options = { "Static", "Dynamic" }, Config = P("Main", "Mode") })

        local look = grid:AddSection({ Title = "Text", Side = "right" })
        look:AddToggle({ Label = "Use Display Names", Config = P("Settings", "UseDisplayName") })
        look:AddDropdown({ Label = "Font", Options = fonts, Config = P("Settings", "Font") })
        look:AddSlider({ Label = "Font Size", Min = 8, Max = 32, Config = P("Settings", "FontSize") })
        look:AddDropdown({ Label = "Text Case", Options = { "Standard", "UPPERCASE", "lowercase" }, Config = P("Settings", "TextCase") })
        look:AddDropdown({ Label = "Text Surround", Options = { "None", "[]", "()", "<>", "{}" }, Config = P("Settings", "TextSurround") })
        look:AddDivider({ Label = "Flags" })
        look:AddDropdown({ Label = "Flag Font", Options = fonts, Config = P("Settings", "FlagFont") })
        look:AddSlider({ Label = "Flag Font Size", Min = 6, Max = 24, Config = P("Settings", "FlagFontSize") })
        look:AddDropdown({ Label = "Flag Text Case", Options = { "Standard", "UPPERCASE", "lowercase" }, Config = P("Settings", "FlagTextCase") })
        look:AddDropdown({ Label = "Flag Surround", Options = { "None", "[]", "()", "<>", "{}" }, Config = P("Settings", "FlagTextSurround") })
        look:AddGroup({ Source = look:AddToggle({ Label = "Scale With Distance", Config = P("Settings", "DistanceScaling") }) })
            :AddSlider({ Label = "Reference Distance", Min = 10, Max = 300, Config = P("Settings", "DistanceScalingRef") })

        local function side(title, key, where)
            local s = grid:AddSection({ Title = title, Side = where })
            local function Q(...) return P(key, ...) end
            --  Kicia's ESP draws a side only when Main AND this side are enabled
            enable(s, "Enable " .. title .. " ESP", { "Always", "Toggle", "Hold" }, P(key), true)
            local function color(label, path, transparency)
                local t = s:AddToggle({ Label = label, Config = Q(path, "Enabled") })
                s:AddColor({ Row = t.Row, Config = Q(path, "Color"), Transparency = transparency and Q(path, "Transparency") or nil, Alpha = transparency or nil })
                return t
            end
            local function gradient(label, path)
                local t = s:AddToggle({ Label = label, Config = Q(path, "Enabled") })
                s:AddColor({ Row = t.Row, Gradient = "editable", Alpha = true, Config = Q(path, "Color"), Transparency = Q(path, "Transparency") })
                return t
            end
            color("Name", "Name", true)
            s:AddGroup({ Source = color("Box", "Box") }):AddDropdown({ Label = "Style", Options = { "Full", "Corner" }, Config = Q("Box", "Style") })
            gradient("Filled Box", "FilledBox")
            local hb = s:AddToggle({ Label = "Health Bar", Config = Q("HealthBar", "Enabled") })
            s:AddColor({ Row = hb.Row, Gradient = "editable", Config = Q("HealthBar", "Color") })
            s:AddGroup({ Source = hb }):AddDropdown({ Label = "Color Mode", Options = { "Solid", "Gradient", "Reactive" }, Config = Q("HealthBar", "ColorMode") })
            color("Health Number", "HealthNumber")
            color("Held Weapon", "HeldWeapon", true)
            local ab = s:AddToggle({ Label = "Ammo Bar", Config = Q("AmmoBar", "Enabled") })
            s:AddColor({ Row = ab.Row, Gradient = "editable", Config = Q("AmmoBar", "Color") })
            s:AddGroup({ Source = ab }):AddDropdown({ Label = "Color Mode", Options = { "Solid", "Gradient", "Reactive" }, Config = Q("AmmoBar", "ColorMode") })
            color("Distance", "Distance")
            color("Rank", "Rank")
            color("Win Streak", "Winstreak")
            color("Deflecting", "Deflecting", true)
            local ch = s:AddGroup({ Source = s:AddToggle({ Label = "Chams", Config = Q("Chams", "Enabled") }) })
            ch:AddDropdown({ Label = "Kind", Options = { "Legacy", "Highlight" }, Config = Q("Chams", "Kind") })
            local fill = ch:AddLabel({ Label = "Fill" })
            ch:AddColor({ Row = fill.Row, Alpha = true, Config = Q("Chams", "InnerColor"), Transparency = Q("Chams", "InnerTransparency") })
            local outline = ch:AddLabel({ Label = "Outline" })
            ch:AddColor({ Row = outline.Row, Alpha = true, Config = Q("Chams", "OutlineColor"), Transparency = Q("Chams", "OutlineTransparency") })
            local glow = ch:AddToggle({ Label = "Glow", Config = Q("Chams", "Glow") })
            ch:AddColor({ Row = glow.Row, Config = Q("Chams", "GlowColor") })
            s:AddGroup({ Source = gradient("Skeleton", "Skeleton") })
                :AddSlider({ Label = "Thickness", Min = 1, Max = 6, Config = Q("Skeleton", "Thickness") })
            local hm = s:AddGroup({ Source = color("Head Marker", "HeadMarker", true) })
            hm:AddDropdown({ Label = "Shape", Options = { "Cross", "Circle", "Diamond" }, Config = Q("HeadMarker", "Shape") })
            hm:AddToggle({ Label = "Filled", Config = Q("HeadMarker", "Filled") })
            local hmo = hm:AddToggle({ Label = "Outline", Config = Q("HeadMarker", "Outline") })
            hm:AddColor({ Row = hmo.Row, Alpha = true, Config = Q("HeadMarker", "OutlineColor"), Transparency = Q("HeadMarker", "OutlineTransparency") })
            local tr = s:AddGroup({ Source = gradient("Tracer", "Tracer") })
            tr:AddSlider({ Label = "Thickness", Min = 1, Max = 6, Config = Q("Tracer", "Thickness") })
            tr:AddDropdown({ Label = "From", Options = { "Bottom", "Center", "Top", "Mouse" }, Config = Q("Tracer", "Origin") })
            tr:AddDropdown({ Label = "To", Options = { "Feet", "Head" }, Config = Q("Tracer", "Target") })
            local tro = tr:AddToggle({ Label = "Outline", Config = Q("Tracer", "Outline") })
            tr:AddColor({ Row = tro.Row, Alpha = true, Config = Q("Tracer", "OutlineColor"), Transparency = Q("Tracer", "OutlineTransparency") })
            tr:AddSlider({ Label = "Outline Thickness", Min = 1, Max = 6, Config = Q("Tracer", "OutlineThickness") })
        end
        side("Enemies", "Enemy", "left")
        side("Teammates", "Team", "right")
    end
end

--  eZ: Kicia's online user service (sessions with user.kicia.cc). Offline here:
--  nothing is sent anywhere, connecting is refused.
tbl17.eZ = function()
    local Offline = {}
    Offline.__index = Offline
    function Offline.new()
        local Signal = tbl17.g()
        local self = setmetatable({ Connected = Signal.new(), ShowActiveChanged = Signal.new(),
            PeerPayloadReceived = Signal.new(), PeerRemoved = Signal.new(), ShowActivated = Signal.new(),
            _playerByHash = {} }, Offline)
        self._leaving = Players.PlayerRemoving:Connect(function(p) self.PeerRemoved:Fire(p) end)
        return self
    end
    function Offline:ShouldShowActive() return false end
    function Offline:IsConnected() return false end
    function Offline:Send() return tbl17.a().err("UserServer", "offline", "the online user service is disabled") end
    function Offline:FindPlayerByHash() return nil end
    function Offline:Connect() return tbl17.ay().reject("the online user service is disabled") end
    function Offline:Destroy()
        self.Connected:Destroy()
        self.ShowActiveChanged:Destroy()
        self.PeerPayloadReceived:Destroy()
        self.PeerRemoved:Destroy()
        self.ShowActivated:Destroy()
        self._leaving:Disconnect()
    end
    return Offline
end
--  Kicia's own modules, lifted from the dump (extract.py). Do not edit by hand.
do -- a
local function fn35()
return {
ok = function(arg)
return { Ok = true, Value = arg }
end,
err = function(arg, arg2, arg3)
return { Ok = false, Error = { Source = arg, Stage = arg2, Detail = arg3, Timestamp = os.clock() } }
end,
formatError = function(arg)
local v115 = tostring
local detail = arg.Detail
return string.format("'%s' @ %s failed during stage '%s'; %s", tostring(arg.Source), tostring(arg.Timestamp), tostring(arg.Stage), v115(detail))
end,
VoidOk = table.freeze({ Ok = true, Value = nil }),
}
end

tbl17.a = function()
local a = tbl17.cache.a

if not a then
a = { c = fn35() }
tbl17.cache.a = a
end

return a.c
end
end
do -- b
local function fn35()
tbl17.a()
local v115 = nil

return {
use = function(arg)
v115 = arg
end,
get = function()
assert(v115)
return v115
end,
}
end

tbl17.b = function()
local b = tbl17.cache.b

if not b then
b = { c = fn35() }
tbl17.cache.b = b
end

return b.c
end
end
do -- d
local function fn35()
local function copy(t)
if type(t) ~= "table" then return t end
local o = {}
for k, v in next, t do o[k] = copy(v) end
return setmetatable(o, getmetatable(t))
end
return copy
end

tbl17.d = function()
local d = tbl17.cache.d

if not d then
d = { c = fn35() }
tbl17.cache.d = d
end

return d.c
end
end
do -- e
local function fn35()
local v115 = tbl17.a()

return function(arg, arg2)
local parts = arg:split("/")
arg2 = arg2 or ""

for k, v116 in parts, nil, nil do
if v116 == "" then
continue
end
local str7 = k == #parts and "" or "/"
local v117 = tostring
arg2 ..= string.format("%s%s", tostring(v116), v117(str7))
if isfile(arg2) then
return v115.err("ensureFolderPath", "collision", string.format("expected `%s` to be non-existant or a folder, found a file instead.", tostring(arg2)))
end

if not isfolder(arg2) then
makefolder(arg2)
end
end

return v115.VoidOk
end
end

tbl17.e = function()
local e = tbl17.cache.e

if not e then
e = { c = fn35() }
tbl17.cache.e = e
end

return e.c
end
end
do -- f
local function fn35()
local v115 = tbl17.a()
local v116 = tbl17.d()
local v117 = tbl17.e()
local v118 = cloneref(game:GetService(v86[182]))
local index2 = {}
index2.__index = index2

local function fn36(arg)
local v119 = v86[68]
if type(arg) == v119 then
return v116(arg)
end
return arg
end

local function fn37(arg)
if arg == nil or arg == "" then
return ""
end

if arg:sub(-v86[63]) == "/" then
return arg
end
return arg .. "/"
end

local function fn38(arg)
if arg == "" then
return v115.err("ConfigManager", "validateConfigName", "config name cannot be empty")
end

if arg:find("/") or arg:find("\\") then
return v115.err("ConfigManager", "validateConfigName", "expected no directory traversal")
end
return v115.VoidOk
end

index2.new = function(arg)
assert(type(arg.CurrentVersion) == "number" and arg.CurrentVersion >= v86[63], "expected `CurrentVersion` >= 1")
local v119 = fn37(arg.SavePath)

if v119 ~= "" then
local v120 = v117(v119)

if not v120.Ok then
error(v120.Error.Detail, 2)
end
end

local serialize = arg.Serialize or function(arg2)
return arg2
end

local deserialize = arg.Deserialize or function(arg2)
return arg2
end

local v120 = fn36(arg.DefaultConfig)

local tbl18 = {
Data = fn36(v120),
_defaultConfig = v120,
_currentVersion = arg.CurrentVersion,
_legacyVersion = arg.LegacyVersion or 1,
_savePath = v119,
_migrations = arg.Migrations or {},
_serialize = serialize,
_deserialize = deserialize,
}

setmetatable(tbl18, index2)
return tbl18
end

index2._ConfigPath = function(arg, arg2)
if arg2:match("%.json$") then
return arg._savePath .. arg2
end
local v119 = tostring
return string.format("%s%s.json", tostring(arg._savePath), v119(arg2))
end

index2._ApplyMigrations = function(arg, arg2, arg3)
if arg2 < 1 then
return v115.err("ConfigManager", "ApplyMigrations", string.format("invalid file version %s", tostring(arg2)))
end

if arg._currentVersion < arg2 then
local v119 = tostring
local currentVersion = arg._currentVersion
return v115.err("ConfigManager", "ApplyMigrations", string.format("file version %s is newer than current version %s", tostring(arg2), v119(currentVersion)))
end

local v119 = fn36(arg3)

while arg2 < arg._currentVersion do
local v120 = arg._migrations[arg2]
if v120 == nil then
local v121 = tostring
return v115.err("ConfigManager", v86[36], string.format("missing migration for version %s -> %s", tostring(arg2), v121(arg2 + 1)))
end
local v121, v122 = v107(v120, v119, arg2, arg2 + v86[63])
if not v121 then
local v123 = tostring
return v115.err(v86[35], "ApplyMigrations", string.format("migration %s -> %s failed: %s", tostring(arg2), tostring(arg2 + v86[63]), v123(v122)))
end

if v122 == nil then
local v123 = tostring
return v115.err("ConfigManager", "ApplyMigrations", string.format("migration %s -> %s returned nil", tostring(arg2), v123(arg2 + 1)))
end
arg2 += 1
v119 = v122
end

return v115.ok(v119)
end

index2.SetData = function(arg, data)
arg.Data = data
end

index2.Reset = function(arg)
local v119 = v116(arg._defaultConfig)
arg.Data = v119
return v119
end

index2.ToJson = function(arg, arg2)
if arg2 == nil then
arg2 = arg.Data
end

local v119, v120 = v107(arg._serialize, arg2)
if not v119 then
return v115.err("ConfigManager", "ToJson", string.format("failed to serialize config: %s", tostring(v120)))
end
local v121, v122 = v107(v118.JSONEncode, v118, { Version = arg._currentVersion, Data = v120 })
if not v121 then
return v115.err("ConfigManager", "ToJson", string.format("failed to encode config payload as JSON: %s", tostring(v122)))
end
return v115.ok(v122)
end

index2.FromJson = function(arg, arg2)
local v119, v120 = v107(v118.JSONDecode, v118, arg2)
if not v119 then
return v115.err(v86[35], v86[169], string.format("failed to decode JSON payload: %s", tostring(v120)))
end

if type(v120) ~= "table" then
return v115.err("ConfigManager", "FromJson", "expected decoded config JSON to be a table")
end
local legacyVersion = arg._legacyVersion
local version = v120.Version
local data = v120.Data

if version == nil and data == nil then
version = v120.version
data = v120.data
end

if not (type(version) == "number" and data ~= nil) then
data = v120
version = legacyVersion
end

local v121 = arg:_ApplyMigrations(version, data)
if not v121.Ok then
return v115.err("ConfigManager", v86[169], v121.Error.Detail)
end
local v122, v123 = v107(arg._deserialize, v121.Value)
if not v122 then
return v115.err("ConfigManager", "FromJson", string.format("failed to deserialize config data: %s", tostring(v123)))
end

if v123 == nil then
return v115.err("ConfigManager", "FromJson", "deserializer returned nil")
end
arg.Data = v123
return v115.ok(v123)
end

index2._SaveImpl = function(arg, arg2, arg3, arg4)
local v119 = fn38(arg2)
if not v119.Ok then
return v119
end
local v120 = arg:_ConfigPath(arg2)
if arg4 and isfile(v120) then
return v115.err("ConfigManager", "SaveImpl", string.format("path `%s` already exists", tostring(v120)))
end
local v121 = arg:ToJson(arg3)
if not v121.Ok then
return v115.err("ConfigManager", "SaveImpl", v121.Error.Detail)
end
writefile(v120, v121.Value)
return v115.VoidOk
end

index2.SaveToFile = function(arg, arg2, arg3)
return arg:_SaveImpl(arg2, nil, arg3)
end

index2.LoadFromFile = function(arg, arg2)
local v119 = fn38(arg2)
if not v119.Ok then
return v115.err("ConfigManager", v86[76], v119.Error.Detail)
end
local v120 = arg:_ConfigPath(arg2)
if not isfile(v120) then
return v115.err(v86[35], "LoadFromFile", string.format("path `%s` does not exist", tostring(v120)))
end
local v121 = readfile(v120)
return arg:FromJson(v121)
end

index2.Exists = function(arg, arg2)
if not fn38(arg2).Ok then
return v86[153]
end
return isfile(arg:_ConfigPath(arg2))
end

index2.SaveDefaultToFile = function(arg, arg2, arg3)
return arg:_SaveImpl(arg2, arg._defaultConfig, arg3)
end

index2.Delete = function(arg, arg2)
local v119 = fn38(arg2)
if not v119.Ok then
return v119
end
local v120 = arg:_ConfigPath(arg2)
if not isfile(v120) then
return v115.err("ConfigManager", v86[38], string.format("path `%s` does not exist", tostring(v120)))
end
delfile(v120)
return v115.VoidOk
end

index2.AllConfigs = function(arg)
local tbl18 = {}
if arg._savePath == "" then
return tbl18
end

for _, v119 in listfiles(arg._savePath) do
if isfile(v119) then
local match = (v119:match("[/\\]([^/\\]+)$") or v119):match("(.+)%.json$")

if match ~= nil then
table.insert(tbl18, match)
end
end
end

return tbl18
end

return index2
end

tbl17.f = function()
local f = tbl17.cache.f

if not f then
f = { c = fn35() }
tbl17.cache.f = f
end

return f.c
end
end
do -- g
local function fn35()local I;local function W(N,...)local P=I;I=nil;N(...);I=P;end;local function N(...)W(...);while true do W(coroutine.yield());end;end;local W_1={};W_1.__index=W_1;W_1.Disconnect=function(P)if not P.Connected then return;end;P.Connected=false;if P._signal._handlerListHead==P then P._signal._handlerListHead=P._next;else local a=P._signal._handlerListHead;while a and a._next~=P do a=a._next;end;if a then a._next=P._next;end;end;end;W_1.Destroy=W_1.Disconnect;setmetatable(W_1,{__index=function(P,P_2)error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(P_2)),2);end,__newindex=function(P,P_3,a)error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(P_3)),2);end});local P={};P.__index=P;P.new=function()return(setmetatable({_handlerListHead=false,_proxyHandler=nil,_yieldedThreads=nil},P));end;P.Wrap=function(a)assert(typeof(a)=="RBXScriptSignal","Argument #1 to Signal.Wrap must be a RBXScriptSignal; got "..typeof(a));local e=P.new();e._proxyHandler=a:Connect(function(...)e:Fire(...);end);return e;end;P.Is=function(a)return type(a)=="table"and getmetatable(a)==P;end;P.Connect=function(a,e)local c=setmetatable({Connected=true,_signal=a,_fn=e,_next=false},W_1);if a._handlerListHead then c._next=a._handlerListHead;a._handlerListHead=c;else a._handlerListHead=c;end;return c;end;P.ConnectOnce=function(W,a)return W:Once(a);end;P.Once=function(W,a)local e;local c=false;e=W:Connect(function(...)if c then return;end;c=true;e:Disconnect();a(...);end);return e;end;P.GetConnections=function(W)local a,e={},W._handlerListHead;while e do table.insert(a,e);e=e._next;end;return a;end;P.DisconnectAll=function(W)local a=W._handlerListHead;while a do a.Connected=false;a=a._next;end;W._handlerListHead=false;a= v102 (W,"_yieldedThreads");if a then for e in a,nil,nil do if coroutine.status(e)=="suspended"then warn((debug.traceback :: any)(e,"signal disconnected; yielded thread cancelled",2));task.cancel(e);end;end;table.clear(W._yieldedThreads);end;end;P.Fire=function(W,...)local a=W._handlerListHead;while a do if a.Connected then W=I;if not W then I=coroutine.create(N);end;task.spawn(I,a._fn,...);end;a=a._next;end;end;P.FireDeferred=function(I,...)local W=I._handlerListHead;while W do local I_4=W;task.defer(function(...)if I_4.Connected then I_4._fn(...);end;end,...);W=W._next;end;end;P.Wait=function(I)local W= v102 (I,"_yieldedThreads");if not W then W={}; v103 (I,"_yieldedThreads",W);end;local N=coroutine.running();W[N]=true;I:Once(function(...)W[N]=nil;if coroutine.status(N)=="suspended"then task.spawn(N,...);end;end);return coroutine.yield();end;P.Destroy=function(I)I:DisconnectAll();local W= v102 (I,"_proxyHandler");if W then W:Disconnect();end;end;return table.freeze({new=P.new,Wrap=P.Wrap,Is=P.Is});end

tbl17.g = function()
local g = tbl17.cache.g

if not g then
local g2 = { c = fn35() }
tbl17.cache.g = g2
g = g2
end

return g.c
end
end
do -- h
local function fn35()
local v115 = tbl17.g()
local index2 = {}
index2.__index = index2
local index3 = {}
index3.__index = index3
index3.Enable = function(l)if l.Connected then return;end;l.Connected=true;l._inner=l._signal._inner:Connect(l._callback);end
index3.Disable = function(l)if not l.Connected then return;end;l.Connected=false;local I=l._inner;if I~=nil then I:Disconnect();end;l._inner=nil;end
index3.Disconnect = index3.Disable
index3.Destroy = index3.Disable
index2.Connect = function(I,W)local N=setmetatable({_signal=I,_callback=W,_inner=nil,Connected=false}, index3 );N:Enable();return N;end
index2.Fire = function(l,I)l._inner:Fire(I);end

index2.FireDeferred = function(arg, arg2)
arg._inner:FireDeferred(arg2)
end

index2.Once = function(arg, arg2)
return arg._inner:Once(arg2)
end

index2.Wait = function(arg)
return arg._inner:Wait()
end

index2.DisconnectAll = function(arg)
arg._inner:DisconnectAll()
end

index2.GetConnections = function(arg)
return arg._inner:GetConnections()
end

index2.Destroy = function(arg)
arg._inner:Destroy()
end

return table.freeze({ new = function()
return (setmetatable({ _inner = v115.new() }, index2))
end })
end

tbl17.h = function()
local h = tbl17.cache.h

if not h then
local h2 = { c = fn35() }
tbl17.cache.h = h2
h = h2
end

return h.c
end
end
do -- i
local function fn35()
local tbl18 = {}

return {
atomic = function(arg)
setmetatable(arg, tbl18)
return arg
end,
isAtomic = function(I)return type(I)=="table"and getmetatable(I)== tbl18 ;end,
}
end

tbl17.i = function()
local i = tbl17.cache.i

if not i then
local i2 = { c = fn35() }
tbl17.cache.i = i2
i = i2
end

return i.c
end
end
do -- j
local function fn35()
if true then
local isAtomic = tbl17.i().isAtomic
local tbl18

tbl18 = {
PathToKey = function(l)return table.concat(l,".");end,
KeyToPath = function(l)return l:split(".");end,
NavigateTo = function(l,I,W)if#I==0 then return nil;end;for N=1,#I,1 do local P=I[N];if N==#I then return l[P];end;l=l[P];if l==nil then if W then return nil;end;error(string.format("Invalid path specified '%s', key %s is nil!",tostring(table.concat(I,".")),tostring(P)),2);elseif type(l)~="table"then if W then return nil;end;error(string.format("Invalid path specified '%s', key %s is not a branch!",tostring(table.concat(I,".")),tostring(P)),2);end;end;return nil;end,
Set = function(I,W,N)for P=1,#W,1 do local a=W[P];if P==#W then I[a]=N;return;end;local Q=I[a];if Q==nil then Q={};I[a]=Q;elseif type(Q)~="table"then local N_5= tbl18 .PathToKey(W);error(string.format("Invalid path specified '%s', key %s is not a table!",tostring(N_5),tostring(a)),2);end;I=Q;end;end,
ForEachEntry = function(I,W)local N={};local function P(a)for e,c in a,nil,nil do table.insert(N,e);W(N,c);if type(c)=="table"and not  isAtomic (c)then P(c);end;table.remove(N);end;end;P(I);end,
ForEachLeafValue = function(I,W,N)local P={};local function a(e,c)for E,p in e,nil,nil do table.insert(P,E);local e_6=if c~=nil then c[E]else nil;local c_7=type(e_6)=="table";E=if type(p)=="table"and not  isAtomic (p)and not(c_7 and( isAtomic (e_6)))and(e_6==nil or c_7)then(a(p,if c_7 then e_6 else nil))else if c_7 and not  isAtomic (e_6)then false else N(P,p)==true;table.remove(P);if E then return true;end;end;return false;end;a(I,W);end,
}

return tbl18
end
return nil

-- (anti-tamper freeze trap removed)
end

tbl17.j = function()
local j = tbl17.cache.j

if not j then
local j2 = { c = fn35() }
tbl17.cache.j = j2
j = j2
end

return j.c
end
end
do -- l
local function fn35()
local v115 = tbl17.f()
local v116 = tbl17.h()
local v117 = tbl17.j()
local v118 = tbl17.a()
local v119 = tbl17.g()
local v120 = tbl17.k()
local v121 = tbl17.d()
local isAtomic = tbl17.i().isAtomic
local index2 = {}
index2.__index = index2

index2.new = function(arg)
local ReactiveStore = v120.new("ReactiveStore")

return setmetatable({
_trove = ReactiveStore,
Default = arg.DefaultConfig,
Data = v121(arg.DefaultConfig),
_middleware = {},
_configManager = v115.new({
DefaultConfig = arg.DefaultConfig,
CurrentVersion = arg.CurrentVersion,
LegacyVersion = arg.LegacyVersion,
SavePath = arg.SavePath,
Migrations = arg.Migrations,
Serialize = arg.Serialize,
Deserialize = arg.Deserialize,
}),
_listenerByPathKey = {},
_listenerTrieRoot = {},
_pendingUpdateByPathKey = {},
_pendingOrder = {},
_isFlushing = false,
_isLoading = false,
_lastPublishedValueByPathKey = {},
_liveValueByPathKey = {},
Reloaded = ReactiveStore:Add(v119.new()),
Changed = ReactiveStore:Add(v119.new()),
}, index2)
end

index2.UseMiddleware = function(arg, middleware)
arg._middleware = middleware
end

local tbl18 = {}

index2.GetPropertyChangedSignal = function(arg, arg2)
local v122 = v117.PathToKey(arg2)
local v123 = arg._listenerByPathKey[v122]

if v123 == nil then
local v124 = arg._trove:Add(v116.new())
arg._listenerByPathKey[v122] = v124
local listenerTrieRoot = arg._listenerTrieRoot

for _, v125 in arg2, nil, nil do
local v126 = listenerTrieRoot[v125]

if v126 ~= nil then
listenerTrieRoot = v126
else
local tbl19 = {}
listenerTrieRoot[v125] = tbl19
listenerTrieRoot = tbl19
end
end

listenerTrieRoot[tbl18] = v124
v123 = v124
end

return v123
end

index2._FireChanged = function(l,I,W,N)local P=l._pendingUpdateByPathKey[I];if not N and P==nil and l._lastPublishedValueByPathKey[I]==W then return;end;if P==nil then table.insert(l._pendingOrder,I);end;l._pendingUpdateByPathKey[I]={Value=W};end
index2._Flush = function(l)if l._isFlushing then return;end;l._isFlushing=true;while#l._pendingOrder>0 do local I,W=l._pendingOrder,l._pendingUpdateByPathKey;l._pendingUpdateByPathKey={};l._pendingOrder={};for N,N_8 in I,nil,nil do local I_9,P=W[N_8],l._listenerByPathKey[N_8];if P then P:Fire(I_9.Value);end;l._lastPublishedValueByPathKey[N_8]=I_9.Value;end;end;l._isFlushing=false;end
index2._FireForChangedPaths = function(arg, paths)
local function publish(p)
local value = v117.NavigateTo(arg.Data, p, true)
arg:_FireChanged(v117.PathToKey(p), value, type(value) == "table")
end
local function below(node, p)
for k, child in next, node do
if k ~= tbl18 and type(child) == "table" then
table.insert(p, k)
if child[tbl18] ~= nil then publish(p) end
below(child, p)
table.remove(p)
end
end
end
for _, path in paths do
local node, prefix = arg._listenerTrieRoot, {}
for i = 1, #path do
node = node[path[i]]
if node == nil then break end
prefix[i] = path[i]
if node[tbl18] ~= nil then publish(prefix) end
if i == #path then below(node, table.clone(prefix)) end
end
end
end
index2._FireListenersOnly = function(arg, path)
arg:_FireForChangedPaths({ path })
arg:_Flush()
end
index2.Get = function(I,W,N)return  v117 .NavigateTo(I.Data,W,N);end
index2.Set = function(I,W,N)local P=I._middleware;local a=P.Set;N=if a~=nil then(a(P,W,N))else N;local e=I.Data;a= v117 .NavigateTo(e,W,true)~=N;if a then  v117 .Set(e,W,N);end;e=P.SetApplied;if e~=nil then e(P,W,N);end;if a then I:_FireForChangedPaths({W});end;e= v117 .PathToKey(W);a=I._liveValueByPathKey[e];if a~=nil then a.Base=N;end;if I._pendingUpdateByPathKey[e]==nil then I:_FireChanged(e,N);end;I:_Flush();if not I._isLoading then I.Changed:Fire(W,N);end;end
index2.SetLiveOverride = function(I,W,N)local P= v117 .PathToKey(W);if I._liveValueByPathKey[P]==nil then I._liveValueByPathKey[P]={Path=W,Base= v117 .NavigateTo(I.Data,W,true)};end; v117 .Set(I.Data,W,N);I:_FireListenersOnly(W,N);end

index2.ClearLiveOverride = function(arg, arg2)
local v122 = v117.PathToKey(arg2)
local v123 = arg._liveValueByPathKey[v122]
if v123 == nil then
return
end
arg._liveValueByPathKey[v122] = nil
v117.Set(arg.Data, arg2, v123.Base)
arg:_FireListenersOnly(arg2, v123.Base)
end

index2.GetBase = function(I,W)local N=I._liveValueByPathKey[ v117 .PathToKey(W)];if N~=nil then return N.Base;end;return  v117 .NavigateTo(I.Data,W,true);end

index2.RebaseLiveOverride = function(arg, arg2, base)
local v122 = arg._liveValueByPathKey[v117.PathToKey(arg2)]
if v122 == nil then
return v86[153]
end
v122.Base = base
return true
end

index2.PublishPath = function(arg, arg2)
arg:_FireListenersOnly(arg2, v117.NavigateTo(arg.Data, arg2, true))
end

index2._PersistableData = function(arg)
local data = arg.Data
local flag19 = true

if next(arg._liveValueByPathKey) ~= nil then
data = v121(data)

for _, v122 in arg._liveValueByPathKey, nil, nil do
v117.Set(data, v122.Path, v122.Base)
end

flag19 = false
end

local middleware = arg._middleware
local persistable = middleware.Persistable
local v122

if persistable ~= nil then
v122 = persistable(middleware, data, flag19)
else
v122 = data
end

return v122
end

index2.SaveToFile = function(arg, arg2, arg3)
arg._configManager:SetData(arg:_PersistableData())
return arg._configManager:SaveToFile(arg2, arg3)
end

index2.CreateDefault = function(arg, arg2)
return arg._configManager:SaveDefaultToFile(arg2, v86[34])
end

local fn36 = nil

fn36 = function(arg, arg2)
if type(arg) ~= "table" or isAtomic(arg) then
local v122 = (arg2 == nil and { arg } or { arg2 })[1]
return (type(v122) == "table" and { (v121(v122)) } or { v122 })[1]
end

if type(arg2) ~= "table" then
return v121(arg)
end
local v122 = table.clone(arg)

for k, v123 in arg, nil, nil do
v122[k] = fn36(v123, arg2[k])
end

for k, v123 in arg2, nil, nil do
if arg[k] == nil then
v122[k] = (type(v123) == "table" and { (v121(v123)) } or { v123 })[v86[63]]
end
end

return v122
end

local fn37 = nil

fn37 = function(arg, arg2, arg3, arg4, arg5)
for k, v122 in arg, nil, nil do
if not (arg2 ~= nil and arg2[k] ~= nil) then
table.insert(arg4, k)
local v123 = (arg3 ~= nil and { arg3[k] } or { nil })[1]

if type(v122) == "table" and not isAtomic(v122) and (v123 == nil or type(v123) == "table" and not isAtomic(v123)) then
fn37(v122, nil, v123, arg4, arg5)
end

arg[k] = nil
table.insert(arg5, table.clone(arg4))
table.remove(arg4)
end
end

if arg2 == nil then
return
end

for k, v122 in arg2, nil, nil do
table.insert(arg4, k)
local tbl19 = arg[k]
local v123 = (arg3 ~= nil and { arg3[k] } or { nil })[1]

if type(v122) == "table" and not isAtomic(v122) and (v123 == nil or type(v123) == "table" and not isAtomic(v123)) then
if type(tbl19) ~= "table" or isAtomic(tbl19) then
tbl19 = {}
arg[k] = tbl19
table.insert(arg5, table.clone(arg4))
end

fn37(tbl19, v122, v123, arg4, arg5)
elseif tbl19 ~= v122 then
if type(tbl19) == "table" and not isAtomic(tbl19) and (v123 == nil or type(v123) == "table" and not isAtomic(v123)) then
fn37(tbl19, nil, v123, arg4, arg5)
end

arg[k] = v122
table.insert(arg5, table.clone(arg4))
end

table.remove(arg4)
end
end

index2._ApplyLoadedData = function(arg, arg2)
local v122 = fn36(arg.Default, arg2)
arg._isLoading = true
table.clear(arg._lastPublishedValueByPathKey)
table.clear(arg._pendingUpdateByPathKey)
table.clear(arg._pendingOrder)
table.clear(arg._liveValueByPathKey)
local tbl19 = {}
fn37(arg.Data, v122, arg.Default, {}, tbl19)
local loaded = arg._middleware.Loaded

if loaded ~= nil then
loaded(arg._middleware, v122)
end

arg:_FireForChangedPaths(tbl19)
arg:_Flush()
arg.Reloaded:Fire()
arg._isLoading = v86[153]
end

index2.LoadFromFile = function(arg, arg2)
local v122 = arg._configManager:LoadFromFile(arg2)
if not v122.Ok then
return v118.err("ReactiveStore", "LoadFromFile", v122.Error.Detail)
end
local value = v122.Value
arg:_ApplyLoadedData(value)
return v118.ok(value)
end

index2.ExportToJson = function(arg)
local v122 = arg._configManager:ToJson(arg:_PersistableData())
if not v122.Ok then
return v118.err("ReactiveStore", v86[99], v122.Error.Detail)
end
return v118.ok(v122.Value)
end

index2.InstallFromJson = function(arg, arg2, arg3)
local v122 = arg._configManager:FromJson(arg3)
if not v122.Ok then
return v118.err("ReactiveStore", "InstallFromJson", v122.Error.Detail)
end
local v123 = arg._configManager:SaveToFile(arg2)
if not v123.Ok then
return v118.err(v86[2], "InstallFromJson", v123.Error.Detail)
end
return v118.VoidOk
end

index2.LoadFromJson = function(arg, arg2)
local v122 = arg._configManager:FromJson(arg2)
if not v122.Ok then
return v118.err(v86[2], "LoadFromJson", v122.Error.Detail)
end
arg:_ApplyLoadedData(v122.Value)
return v118.VoidOk
end

index2.DeleteFile = function(arg, arg2)
local v122 = arg._configManager:Delete(arg2)
if not v122.Ok then
return v118.err("ReactiveStore", "DeleteFile", v122.Error.Detail)
end
return v118.VoidOk
end

index2.AllConfigs = function(arg)
return arg._configManager:AllConfigs()
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.l = function()
local l = tbl17.cache.l

if not l then
l = { c = fn35() }
tbl17.cache.l = l
end

return l.c
end
end
do -- m
local function fn35()
local tbl18

tbl18 = {
normalize = function(arg)
local tbl19 = {}

for k, v115 in arg, nil, nil do
local kind = typeof(v115)
local tbl20

if kind == "Color3" then
tbl20 = { __type = v86[115], R = v115.R, G = v115.G, B = v115.B }
elseif kind == "EnumItem" then
tbl20 = { __type = "EnumItem", EnumType = tostring(v115.EnumType), Name = v115.Name }
elseif kind == "Vector3" then
tbl20 = { __type = v86[20], X = v115.X, Y = v115.Y, Z = v115.Z }
elseif kind == v86[127] then
tbl20 = { __type = "CFrame", Components = { v115:GetComponents() } }
elseif kind == "ColorSequence" then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = { Time = v117.Time, R = v117.Value.R, G = v117.Value.G, B = v117.Value.B }
end

tbl20 = { __type = v86[93], Keypoints = v116 }
elseif kind == "NumberSequence" then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = { Time = v117.Time, Value = v117.Value, Envelope = v117.Envelope }
end

tbl20 = { __type = "NumberSequence", Keypoints = v116 }
elseif kind == "table" then
tbl20 = tbl18.normalize(v115)
else
tbl20 = v115
end

tbl19[k] = tbl20
end

return tbl19
end,
parse = function(arg)
local tbl19 = {}

for k, v115 in arg, nil, nil do
if typeof(v115) == "table" then
local type_ = v115.__type

if type(type_) ~= "string" then
tbl19[k] = tbl18.parse(v115)
else
if type_ == "Color3" then
v115 = Color3.new(v115.R, v115.G, v115.B)
elseif type_ == "EnumItem" then
v115 = Enum[v115.EnumType][v115.Name]
elseif type_ == "Vector3" then
v115 = Vector3.new(v115.X, v115.Y, v115.Z)
elseif type_ == "CFrame" then
v115 = CFrame.new(unpack(v115.Components))
elseif type_ == v86[93] then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = ColorSequenceKeypoint.new(v117.Time, Color3.new(v117.R, v117.G, v117.B))
end

v115 = ColorSequence.new(v116)
elseif type_ == "NumberSequence" then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = NumberSequenceKeypoint.new(v117.Time, v117.Value, v117.Envelope)
end

v115 = NumberSequence.new(v116)
end

tbl19[k] = v115
end

continue
end

tbl19[k] = v115
end

return tbl19
end,
}

return tbl18
end

tbl17.m = function()
local m = tbl17.cache.m

if not m then
local m2 = { c = fn35() }
tbl17.cache.m = m2
m = m2
end

return m.c
end
end
do -- n
local function fn35()
local GlobalTrove = tbl17.k().new("GlobalTrove")

K.GlobalTrove = GlobalTrove

return GlobalTrove
end

tbl17.n = function()
local n = tbl17.cache.n

if not n then
local n33 = { c = fn35() }
tbl17.cache.n = n33
n = n33
end

return n.c
end
end
do -- r
local function fn35()
tbl17.l()
tbl17.g()
tbl17.k()
return {}
end

tbl17.r = function()
local r = tbl17.cache.r

if not r then
r = { c = fn35() }
tbl17.cache.r = r
end

return r.c
end
end
do -- s
local function fn35()return table.freeze({Medium=Font.new("rbxassetid://12187365364",Enum.FontWeight.Medium,Enum.FontStyle.Normal),SemiBold=Font.new("rbxassetid://12187365364",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),Bold=Font.new("rbxassetid://12187365364",Enum.FontWeight.Bold,Enum.FontStyle.Normal)});end

tbl17.s = function()
local s = tbl17.cache.s

if not s then
local s2 = { c = fn35() }
tbl17.cache.s = s2
s = s2
end

return s.c
end
end
do -- t
local function fn35()return{Players=cloneref(game:GetService("Players")),GuiService=cloneref(game:GetService("GuiService")),UserInputService=cloneref(game:GetService("UserInputService")),RunService=cloneref(game:GetService("RunService")),TweenService=cloneref(game:GetService("TweenService")),HttpService=cloneref(game:GetService("HttpService")),CoreGui=cloneref(game:GetService("CoreGui"))};end

tbl17.t = function()
local t = tbl17.cache.t

if not t then
if n26 >= 4809 then
-- (anti-tamper freeze trap removed)
else
local t2 = { c = fn35() }
tbl17.cache.t = t2
t = t2
end
end

return t.c
end
end
do -- u
local function fn35()local I= tbl17 .t();local l,W,N=I.GuiService,I.UserInputService,{DesignSize=UDim2.fromOffset(919,643),MinSize=UDim2.fromOffset(700,400),Scale=1};local function I_10()return workspace.CurrentCamera;end;local function P(a)if not a then return false;end;a=I_10();if a==nil then return false;end;local I=a.ViewportSize;return math.min(I.X,I.Y)>500;end;local function I_11(a)if a then return false;end;a=W.PreferredInput;if a==Enum.PreferredInput.Touch then return true;end;if a==Enum.PreferredInput.KeyboardAndMouse or a==Enum.PreferredInput.Gamepad then return false;end;a=W:GetLastInputType();if a==Enum.UserInputType.Touch then return true;end;if a==Enum.UserInputType.MouseButton1 or a==Enum.UserInputType.MouseButton2 or a==Enum.UserInputType.MouseMovement or a==Enum.UserInputType.Keyboard then return false;end;return W.TouchEnabled and not W.KeyboardEnabled;end;local a=l:IsTenFootInterface();local l_12=I_11(a);local I_13;N.IsMobile=function()return l_12;end;N.ForceMobileLayout=function(e)l_12=true;I_13=e==true;end;N.IsTablet=function()local l=I_13;if l==nil then l=P(N.IsMobile());I_13=l;end;return l;end;N.HasTouch=function()return not a and W.TouchEnabled;end;N.WantsMobileButtons=function()return N.HasTouch()or(N.IsMobile());end;return N;end

tbl17.u = function()
local u = tbl17.cache.u

if not u then
local u2 = { c = fn35() }
tbl17.cache.u = u2
u = u2
end

return u.c
end
end
do -- v
local function fn35()local I,W,N,P= tbl17 .u(),{},table.freeze({IsCompact=false,Rail=table.freeze({Width=100,HeaderHeight=85,TabsTop=102,TabSize=66,TabGap=4,TabIconSize=26,LogoSize=Vector2.new(48,37),ShowLabels=true}),Page=table.freeze({HasTitleBlock=true,OuterInset=18,HorizontalInset=17,HeaderHeight=85,TabsHeight=84,BottomInset=17,TitleTextSize=18,DescriptionTextSize=13,TabMinWidth=50,TabHeight=50,TabIconSize=24,TabTextSize=16,TabGap=14,TabPaddingLeft=13,TabPaddingRight=16,SearchCollapsedWidth=90,SearchExpandedWidth=260,SearchHeight=33,SearchRightInset=14}),Navigation=table.freeze({CueDepth=12,RevealPadding=4,VisibilityEpsilon=1}),Grid=table.freeze({Gap=17,MinColumnWidth=220}),Section=table.freeze({Gap=17,TitleGap=16,InnerPadding=12,ElementGap=12,GroupGap=12,TitleTextSize=16,MultiHeaderHeight=45,MultiHeaderGap=12,MultiHeaderPadding=12,MultiPaneTop=57,MultiTabTextSize=16}),Row=table.freeze({Height=24,TextSize=16,ControlVerticalInset=0,ControlHeight=22,AttachmentGap=11,ListRowHeight=26}),Button=table.freeze({RowHeight=24,VisualHeight=22,Gap=13})}),table.freeze({IsCompact=true,Rail=table.freeze({Width=52,HeaderHeight=48,TabsTop=52,TabSize=44,TabGap=2,TabIconSize=20,LogoSize=Vector2.new(24,19),ShowLabels=false}),Page=table.freeze({HasTitleBlock=true,OuterInset=12,HorizontalInset=12,HeaderHeight=44,TabsHeight=40,BottomInset=12,TitleTextSize=16,DescriptionTextSize=10,TabMinWidth=44,TabHeight=34,TabIconSize=18,TabTextSize=13,TabGap=6,TabPaddingLeft=8,TabPaddingRight=10,SearchCollapsedWidth=32,SearchExpandedWidth=220,SearchHeight=32,SearchRightInset=8}),Navigation=table.freeze({CueDepth=12,RevealPadding=4,VisibilityEpsilon=1}),Grid=table.freeze({Gap=12,MinColumnWidth=220}),Section=table.freeze({Gap=12,TitleGap=8,InnerPadding=8,ElementGap=8,GroupGap=8,TitleTextSize=15,MultiHeaderHeight=36,MultiHeaderGap=8,MultiHeaderPadding=8,MultiPaneTop=44,MultiTabTextSize=13}),Row=table.freeze({Height=32,TextSize=14,ControlVerticalInset=4,ControlHeight=24,AttachmentGap=8,ListRowHeight=32}),Button=table.freeze({RowHeight=32,VisualHeight=30,Gap=8})});local l=table.freeze({IsCompact=true,Rail=P.Rail,Page=table.freeze({HasTitleBlock=false,OuterInset=12,HorizontalInset=12,HeaderHeight=0,TabsHeight=44,BottomInset=12,TitleTextSize=16,DescriptionTextSize=10,TabMinWidth=44,TabHeight=36,TabIconSize=18,TabTextSize=14,TabGap=6,TabPaddingLeft=8,TabPaddingRight=10,SearchCollapsedWidth=32,SearchExpandedWidth=220,SearchHeight=32,SearchRightInset=8}),Navigation=P.Navigation,Grid=table.freeze({Gap=12,MinColumnWidth=330}),Section=P.Section,Row=table.freeze({Height=40,TextSize=15,ControlVerticalInset=6,ControlHeight=28,AttachmentGap=8,ListRowHeight=40}),Button=table.freeze({RowHeight=40,VisualHeight=36,Gap=8})});W.get=function()if not I.IsMobile()then return N;end;if I.IsTablet()then return P;end;return l;end;return W;end

tbl17.v = function()
local v115 = tbl17.cache.v

if not v115 then
v115 = { c = fn35() }
tbl17.cache.v = v115
end

return v115.c
end
end
do -- x
local function fn35() tbl17 .k();local I,W= tbl17 .t(), tbl17 .w();local l,N,P=I.UserInputService,{},setmetatable({},{__mode="k"});N.suppressActivation=function(I)P[I]=true;end;local I_14=W.findScrollingAncestor;N.connectPress=function(a,e,c,E)local p,T,t,x=false, nil, nil, nil;local function S(J)if not p then return;end;p,T,t=false,nil,nil;if x~=nil then x:Disconnect();x=nil;end;E(J);end;a:Add({Destroy=function()p,T,t=false,nil,nil;if x~=nil then x:Disconnect();x=nil;end;end});a:Connect(e.InputBegan,function(E)if p then return;end;local J=E.UserInputType;if J~=Enum.UserInputType.MouseButton1 and J~=Enum.UserInputType.Touch then return;end;T,t,p=E,J,true;c();x=l.InputEnded:Connect(function(c)if T==nil then return;end;if not W.matchesPointerDrag(c,T,Enum.UserInputType.MouseButton1)then return;end;S(false);end);end);a:Connect(e.MouseLeave,function()if t==Enum.UserInputType.MouseButton1 then S(true);end;end);end;N.connectClick=function(a,e,c)if e:IsA("GuiButton")then a:Connect(e.Activated,function(E,p)if P[E]then P[E]=nil;return;end;c();end);return;end;a:Connect(e.InputBegan,function(P)local a=P.UserInputType;if a==Enum.UserInputType.MouseButton1 or a==Enum.UserInputType.Touch then c();end;end);end;N.connectDrag=function(P,a,e,c)local E,p,T,t,x=c or function(c,c_15)end, nil, nil, nil, nil;local c_16,S,J,B,X=false,false,0, nil, nil;local function H()J+=1;if B~=nil then B:Disconnect();B=nil;end;if X~=nil then X:Disconnect();X=nil;end;p,T,t,x,c_16,S=nil,nil,nil,nil,false,false;end;local function k(D)local Q=c_16;H();if Q then E(false,D);end;end;local function D()if p==nil or c_16 or S then return;end;c_16=true;E(true,false);end;P:Add({Destroy=H});P:Connect(a.InputBegan,function(P)local E=P.UserInputType;if E~=Enum.UserInputType.MouseButton1 and E~=Enum.UserInputType.Touch then return;end;H();p=P;T=P.Position;t=I_14(a);x=t and t.CanvasPosition or nil;J+=1;local I=J;task.delay(0.3,function()if J==I then D();end;end);X=l.InputEnded:Connect(function(I)if p==nil then return;end;if not W.matchesPointerDrag(I,p,Enum.UserInputType.MouseButton1)then return;end;J+=1;k(false);end);B=l.InputChanged:Connect(function(l)if p==nil or S then return;end;if not W.matchesPointerDrag(l,p,Enum.UserInputType.MouseMovement)then return;end;local I,W=t,x;if I~=nil and W~=nil then local P=I.CanvasPosition-W;if P.X*P.X+P.Y*P.Y>0.25 then if c_16 then k(true);else S=true;J+=1;end;return;end;end;if not c_16 and T~=nil then W,I=l.Position.X-T.X,l.Position.Y-T.Y;if W*W+I*I>=100 then D();end;end;if c_16 then e(l);end;end);end);end;return N;end

tbl17.x = function()
local x = tbl17.cache.x

if not x then
x = { c = fn35() }
tbl17.cache.x = x
end

return x.c
end
end
do -- y
local function fn35()
tbl17.k()
tbl17.r()
local color = Color3.fromRGB(255, v86[108], v86[108])
local tweenInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return { attach = function(arg, arg2, parent, arg3)
local trigger = parent
local cornerRadius = nil

if arg3 ~= nil then
trigger = arg3.Trigger or parent
cornerRadius = arg3.CornerRadius
end

local frame = Instance.new("Frame")
frame.BackgroundTransparency = v86[63]
frame.Size = UDim2.fromScale(1, 1)
frame.BorderSizePixel = v86[186]
frame.ClipsDescendants = v86[34]
frame.ZIndex = 0
frame.Parent = parent

if cornerRadius ~= nil then
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, cornerRadius)
uiCorner.Parent = frame
end

arg2:Connect(trigger.InputBegan, function(arg4)
local userInputType = arg4.UserInputType
if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.Touch then
return
end
local absoluteSize = parent.AbsoluteSize
local absolutePosition = parent.AbsolutePosition
local n = arg4.Position.X - absolutePosition.X
local n33 = arg4.Position.Y - absolutePosition.Y
local n34 = math.max(absoluteSize.X, absoluteSize.Y) * v86[49]
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(0.5, v86[101])
frame2.Position = UDim2.fromOffset(n, n33)
frame2.Size = UDim2.fromOffset(0, 0)
frame2.BackgroundColor3 = color
frame2.BackgroundTransparency = 0.84
frame2.BorderSizePixel = 0
frame2.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[63], 0)
uiCorner.Parent = frame2
local v115 = arg:Tween(frame2, { Size = UDim2.fromOffset(n34, n34), BackgroundTransparency = 1 }, tweenInfo)

if v115 ~= nil then
v115.Completed:Once(function()
frame2:Destroy()
end)
else
frame2:Destroy()
end
end)
end }
end

tbl17.y = function()
local y = tbl17.cache.y

if not y then
local y2 = { c = fn35() }
tbl17.cache.y = y2
y = y2
end

return y.c
end
end
do -- z
local function fn35()return{Accent=Color3.fromRGB(197,59,59),Outline=Color3.fromRGB(24,25,24),Background=Color3.fromRGB(0,0,0),ElementBackground=Color3.fromRGB(6,6,6),TabButtonSelected=Color3.fromRGB(51,65,70),Unselected=Color3.fromRGB(75,72,72),TextColor=Color3.fromRGB(197,197,197),ToggleCircleUnselected=Color3.fromRGB(70,85,87),ToggleBackgroundUnselected=Color3.fromRGB(12,13,13),GradientTop=Color3.fromRGB(14,16,16),GradientMid=Color3.fromRGB(6,6,6),GradientDark=Color3.fromRGB(3,3,3),GradientDeep=Color3.fromRGB(0,0,0),TabHighlight=Color3.fromRGB(51,65,70),TabShadow=Color3.fromRGB(30,51,61)};end

tbl17.z = function()
local z = tbl17.cache.z

if not z then
local z2 = { c = fn35() }
tbl17.cache.z = z2
z = z2
end

return z.c
end
end
do -- A
local function fn35()
tbl17.k()
local v115 = tbl17.z()
local index2 = {}
index2.__index = index2
local tbl18 = {}
local tbl19 = { Tokens = v115 }

local function fn36(arg, arg2)
local n = #arg
if n == 1 then
return ColorSequence.new(v115[arg[1]])
end
local tbl20 = {}

for k, v116 in arg, nil, nil do
local n33

if arg2 ~= nil then
n33 = arg2[k]
else
n33 = (k - 1) / (n - 1)
end

tbl20[k] = ColorSequenceKeypoint.new(n33, v115[v116])
end

return ColorSequence.new(tbl20)
end

local function fn37(arg, arg2)
if arg._tokenSet[arg2] then
return
end
arg._tokenSet[arg2] = true
local tbl20 = tbl18[arg2]

if tbl20 == nil then
tbl20 = {}
tbl18[arg2] = tbl20
end

tbl20[arg] = v86[34]
end

index2.new = function()
return setmetatable({ _propBindingsByToken = {}, _gradients = {}, _statefulApplyByToken = {}, _tokenSet = {} }, index2)
end

index2.Bind = function(arg, arg2, arg3, arg4)
arg2[arg3] = v115[arg4]
local tbl20 = arg._propBindingsByToken[arg4]

if tbl20 == nil then
tbl20 = {}
arg._propBindingsByToken[arg4] = tbl20
end

table.insert(tbl20, { Instance = arg2, Property = arg3 })
fn37(arg, arg4)
end

index2.BindGradient = function(arg, arg2, arg3, arg4)
arg2.Color = fn36(arg3, arg4)
table.insert(arg._gradients, { Gradient = arg2, Tokens = arg3, Times = arg4 })

for _, v116 in arg3, nil, nil do
fn37(arg, v116)
end
end

index2.BindStateful = function(arg, arg2, arg3)
local tbl20 = arg._statefulApplyByToken[arg2]

if tbl20 == nil then
tbl20 = {}
arg._statefulApplyByToken[arg2] = tbl20
end

table.insert(tbl20, arg3)
fn37(arg, arg2)
end

index2.Destroy = function(arg)
for k in arg._tokenSet, nil, nil do
local v116 = tbl18[k]

if v116 ~= nil then
v116[arg] = nil
end
end

table.clear(arg._tokenSet)
table.clear(arg._propBindingsByToken)
table.clear(arg._gradients)
table.clear(arg._statefulApplyByToken)
end

tbl19.newBatch = function(arg)
local v116 = index2.new()

if arg ~= nil then
arg:Add(v116)
end

return v116
end

tbl19.get = function(arg)
return v115[arg]
end

local tbl20 = { "GradientTop", v86[187], v86[70], v86[141] }
local tbl21 = {}
local background = v115.Background

for _, v116 in tbl20, nil, nil do
local v117 = v115[v116]
tbl21[v116] = { R = v117.R - background.R, G = v117.G - background.G, B = v117.B - background.B }
end

local function fn38(I,W)if  v115 [I]==W then return;end; v115 [I]=W;local N= tbl18 [I];if N==nil then return;end;for P in N,nil,nil do local N_17=P._propBindingsByToken[I];if N_17~=nil then for a,a_18 in N_17,nil,nil do a_18.Instance[a_18.Property]=W;end;end;for a,a_19 in P._gradients,nil,nil do if table.find(a_19.Tokens,I)~=nil then a_19.Gradient.Color= fn36 (a_19.Tokens,a_19.Times);end;end;N_17=P._statefulApplyByToken[I];if N_17~=nil then for l,l_20 in N_17,nil,nil do l_20(W);end;end;end;end

local function fn39(arg)
for _, v116 in tbl20, nil, nil do
local v117 = tbl21[v116]
fn38(v116, Color3.new(math.clamp(arg.R + v117.R, v86[186], 1), math.clamp(arg.G + v117.G, 0, 1), math.clamp(arg.B + v117.B, 0, 1)))
end
end

tbl19.refresh = function(arg, arg2)
fn38(arg, arg2)

if arg == "Background" then
fn39(arg2)
end
end

return tbl19
end

tbl17.A = function()
local a = tbl17.cache.A

if not a then
local a2 = { c = fn35() }
tbl17.cache.A = a2
a = a2
end

return a.c
end
end
do -- B
local function fn35()
local v115 = tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2)
local v119 = v117.get()
local flag19 = arg2.Bare == v86[34]
local height = arg2.Height or v119.Row.Height
local n

if v119.IsCompact and not flag19 then
n = math.max(height, v119.Row.Height)
else
n = height
end

return setmetatable({
_menu = arg,
_metrics = v119,
Label = arg2.Label,
_tooltip = arg2.Tooltip,
_bare = flag19,
_isBareFlexRoot = false,
_visible = v86[34],
_height = n,
_mediumTitle = arg2.MediumTitle == true,
_rightOffset = arg2.RightOffset or 0,
_attachments = {},
_titleAccessories = {},
_titleAccessoryReserve = v86[186],
_isDestroyed = false,
_onVisibilityChanged = function()
end,
_ctx = nil,
_barePending = nil,
_isTooltipWired = false,
Frame = nil,
TitleLabel = nil,
Right = nil,
_rightLayout = nil,
}, index2)
end

index2.AttachRight = function(arg, arg2, arg3, arg4, arg5, arg6, arg7)
local tbl18 = {
Build = arg2,
BuildRoot = arg6,
IsFlexChild = arg7 == true,
IsInRight = false,
Widget = nil,
NaturalWidth = arg3,
Leading = arg4,
Trove = v115.new(),
Cleanup = nil,
}

local cleanup = { Destroy = function()
arg:_DetachAttachment(tbl18)
end }

tbl18.Cleanup = cleanup

if arg5 ~= nil then
arg5:Add(cleanup)
end

if arg._isDestroyed then
tbl18.Trove:Destroy()
return
end
table.insert(arg._attachments, tbl18)
local ctx = arg._ctx
if ctx == nil then
return
end
local barePending = arg._barePending

if barePending ~= nil then
arg._barePending = nil
arg:_BuildBareRoot(barePending.Parent, barePending.LayoutOrder, ctx)
return
end

arg:_RealizeAttachment(tbl18, ctx)
end

index2._DetachAttachment = function(arg, arg2)
local v119 = table.find(arg._attachments, arg2)
if v119 == nil then
return
end
local isInRight = arg2.IsInRight
table.remove(arg._attachments, v119)
arg2.Trove:Destroy()
arg2.Widget = nil
arg2.Cleanup = nil

if arg._bare and isInRight then
local flag19 = v86[153]

for _, v120 in arg._attachments, nil, nil do
if v120.IsInRight then
flag19 = true
break
end
end

if not flag19 then
local right = arg.Right

if right ~= nil then
right:Destroy()
arg.Right = nil
arg._rightLayout = nil
end
end
end

if #arg._attachments > 0 then
return
end
arg._isDestroyed = true
arg._barePending = nil
local frame = arg.Frame

if frame ~= nil then
frame:Destroy()
arg.Frame = nil
end

arg.TitleLabel = nil
arg.Right = nil
arg._rightLayout = nil
arg._isBareFlexRoot = false
arg._onVisibilityChanged()
end

index2.AttachTitleAccessory = function(arg, arg2, arg3, arg4)
local tbl18 = { Build = arg2, Trove = v115.new(), Widget = nil }

local tbl19 = { Destroy = function()
local v119 = table.find(arg._titleAccessories, tbl18)

if v119 ~= nil then
table.remove(arg._titleAccessories, v119)
end

tbl18.Trove:Destroy()
tbl18.Widget = nil
end }

if arg4 ~= nil then
arg4:Add(tbl19)
end

if arg._isDestroyed then
tbl18.Trove:Destroy()
return
end
table.insert(arg._titleAccessories, tbl18)
arg._titleAccessoryReserve = arg._titleAccessoryReserve + arg3
local ctx = arg._ctx

if ctx ~= nil and arg.TitleLabel ~= nil then
arg:_RealizeTitleAccessory(tbl18, ctx)
end
end

index2._RealizeTitleAccessory = function(arg, arg2, arg3)
arg2.Widget = arg2.Build(arg.TitleLabel, {
Menu = arg3.Menu,
Trove = arg2.Trove,
Batch = v118.newBatch(arg2.Trove),
ParentOverlay = arg3.ParentOverlay,
})
end

index2._EnsureRightLayout = function(arg, parent)
if arg._rightLayout ~= nil then
return
end
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
uiListLayout.Padding = UDim.new(0, arg._metrics.Row.AttachmentGap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = parent
arg._rightLayout = uiListLayout

for k, v119 in arg._attachments, nil, nil do
if not (arg._bare and k == 1) then
local widget = v119.Widget

if widget ~= nil then
widget.LayoutOrder = v119.Leading and -1 or k
end
end
end
end

index2._EnsureBareRight = function(arg)
if arg.Right ~= nil then
return arg.Right
end
local frame = arg.Frame
if frame == nil then
return nil
end
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(v86[63], 0.5)
frame2.Position = UDim2.new(1, arg._rightOffset, 0.5, 0)
frame2.Size = UDim2.new(0.55, 0, v86[186], arg._height)
frame2.BorderSizePixel = 0
frame2.BackgroundTransparency = 1
frame2.Parent = frame
arg.Right = frame2
arg:_EnsureRightLayout(frame2)
return frame2
end

index2._RealizeAttachment = function(arg, arg2, arg3)
local frame

if arg._bare then
if arg._isBareFlexRoot and arg2.IsFlexChild then
frame = arg.Frame
else
frame = arg:_EnsureBareRight()
end
else
frame = arg.Right or arg.Frame

if arg.Right ~= nil and #arg._attachments >= 2 then
arg:_EnsureRightLayout(arg.Right)
end
end

if frame == nil then
return
end
arg2.IsInRight = arg.Right ~= nil and frame == arg.Right
local tbl18 = {}

for _, v119 in frame:GetChildren() do
tbl18[v119] = v86[34]
end

local v119 = arg2.Build(frame, {
Menu = arg3.Menu,
Trove = arg2.Trove,
Batch = v118.newBatch(arg2.Trove),
ParentOverlay = arg3.ParentOverlay,
})

arg2.Widget = v119

for _, v120 in frame:GetChildren() do
if not tbl18[v120] then
arg2.Trove:Add(v120)
end
end

if v119 ~= nil and arg._rightLayout ~= nil then
local layoutOrder = table.find(arg._attachments, arg2) or #arg._attachments

if arg2.Leading then
layoutOrder = -v86[63]
end

v119.LayoutOrder = layoutOrder
end
end

local function fn36(arg)
local v119 = v86[186]

for k, v120 in arg._attachments, nil, nil do
local naturalWidth = v120.NaturalWidth
if naturalWidth == nil then
return nil
end
v119 += naturalWidth

if k > 1 then
v119 += arg._metrics.Row.AttachmentGap
end
end

if v119 == 0 then
return nil
end
return v119
end

local function fn37(arg, arg2, arg3, arg4, arg5)
local flag19 = false
local flag20 = false
local size = arg5.Size
local anchorPoint = arg5.AnchorPoint
local position = arg5.Position
local position2 = arg4.Position
local size2 = arg3.Size
local automaticSize = arg3.AutomaticSize
local scale = size.X.Scale
local n = 1

if scale > 0 then
n = v86[63] - scale
end

local n33 = arg4.TextBounds.X + arg._titleAccessoryReserve

local function fn38()
if flag20 then
return
end
flag20 = true
local x = arg3.AbsoluteSize.X
if x <= 0 then
flag20 = false
return
end
local n34 = x * n - v86[162]
local v119 = fn36(arg)

if v119 ~= nil then
n34 = x - v119 - 8
end

local flag21 = n33 > n34
if flag21 == flag19 then
flag20 = false
return
end
flag19 = flag21

if flag19 then
local v120 = math.round(math.max(arg4.TextBounds.Y, arg._metrics.Row.TextSize))
arg4.AnchorPoint = Vector2.zero
arg4.Position = UDim2.new(0, 0, v86[186], v86[186])
arg5.AnchorPoint = Vector2.zero
arg5.Position = UDim2.fromOffset(0, v120 + 4)
arg5.Size = UDim2.new(1, 0, 0, size.Y.Offset)
arg3.AutomaticSize = Enum.AutomaticSize.None
arg3.Size = UDim2.new(1, 0, 0, v120 + 4 + size.Y.Offset)
else
arg4.AnchorPoint = Vector2.zero
arg4.Position = position2
arg5.AnchorPoint = anchorPoint
arg5.Position = position
arg5.Size = size
arg3.AutomaticSize = automaticSize
arg3.Size = size2
end

flag20 = false
end

fn38()
arg2.Trove:Connect(arg3:GetPropertyChangedSignal("AbsoluteSize"), fn38)

arg2.Trove:Connect(arg4:GetPropertyChangedSignal(v86[37]), function()
n33 = arg4.TextBounds.X + arg._titleAccessoryReserve
fn38()
end)
end

index2._BuildBareRoot = function(arg, arg2, layoutOrder, arg3)
local v119 = arg._attachments[1]
v119.IsInRight = false
arg._isBareFlexRoot = v119.IsFlexChild

local v120 = (v119.BuildRoot or v119.Build)(arg2, {
Menu = arg3.Menu,
Trove = v119.Trove,
Batch = v118.newBatch(v119.Trove),
ParentOverlay = arg3.ParentOverlay,
})

assert(v120 ~= nil, "Row: bare row builder returned no root")
v120.LayoutOrder = layoutOrder
v120.Visible = arg._visible
arg.Frame = v120

for _, v121 in v120:GetChildren() do
if not v121:IsA("UIListLayout") then
v119.Trove:Add(v121)
end
end

for i = 2, #arg._attachments do
local v121 = arg._attachments[i]

if v121.Widget == nil then
arg:_RealizeAttachment(v121, arg3)
end
end

arg:_WireTooltip()
end

index2.Realize = function(arg, parent, ctx, layoutOrder)
if arg._ctx ~= nil or arg._isDestroyed then
return
end
arg._ctx = ctx

if arg._bare then
if arg._attachments[1] == nil then
arg._barePending = { Parent = parent, LayoutOrder = layoutOrder }
return
end
arg:_BuildBareRoot(parent, layoutOrder, ctx)
else
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.new(1, 0, 0, arg._height)
textButton.BorderSizePixel = 0
textButton.AutomaticSize = Enum.AutomaticSize.Y
textButton.AutoButtonColor = false
textButton.Text = ""
textButton.LayoutOrder = layoutOrder
textButton.Visible = arg._visible
textButton.Parent = parent
arg.Frame = textButton
local n = arg._metrics.Row.TextSize + 4
local textLabel = Instance.new("TextLabel")
textLabel.Text = arg.Label or ""
textLabel.AnchorPoint = Vector2.zero
textLabel.BackgroundTransparency = v86[63]
textLabel.Position = UDim2.fromOffset(v86[186], math.round((arg._height - n) / 2))
textLabel.Size = UDim2.fromOffset(0, n)
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.X
textLabel.TextSize = arg._metrics.Row.TextSize
textLabel.TextXAlignment = Enum.TextXAlignment.Left

if arg._mediumTitle then
textLabel.FontFace = v116.Medium
else
textLabel.FontFace = ctx.Menu.Fonts.Main
end

ctx.Batch:Bind(textLabel, "TextColor3", "TextColor")
textLabel.Parent = textButton
arg.TitleLabel = textLabel
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, v86[186])
frame.Position = UDim2.new(v86[63], arg._rightOffset, 0, 0)
frame.Size = UDim2.new(0.55, 0, 0, arg._height)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BackgroundTransparency = 1
frame.Parent = textButton
local controlVerticalInset = arg._metrics.Row.ControlVerticalInset

if controlVerticalInset > 0 then
frame.AutomaticSize = Enum.AutomaticSize.None
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, controlVerticalInset)
uiPadding.PaddingBottom = UDim.new(v86[186], controlVerticalInset)
uiPadding.Parent = frame
end

arg.Right = frame

for _, v119 in arg._attachments, nil, nil do
if v119.Widget == nil then
arg:_RealizeAttachment(v119, ctx)
end
end

for _, v119 in arg._titleAccessories, nil, nil do
if v119.Widget == nil then
arg:_RealizeTitleAccessory(v119, ctx)
end
end

fn37(arg, ctx, textButton, textLabel, frame)
arg:_WireTooltip()
end
end

index2._WireTooltip = function(arg)
if arg._isTooltipWired or arg._tooltip == nil then
return
end
local ctx = arg._ctx
local frame = arg.Frame
if ctx == nil or frame == nil then
return
end
arg._isTooltipWired = true

ctx.Menu:AttachTooltip(ctx.Trove, frame, function()
return arg._tooltip
end)
end

index2.SetLabel = function(arg, label)
arg.Label = label
arg._menu:InvalidateSearch()
local titleLabel = arg.TitleLabel

if titleLabel ~= nil then
titleLabel.Text = label
end
end

index2.SetTooltip = function(arg, tooltip)
arg._tooltip = tooltip
arg:_WireTooltip()
end

index2.SetVisible = function(arg, visible)
if arg._visible == visible then
return
end
arg._visible = visible
local frame = arg.Frame

if frame ~= nil then
frame.Visible = visible
end

arg._onVisibilityChanged()
end

index2.IsVisible = function(arg)
return arg._visible
end

index2.Destroy = function(arg)
arg._isDestroyed = true
arg._barePending = nil

for i = #arg._attachments, 1, -v86[63] do
local v119 = arg._attachments[i]
table.remove(arg._attachments, i)
v119.Trove:Destroy()
v119.Widget = nil
v119.Cleanup = nil
end

for i = #arg._titleAccessories, 1, -1 do
local v119 = arg._titleAccessories[i]
table.remove(arg._titleAccessories, i)
v119.Trove:Destroy()
v119.Widget = nil
end

local frame = arg.Frame

if frame ~= nil then
frame:Destroy()
arg.Frame = nil
end

arg.TitleLabel = nil
arg.Right = nil
arg._rightLayout = nil
arg._isBareFlexRoot = false
arg._onVisibilityChanged()
end

return index2
end

tbl17.B = function()
local b = tbl17.cache.B

if not b then
b = { c = fn35() }
tbl17.cache.B = b
end

return b.c
end
end
do -- C
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.x()
local v119 = tbl17.y()
tbl17.B()
local v120 = tbl17.A()
local color = Color3.fromRGB(255, 255, 255)
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfo2 = TweenInfo.new(v86[62], Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local color2 = Color3.fromRGB(v86[102], 92, v86[53])

local function fn36(arg, arg2)
local clamp = math.clamp
local n = arg.B * arg2
return Color3.new(math.clamp(arg.R * arg2, v86[186], v86[63]), math.clamp(arg.G * arg2, 0, v86[63]), clamp(n, 0, 1))
end

local function fn37(arg)
return arg == "primary" and v120.get("Accent") or color
end

local function fn38(arg)
local flag19 = arg == "primary"

if flag19 then
local v121 = v86[66]
flag19 = fn36(v120.get("Accent"), v121)
end

return flag19 or Color3.fromRGB(v86[65], 220, 230)
end

local function fn39(arg)
if arg == "primary" then
return color
end

if arg == "ghost" then
return v120.get("Unselected")
end
return v120.get("TextColor")
end

local function fn40(arg)
return arg == "primary" and fn36(v120.get(v86[139]), 0.6) or v120.get(v86[120])
end

local index2 = {}
index2.__index = index2

local function createFrame(arg, parent, arg2)
local menu = arg._menu
local variant = arg._variant
local button = v117.get().Button
local transparency = 0
local n = 0

if variant == "primary" then
n = 0.6
elseif variant == "ghost" then
if n26 < 4790 then
-- (anti-tamper freeze trap removed)
else
transparency = 1
n = 1
end
end

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(v86[63], v86[186])
frame.Position = UDim2.new(1, -v86[63], 0, 1)
frame.Size = UDim2.fromOffset(v86[186], button.VisualHeight)
frame.BorderSizePixel = 0
frame.BackgroundColor3 = fn37(variant)
frame.ClipsDescendants = v86[34]
frame.Parent = parent

if variant == "default" then
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
arg2.Batch:BindGradient(uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = frame
end

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], 5)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = fn40(variant)
uiStroke.Transparency = transparency
uiStroke.Parent = frame
local instance = Instance.new(v86[92])
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = 0
instance.Text = ""
instance.AutoButtonColor = false
instance.Parent = frame
v119.attach(menu, arg2.Trove, frame, { Trigger = instance })
local textLabel = Instance.new("TextLabel")
textLabel.LayoutOrder = -v86[63]
textLabel.FontFace = v116.SemiBold
textLabel.TextColor3 = fn39(variant)
textLabel.Text = arg.Label
textLabel.BackgroundTransparency = 1
textLabel.Size = UDim2.fromScale(1, 1)
textLabel.BorderSizePixel = 0
textLabel.TextSize = 16
textLabel.Parent = frame
arg._title = textLabel

if variant == "default" then
arg2.Batch:Bind(textLabel, "TextColor3", "TextColor")
elseif variant == "ghost" then
arg2.Batch:Bind(textLabel, "TextColor3", "Unselected")
end

arg2.Trove:Connect(instance.MouseEnter, function()
menu:Tween(frame, { BackgroundColor3 = fn38(variant) }, tweenInfo)

if variant == "default" then
menu:Tween(uiStroke, { Color = v120.get("Accent") }, tweenInfo)
elseif variant == "primary" then
menu:Tween(uiStroke, { Transparency = n }, tweenInfo)
elseif variant == "ghost" then
menu:Tween(textLabel, { TextColor3 = v120.get("TextColor") }, tweenInfo)
end
end)

arg2.Trove:Connect(instance.MouseLeave, function()
menu:Tween(frame, { BackgroundColor3 = fn37(variant) }, tweenInfo)

if variant == "default" then
menu:Tween(uiStroke, { Color = v120.get("Outline") }, tweenInfo)
elseif variant == "primary" then
menu:Tween(uiStroke, { Transparency = transparency }, tweenInfo)
elseif variant == "ghost" then
menu:Tween(textLabel, { TextColor3 = v120.get("Unselected") }, tweenInfo)
end
end)

local backgroundColor3 = nil

v118.connectPress(arg2.Trove, instance, function()
backgroundColor3 = frame.BackgroundColor3
menu:Tween(frame, { BackgroundColor3 = fn36(backgroundColor3, 0.85) }, tweenInfo2)
end, function()
if backgroundColor3 ~= nil then
menu:Tween(frame, { BackgroundColor3 = backgroundColor3 }, tweenInfo2)
backgroundColor3 = nil
end
end)

local function fn41()
textLabel.TextColor3 = v120.get("Accent")
menu:Tween(textLabel, { TextColor3 = fn39(variant) })
arg._onClick()
arg.Clicked:Fire()
end

if not arg._requiresConfirm then
v118.connectClick(arg2.Trove, instance, fn41)
return frame
end
local v121 = nil

local function fn42()
local v122 = v121
if v122 == nil then
return
end
v121 = nil
v122:Destroy()
textLabel.Text = arg.Label
menu:Tween(textLabel, { TextColor3 = fn39(variant) }, tweenInfo)
end

v118.connectClick(arg2.Trove, instance, function()
if v121 == nil then
local v122 = arg2.Trove:Extend()
v121 = v122
menu:Tween(textLabel, { TextColor3 = color2 }, tweenInfo)

v122:Add(task.spawn(function()
for i = v86[155], 1, -1 do
textLabel.Text = string.format("%s (%s)", "Are you sure?", tostring(i))
task.wait(v86[63])
end

fn42()
end))

return
end

fn42()
fn41()
end)

return frame
end

local function createTextButton()
local button = v117.get().Button
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.new(1, v86[186], 0, button.RowHeight)
textButton.BorderSizePixel = 0
textButton.Text = ""
textButton.AutoButtonColor = false
local instance = Instance.new(v86[4])
instance.Padding = UDim.new(0, button.Gap)
instance.FillDirection = Enum.FillDirection.Horizontal
instance.HorizontalFlex = Enum.UIFlexAlignment.Fill
instance.SortOrder = Enum.SortOrder.LayoutOrder
instance.VerticalFlex = Enum.UIFlexAlignment.Fill
instance.Parent = textButton
return textButton
end

index2._New = function(arg, arg2, arg3, arg4, arg5)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = v86[33],
Row = arg2,
Label = arg4.Label or "Button",
Clicked = arg3:Add(v115.new()),
_onClick = arg4.OnClick or function()
end,
_variant = arg4.Variant or "default",
_requiresConfirm = arg4.Confirm == true,
_title = nil,
}, index2)

if arg5 then
arg2:AttachRight(function(parent, arg6)
local v121 = createTextButton()
v121.Parent = parent
createFrame(obj, v121, arg6)
return v121
end, nil, nil, arg3, nil, v86[34])
else
arg2:AttachRight(function(arg6, arg7)
return createFrame(obj, arg6, arg7)
end, nil, nil, arg3, function(parent, arg6)
local v121 = createTextButton()
v121.Parent = parent
createFrame(obj, v121, arg6)
return v121
end, true)
end

return obj
end

index2.SetLabel = function(arg, label)
arg.Label = label
local title = arg._title

if title ~= nil then
title.Text = label
end

return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnClick = function(arg, arg2)
arg._trove:Connect(arg.Clicked, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.C = function()
local c = tbl17.cache.C

if not c then
local c2 = { c = fn35() }
tbl17.cache.C = c2
c = c2
end

return c.c
end
end
do -- D
local function fn35() tbl17 .r();local l={};local function I(W)local N={};for P,P_21 in W.Keypoints,nil,nil do table.insert(N,{Time=P_21.Time,Value=P_21.Value});end;return N;end;local function W(N)local P={};for a,a_22 in N,nil,nil do table.insert(P,ColorSequenceKeypoint.new(a_22.Time,a_22.Value));end;return ColorSequence.new(P);end;local function N(P)local a=P[1].Value;for e=2,#P,1 do if P[e].Value~=a then return false;end;end;return true;end;local function P(a)if type(a)=="number"then return 1-a;end;return 1;end;l.decodeSolid=function(a,e)if typeof(a)~="Color3"then return nil;end;return{Rgb=a,Alpha=P(e),Stops={}};end;l.encodeSolid=function(a)return a.Rgb,1-a.Alpha;end;l.decodeSequence=function(a,e)if typeof(a)~="ColorSequence"then return nil;end;local c=I(a);if#c==0 then return nil;end;a=P(e);if N(c)then return{Rgb=c[1].Value,Alpha=a,Stops={}};end;return{Rgb=c[1].Value,Alpha=a,Stops=c};end;l.encodeSequence=function(I)local N=I.Stops;if N~=nil and#N>=2 then return W(N),1-I.Alpha;end;return ColorSequence.new(I.Rgb),1-I.Alpha;end;return l;end

tbl17.D = function()
local d = tbl17.cache.D

if not d then
d = { c = fn35() }
tbl17.cache.D = d
end

return d.c
end
end
do -- E
local function fn35() tbl17 .r();local l;l={clone=function(I)local W={};if type(I)=="table"then for N,P in I,nil,nil do if type(P)=="table"then N=P.Value;if typeof(N)=="Color3"then table.insert(W,{Time=math.clamp(tonumber(P.Time)or 0,0,1),Value=N});end;end;end;end;return W;end,sort=function(I,W)table.sort(I,function(N,P)return N.Time<P.Time;end);if W~=nil then for N,P in I,nil,nil do if P==W then return N;end;end;end;return math.max(#I,1);end,ensure=function(I,W)local N=l.clone(I);if#N>=2 then l.sort(N);N[1].Time=0;N[#N].Time=1;return N;end;return{{Time=0,Value=W},{Time=1,Value=W}};end,toSequence=function(I)local W=l.clone(I);if#W==0 then return ColorSequence.new(Color3.new(1,1,1));end;l.sort(W);local I_23,N,P={},W[1],W[#W];if N.Time>0 then table.insert(I_23,ColorSequenceKeypoint.new(0,N.Value));end;for a,a_24 in W,nil,nil do N=math.clamp(a_24.Time,0,1);table.insert(I_23,ColorSequenceKeypoint.new(if#I_23>0 then(math.max(N,I_23[#I_23].Time))else N,a_24.Value));end;if I_23[#I_23].Time<1 then table.insert(I_23,ColorSequenceKeypoint.new(1,P.Value));end;return ColorSequence.new(I_23);end};return l;end

tbl17.E = function()
local e = tbl17.cache.E

if not e then
e = { c = fn35() }
tbl17.cache.E = e
end

return e.c
end
end
do -- F
local function fn35()
tbl17.A()

return {
addGlow = function(arg, parent, arg2)
local amount = arg2.Amount or v86[175]
local dampingFactor = arg2.DampingFactor or 0.4

for i = 1, amount do
local uiStroke = Instance.new("UIStroke")
uiStroke.LineJoinMode = Enum.LineJoinMode.Round
uiStroke.BorderOffset = UDim.new(0, i)
uiStroke.Transparency = 1 - (v86[63] - i / (amount + dampingFactor)) * (v86[63] - dampingFactor)
arg:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = parent
end
end,
bindSurfaceGradient = function(arg, arg2, arg3)
local n = #arg3
local v115 = table.clone(arg3)
table.insert(v115, arg3[n])
local tbl18 = {}

for i = 1, n do
tbl18[i] = (i - 1) / (n - 1) * v86[81]
end

tbl18[n + 1] = 1
arg:BindGradient(arg2, v115, tbl18)
end,
}
end

tbl17.F = function()
local f = tbl17.cache.F

if not f then
local f2 = { c = fn35() }
tbl17.cache.F = f2
f = f2
end

return f.c
end
end
do -- G
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.A()
local v117 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36(arg)
local root = arg.Root
local v118, v119 = arg._place(arg._trigger, root)
local v120 = v117.absoluteToLayerOffset(arg._layer, Vector2.new(v118, v119))
local absoluteSize = root.AbsoluteSize

if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
local absoluteSize2 = arg._layer.AbsoluteSize
absoluteSize = Vector2.new(root.Size.X.Scale * absoluteSize2.X + root.Size.X.Offset, root.Size.Y.Scale * absoluteSize2.Y + root.Size.Y.Offset)
end

local anchorPoint = root.AnchorPoint
local v121, v122 = v117.clampOffsetToViewport(v120.X - absoluteSize.X * anchorPoint.X, v120.Y - absoluteSize.Y * anchorPoint.Y, absoluteSize)
local v123 = v117.onScreenKeyboardTop()
local n

if v123 == nil then
n = v122
else
n = math.clamp(v122, v86[186], math.max(0, v123 - absoluteSize.Y))
end

return math.round(v121 + absoluteSize.X * anchorPoint.X), math.round(n + absoluteSize.Y * anchorPoint.Y)
end

local function fn37(arg, arg2)
arg._geometryTrove:Clean()
arg._onToggle(arg2)
local menu = arg._menu
local root = arg.Root

if not arg2 then
local v118, v119 = fn36(arg)
menu:Tween(root, { Position = UDim2.fromOffset(v118, v119 - 15) })
menu:FadeCanvasGroup(root, false, arg._fadeState)
return
end

v117.connectOnScreenKeyboard(arg._geometryTrove, function()
local updateViewport = arg._updateViewport
if updateViewport ~= nil then
updateViewport()
return
end
arg:Reposition()
end)

local v118, v119 = fn36(arg)
root.Position = UDim2.fromOffset(v118, v119 - 15)

arg._geometryTrove:Add(task.defer(function()
if not arg.Entry.Open or root.Parent == nil then
return
end
local v120, v121 = fn36(arg)
root.Position = UDim2.fromOffset(v120, v121 - 15)
menu:FadeCanvasGroup(root, true, arg._fadeState)
menu:Tween(root, { Position = UDim2.fromOffset(v120, v121) })
end))
end

index2.new = function(arg, arg2, arg3)
local v118 = arg2:Extend()
local v119 = v116.newBatch(v118)
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.Visible = false
canvasGroup.GroupTransparency = 1
canvasGroup.BorderSizePixel = 0
canvasGroup.AnchorPoint = arg3.AnchorPoint or Vector2.zero
canvasGroup.Size = arg3.Size
canvasGroup.AutomaticSize = arg3.AutomaticSize or Enum.AutomaticSize.None

if arg3.FlatBackground then
canvasGroup.BackgroundTransparency = v86[6]
v119:Bind(canvasGroup, "BackgroundColor3", v86[168])
else
canvasGroup.BackgroundTransparency = 1
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(v86[63], 1)
frame.BorderSizePixel = 0
frame.ZIndex = v86[186]
frame.BackgroundColor3 = Color3.fromRGB(v86[108], v86[108], 255)
frame.Parent = canvasGroup
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v115.bindSurfaceGradient(v119, uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, arg3.CornerRadius or 5)
uiCorner.Parent = frame
end

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], arg3.CornerRadius or 5)
uiCorner.Parent = canvasGroup
local uiStroke = Instance.new("UIStroke")
v119:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = canvasGroup

if arg3.Glow then
v115.addGlow(v119, canvasGroup, { Amount = 5, DampingFactor = 0.6 })
end

local overlayLayer = arg:GetOverlayLayer()
canvasGroup.Parent = overlayLayer
v118:Add(canvasGroup)
local v120 = nil

local v121 = arg:RegisterOverlay(canvasGroup, {
Triggers = { arg3.Trigger },
ParentEntry = arg3.ParentEntry,
OnToggle = function(arg4)
local v121 = v120

if v121 ~= nil then
fn37(v121, arg4)
end
end,
})

v118:Add({ Destroy = function()
arg:UnregisterOverlay(v121)
end })

local obj = setmetatable({
Trove = v118,
_menu = arg,
_layer = overlayLayer,
Batch = v119,
_trigger = arg3.Trigger,
_place = arg3.Place,
_onToggle = arg3.OnToggle or function()
end,
_fadeState = { Tweening = v86[153] },
_geometryTrove = v118:Extend(),
_updateViewport = nil,
Root = canvasGroup,
Entry = v121,
}, index2)

v120 = obj

v118:Connect(arg3.Trigger:GetPropertyChangedSignal("AbsolutePosition"), function()
obj:Reposition()
end)

v117.connectCurrentCameraViewport(v118, function()
obj:Reposition()
end)

return obj
end

index2.RealizeCtx = function(arg)
return { Menu = arg._menu, Trove = arg.Trove, Batch = arg.Batch, ParentOverlay = arg.Entry }
end

index2.placeBelow = function(arg, arg2)
return function(arg3)
local absolutePosition = arg3.AbsolutePosition
return math.round(absolutePosition.X) + arg, math.round(absolutePosition.Y + arg3.AbsoluteSize.Y + arg2)
end
end

index2.AttachScrollingList = function(arg, arg2, arg3)
local root = arg.Root
local n = 12
local n33 = 12
local n34 = 12

if arg3 ~= nil then
n = arg3.Top
n33 = arg3.Bottom
n34 = arg3.Side
end

local instance = Instance.new(v86[64])
instance.Active = v86[34]
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = 0
instance.BackgroundTransparency = 1
instance.AutomaticCanvasSize = Enum.AutomaticSize.Y
instance.CanvasSize = UDim2.fromOffset(0, 0)
instance.ScrollBarImageTransparency = 0.35
instance.ScrollBarThickness = v86[186]
instance.Selectable = false
arg.Batch:Bind(instance, "ScrollBarImageColor3", "Accent")
instance.Parent = root
local instance2 = Instance.new(v86[128])
instance2.Position = UDim2.fromOffset(n34, n)
instance2.Size = UDim2.new(1, -n34 * 2, 0, 0)
instance2.AutomaticSize = Enum.AutomaticSize.Y
instance2.BorderSizePixel = 0
instance2.BackgroundTransparency = v86[63]
instance2.Parent = instance
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, v86[12])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = instance2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, n33)
uiPadding.Parent = instance2
local v118 = nil

local function updateViewport()
local y = v118 and v118.Y or v86[78]
local v119 = v117.onScreenKeyboardTop()
local n35

if v119 == nil then
n35 = y
else
n35 = math.min(y, v119)
end

local n36 = uiListLayout.AbsoluteContentSize.Y + n + n33
local n37 = math.min(n36, math.max(80, n35 - v86[13]))
root.Size = UDim2.fromOffset(arg2, n37)
local scrollBarThickness = v86[186]

if n36 > n37 + 0.5 then
scrollBarThickness = 4
end

instance.ScrollBarThickness = scrollBarThickness
arg:Reposition()
end

arg._updateViewport = updateViewport
arg.Trove:Connect(uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), updateViewport)

v117.connectCurrentCameraViewport(arg.Trove, function(arg4)
v118 = arg4
updateViewport()
end)

return instance, instance2
end

index2.IsOpen = function(arg)
return arg.Entry.Open
end

index2.Toggle = function(arg)
arg._menu:ToggleOverlay(arg.Entry)
end

index2.SetOpen = function(arg, arg2)
arg._menu:SetOverlayOpen(arg.Entry, arg2)
end

index2.Reposition = function(arg)
if not arg.Entry.Open then
return
end
local v118, v119 = fn36(arg)
if arg._fadeState.Tweening then
arg._menu:Tween(arg.Root, { Position = UDim2.fromOffset(v118, v119) })
return
end
arg.Root.Position = UDim2.fromOffset(v118, v119)
end

index2.Destroy = function(arg)
arg.Trove:Destroy()
end

return index2
end

tbl17.G = function()
local g = tbl17.cache.G

if not g then
g = { c = fn35() }
tbl17.cache.G = g
end

return g.c
end
end
do -- H
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.u()
local v119 = tbl17.x()
local v120 = tbl17.G()
tbl17.B()
local v121 = tbl17.A()
local v122 = tbl17.w()
local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local color = Color3.fromRGB(v86[108], v86[108], v86[108])
local index2 = {}
index2.__index = index2

local function fn36(arg)
local tbl18 = {}
local v123 = v86[165]

if type(arg) == v123 then
tbl18[arg] = true
else
local v124 = v86[68]

if type(arg) == v124 then
for k, v125 in arg, nil, nil do
local v126 = v86[165]

if type(k) == v126 and v125 == true then
tbl18[k] = true
else
local v127 = v86[95]

if type(k) == v127 and type(v125) == "string" then
tbl18[v125] = v86[34]
end
end
end
end
end

return tbl18
end

local function fn37(arg)
table.clear(arg._indexByName)

for k, v123 in arg.Options, nil, nil do
arg._indexByName[v123] = k
end
end

local function fn38(arg, arg2)
return arg._labelByValue[arg2] or arg2
end

local function fn39(arg)
local value = arg.Value
if type(value) == "string" then
return fn38(arg, value)
end

if type(value) == "table" then
local tbl18 = {}

for _, v123 in arg.Options, nil, nil do
if value[v123] then
table.insert(tbl18, fn38(arg, v123))
end
end

if v86[186] < #tbl18 then
return table.concat(tbl18, ", ")
end
end

return "Select"
end

local function fn40(arg)
local rt = arg._rt

if rt ~= nil then
rt.ValueLabel.Text = fn39(arg)
end
end

local function fn41(arg, arg2)
local value = arg.Value
if type(value) == "table" then
return value[arg2] == true
end
return value == arg2
end

local function fn42(arg, arg2, arg3, arg4)
local Unselected = v121.get("Unselected")
local imageTransparency = 1

if arg3 then
Unselected = v121.get(v86[174])
imageTransparency = 0
end

arg2.Tick.ImageColor3 = v121.get("TextColor")

if arg4 then
arg2.Button.TextColor3 = Unselected
arg2.Tick.ImageTransparency = imageTransparency
return
end

arg._menu:Tween(arg2.Button, { TextColor3 = Unselected })
arg._menu:Tween(arg2.Tick, { ImageTransparency = imageTransparency })
end

local function fn43(arg, arg2)
local panel = arg._panel
if panel == nil or not panel.Popup:IsOpen() then
return
end

for k, v123 in panel.Rows, nil, nil do
local v124 = arg.Options[k]
fn42(arg, v123, v124 ~= nil and fn41(arg, v124), arg2)
end
end

local function fn44(arg, arg2)
local panel = arg._panel
if panel == nil then
return
end
local str7 = arg2:lower()

for _, v123 in panel.Rows, nil, nil do
v123.Button.Visible = v123.Button.Text:lower():find(str7, 1, true) ~= nil
end

panel.Scroll.CanvasPosition = Vector2.zero
end

local function fn45(arg, arg2)
local v123 = arg.Options[arg2]
if v123 == nil then
return
end

if arg.Multi then
local tbl18 = {}
local value = arg.Value

if type(value) == "table" then
for k in value, nil, nil do
tbl18[k] = true
end
end

if tbl18[v123] then
tbl18[v123] = nil
else
tbl18[v123] = true
end

arg:Set(tbl18)
return
end

arg:Set(v123)
local panel = arg._panel

if arg.CloseOnSelect and panel ~= nil then
panel.Popup:SetOpen(v86[153])
end
end

local function fn46(arg, arg2, layoutOrder)
local listRowHeight = v117.get().Row.ListRowHeight
local textButton = Instance.new("TextButton")
textButton.AutoButtonColor = false
textButton.BackgroundTransparency = v86[63]
textButton.TextColor3 = v121.get(v86[96])
textButton.Text = ""
textButton.Size = UDim2.new(1, 0, v86[186], listRowHeight)
textButton.ClipsDescendants = v86[34]
textButton.TextXAlignment = Enum.TextXAlignment.Left
textButton.BorderSizePixel = 0
textButton.TextSize = v86[13]
textButton.FontFace = arg._menu.Fonts.Main
textButton.LayoutOrder = layoutOrder
textButton.Parent = arg2.Scroll
local instance = Instance.new(v86[113])
instance.PaddingTop = UDim.new(0, 5)
instance.PaddingBottom = UDim.new(0, 5)
instance.PaddingRight = UDim.new(0, 5)
instance.PaddingLeft = UDim.new(0, 29)
instance.Parent = textButton
local imageLabel = Instance.new("ImageLabel")
imageLabel.Image = "rbxassetid://73347151382921"
imageLabel.ImageColor3 = v121.get(v86[174])
imageLabel.ImageTransparency = 1
imageLabel.BackgroundTransparency = 1
imageLabel.AnchorPoint = Vector2.new(0, 0.5)
imageLabel.Position = UDim2.new(0, -22, 0.5, 0)
imageLabel.Size = UDim2.fromOffset(14, 14)
imageLabel.BorderSizePixel = 0
imageLabel.Parent = textButton

v119.connectClick(arg._trove, textButton, function()
if arg2.Popup:IsOpen() then
fn45(arg, layoutOrder)
end
end)

return { Button = textButton, Tick = imageLabel }
end

local function fn47(arg)
local listRowHeight = v117.get().Row.ListRowHeight
local n = #arg.Rows
local scroll = arg.Scroll
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
scroll.CanvasSize = UDim2.fromOffset(0, n * listRowHeight + v86[122])

if n >= 10 then
scroll.Size = UDim2.new(v86[63], -1, 0, math.min(v86[162], n) * listRowHeight + 7)
scroll.AutomaticSize = Enum.AutomaticSize.None
else
scroll.Size = UDim2.new(1, -1, 0, v86[186])
scroll.AutomaticSize = Enum.AutomaticSize.Y
end
end

local function fn48(arg)
local panel = arg._panel
if panel == nil then
return
end
local rows = panel.Rows
local options = arg.Options

for k, v123 in options, nil, nil do
local v124 = rows[k]

if v124 == nil then
v124 = fn46(arg, panel, k)
rows[k] = v124
end

local v125 = fn38(arg, v123)

if v124.Button.Text ~= v125 then
v124.Button.Text = v125
end

if not v124.Button.Visible then
v124.Button.Visible = true
end
end

for i = #rows, #options + 1, -v86[63] do
rows[i].Button:Destroy()
rows[i] = nil
end

fn47(panel)
panel.RepositionTrove:Clean()

panel.RepositionTrove:Add(task.defer(function()
panel.Popup:Reposition()
end))
end

local function fn49(arg, arg2)
local listRowHeight = v117.get().Row.ListRowHeight
local menu = arg._menu
local root = arg2.Popup.Root
local instance = Instance.new(v86[128])
instance.BackgroundColor3 = v121.get(v86[168])
instance.BorderSizePixel = 0
instance.Size = UDim2.new(1, 0, 0, listRowHeight)
instance.ClipsDescendants = true
instance.Parent = root
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], v86[175])
uiCorner.Parent = instance
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = v121.get("Outline")
uiStroke.Parent = instance
local textBox = Instance.new("TextBox")
textBox.PlaceholderText = v86[190]
textBox.PlaceholderColor3 = v121.get("Unselected")
textBox.FontFace = menu.Fonts.Main
textBox.TextColor3 = v121.get(v86[174])
textBox.Text = ""
textBox.AnchorPoint = Vector2.new(0, 0.5)
textBox.Position = UDim2.new(v86[186], v86[54], 0.5, 0)
textBox.Size = UDim2.new(1, -12, 1, 0)
textBox.BackgroundTransparency = 1
textBox.BorderSizePixel = 0
textBox.TextSize = 14
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = true
textBox.Active = v86[34]
textBox.Parent = instance
arg2.SearchInput = textBox
arg2.Scroll.Position = UDim2.fromOffset(v86[186], v86[192])

arg._trove:Connect(textBox:GetPropertyChangedSignal("Text"), function()
fn44(arg, textBox.Text)
end)

arg._trove:Connect(textBox.Focused, function()
menu:Tween(textBox, { TextColor3 = v121.get("Accent") })
end)

arg._trove:Connect(textBox.FocusLost, function()
menu:Tween(textBox, { TextColor3 = v121.get("TextColor") })
end)
end

local function fn50(arg)
local panel = arg._panel
if panel ~= nil then
return panel
end
local rt = arg._rt
if rt == nil then
return nil
end
local panel2 = nil

local v123 = v120.new(arg._menu, arg._trove, {
Trigger = rt.Pill,
Size = UDim2.fromOffset(80, 0),
AutomaticSize = Enum.AutomaticSize.Y,
AnchorPoint = Vector2.new(1, 0),
Glow = v86[34],
ParentEntry = arg._parentOverlay,
Place = function(arg2, arg3)
local absolutePosition = arg2.AbsolutePosition
local n = math.floor(arg2.AbsoluteSize.X + 2 + 0.5)
local n33 = math.max(n, 80)
local n34 = v86[186]

for _, v123 in panel2.Rows, nil, nil do
if v123.Button.Visible then
n34 = math.max(n34, v123.Button.TextBounds.X)
end
end

arg3.Size = UDim2.fromOffset(math.max(n33, math.ceil(n34) + 40), v86[186])
return math.floor(absolutePosition.X + 0.5) + n, (math.floor(absolutePosition.Y + arg2.AbsoluteSize.Y + 4))
end,
OnToggle = function(arg2)
arg._menu:Tween(rt.Arrow, { Rotation = arg2 and 180 or 0 })
panel2.FocusTrove:Clean()

if not arg2 then
local searchInput = panel2.SearchInput

if searchInput ~= nil then
searchInput:ReleaseFocus()
end

return
end

local getOptions = arg._getOptions

if getOptions ~= nil then
arg:SetOptions(getOptions())
end

fn43(arg, true)
panel2.Scroll.CanvasPosition = Vector2.zero
local searchInput = panel2.SearchInput

if searchInput ~= nil then
searchInput.Text = ""
fn44(arg, "")

panel2.FocusTrove:Add(task.defer(function()
if panel2.Popup:IsOpen() then
searchInput:CaptureFocus()
end

if not flag2 then
return
end
end))
end
end,
})

local y = v122.currentViewportSize().Y
local n = math.floor(y * 0.6)

if v118.IsMobile() then
n = math.floor(y * 0.5)
end

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Active = true
scrollingFrame.ScrollBarImageTransparency = v86[101]
scrollingFrame.ScrollBarThickness = v86[26]
scrollingFrame.Size = UDim2.new(1, -v86[63], 0, 0)
scrollingFrame.BorderSizePixel = 0
scrollingFrame.BackgroundTransparency = v86[63]
scrollingFrame.AutomaticSize = Enum.AutomaticSize.Y
scrollingFrame.CanvasSize = UDim2.fromOffset(0, v86[186])
scrollingFrame.Selectable = v86[153]
scrollingFrame.ScrollBarImageColor3 = v121.get("Accent")
scrollingFrame.Parent = v123.Root
local instance = Instance.new(v86[176])
instance.MaxSize = Vector2.new(math.huge, n)
instance.Parent = scrollingFrame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, v86[122])
uiPadding.Parent = scrollingFrame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollingFrame

panel2 = {
Popup = v123,
Scroll = scrollingFrame,
SearchInput = nil,
Rows = {},
RepositionTrove = v123.Trove:Extend(),
FocusTrove = v123.Trove:Extend(),
}

arg._panel = panel2

if arg.Search then
fn49(arg, panel2)
end

fn48(arg)
return panel2
end

local function createTextButton(arg, parent, arg2)
local menu = arg._menu
local v123 = v117.get()
local inline = arg.Inline
local textButton = Instance.new("TextButton")
textButton.AutoButtonColor = false
textButton.Text = ""
textButton.AnchorPoint = Vector2.new(1, v86[101])
textButton.Position = UDim2.new(1, -v86[63], 0.5, 0)
textButton.BorderSizePixel = 0
textButton.BackgroundColor3 = color

if inline then
textButton.Size = UDim2.fromOffset(0, v123.Row.ControlHeight)
textButton.ClipsDescendants = true
textButton.AutomaticSize = Enum.AutomaticSize.X
else
textButton.Size = UDim2.fromOffset(137, 24)
end

textButton.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
arg2.Batch:BindGradient(uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = textButton
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[175])
uiCorner.Parent = textButton

if inline then
local uiSizeConstraint = Instance.new("UISizeConstraint")
uiSizeConstraint.MaxSize = Vector2.new(arg.MaxWidth, v123.Row.ControlHeight)
uiSizeConstraint.Parent = textButton
end

local uiStroke = Instance.new("UIStroke")

if not inline then
uiStroke.BorderOffset = UDim.new(0, -1)
end

uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = textButton
local imageLabel = Instance.new("ImageLabel")
imageLabel.Image = "rbxassetid://84796267467531"
imageLabel.BackgroundTransparency = v86[63]
imageLabel.Size = UDim2.fromOffset(9, 5)
imageLabel.BorderSizePixel = v86[186]

if inline then
imageLabel.LayoutOrder = 1
else
imageLabel.AnchorPoint = Vector2.new(1, 0.5)
imageLabel.Position = UDim2.new(1, -8, 0.5, 0)
end

arg2.Batch:Bind(imageLabel, "ImageColor3", "Unselected")
imageLabel.Parent = textButton
local instance = Instance.new(v86[135])
instance.Text = fn39(arg)
instance.AnchorPoint = Vector2.new(0, v86[101])
instance.Position = UDim2.new(0, 5, v86[101], 0)
instance.BackgroundTransparency = 1
instance.BorderSizePixel = 0
instance.TextSize = v86[13]
instance.TextTruncate = Enum.TextTruncate.AtEnd

if inline then
instance.LayoutOrder = -1
instance.FontFace = menu.Fonts.Main
instance.AutomaticSize = Enum.AutomaticSize.XY
else
instance.ClipsDescendants = true
instance.FontFace = v116.Medium
instance.Size = UDim2.new(1, -25, 0, 0)
instance.TextXAlignment = Enum.TextXAlignment.Left
instance.AutomaticSize = Enum.AutomaticSize.Y
end

arg2.Batch:Bind(instance, "TextColor3", "TextColor")
instance.Parent = textButton

if inline then
local instance2 = Instance.new(v86[113])
instance2.PaddingBottom = UDim.new(0, 2)
instance2.Parent = instance
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.Padding = UDim.new(0, 6)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = textButton
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(v86[186], 2)
uiPadding.PaddingRight = UDim.new(0, 6)
uiPadding.PaddingLeft = UDim.new(v86[186], v86[54])
uiPadding.Parent = textButton
local v124 = menu:DragTweenInfo()

arg2.Trove:Connect(instance:GetPropertyChangedSignal("Text"), function()
local controlHeight = v123.Row.ControlHeight
menu:Tween(textButton, { Size = UDim2.fromOffset(math.min(instance.AbsoluteSize.X, arg.MaxWidth), controlHeight) }, v124)
end)

arg2.Trove:Add(task.defer(function()
if instance.Parent ~= nil then
local controlHeight = v123.Row.ControlHeight
textButton.Size = UDim2.fromOffset(math.min(instance.AbsoluteSize.X + v86[144], arg.MaxWidth + 22), controlHeight)
end
end))
end

arg._rt = { Pill = textButton, ValueLabel = instance, Arrow = imageLabel }

if arg._parentOverlay == nil then
arg._parentOverlay = arg2.ParentOverlay
end

v119.connectClick(arg2.Trove, textButton, function()
if #arg.Options == 0 and arg._getOptions == nil then
return
end
local v124 = fn50(arg)

if v124 ~= nil then
v124.Popup:Toggle()
end
end)

local v124 = nil

v119.connectPress(arg2.Trove, textButton, function()
local backgroundColor3 = textButton.BackgroundColor3
v124 = backgroundColor3
menu:Tween(textButton, { BackgroundColor3 = Color3.new(backgroundColor3.R * v86[105], backgroundColor3.G * 0.85, backgroundColor3.B * 0.85) }, tweenInfo)
end, function()
if v124 ~= nil then
menu:Tween(textButton, { BackgroundColor3 = v124 }, tweenInfo)
v124 = nil
end
end)

return textButton
end

local function fn51(arg, arg2, arg3, arg4, arg5, arg6, arg7)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "Dropdown",
Row = arg2,
Multi = arg5,
Search = arg4.Search == true,
Inline = arg4.Inline == true,
CloseOnSelect = arg4.CloseOnSelect == true,
MaxWidth = arg4.MaxWidth or 300,
Options = table.clone(arg4.Options or {}),
_labelByValue = arg4.Labels or {},
Value = arg6,
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg7,
_getOptions = arg4.GetOptions,
_isOptionsPublished = arg4.Options ~= nil or arg4.GetOptions == nil,
_indexByName = {},
_rt = nil,
_panel = nil,
_parentOverlay = nil,
}, index2)

fn37(obj)
local n = 138

if obj.Inline then
n = nil
end

arg2:AttachRight(function(arg8, arg9)
return createTextButton(obj, arg8, arg9)
end, n, nil, arg3)

return obj
end

index2._New = function(arg, arg2, arg3, arg4)
local options = arg4.Options or {}
local default = arg4.Default

if not (default ~= nil and (not (arg4.Options ~= nil or arg4.GetOptions == nil) or table.find(options, default) ~= nil)) then
default = options[1]
end

local onChanged = arg4.OnChanged

local function fn52()
end

if onChanged ~= nil then
fn52 = function(arg5)
onChanged(arg5)
end
end

return (fn51(arg, arg2, arg3, arg4, false, default, fn52))
end

index2._NewMulti = function(arg, arg2, arg3, arg4)
local onChanged = arg4.OnChanged

local function fn52()
end

if onChanged ~= nil then
fn52 = function(arg5)
onChanged(arg5)
end
end

return (fn51(arg, arg2, arg3, arg4, v86[34], fn36(arg4.Default), fn52))
end

local function fn52(arg, arg2)
for k in arg, nil, nil do
if not arg2[k] then
return false
end
end

for k in arg2, nil, nil do
if not arg[k] then
return false
end
end

return true
end

index2.Set = function(I,W,N)if I.Multi then local P= fn36 (W);local a=I.Value;if type(a)=="table"and( fn52 (P,a))then return;end;I.Value=P; fn43 (I,N==true); fn40 (I);I.ValueChanged:Fire(I.Value);if not N then I._onChanged(I.Value);I.Changed:Fire(I.Value);end;return;end;local P=if type(W)=="string"and(not I._isOptionsPublished or I._indexByName[W]~=nil)then W else nil;local a=I._isOptionsPublished and W~=nil and P==nil;if P==I.Value and not a then return;end;W=I.Value;I.Value=P;a=I._panel;if a~=nil and(a.Popup:IsOpen())then local e=N==true;local c=type(W)=="string"and I._indexByName[W]or nil;if c~=nil and a.Rows[c]~=nil then  fn42 (I,a.Rows[c],false,e);end;c=P~=nil and I._indexByName[P]or nil;if c~=nil and a.Rows[c]~=nil then  fn42 (I,a.Rows[c],true,e);end;end; fn40 (I);I.ValueChanged:Fire(I.Value);if not N then I._onChanged(I.Value);I.Changed:Fire(I.Value);end;end

index2.SetOptions = function(arg, arg2)
local tbl18 = arg2 or {}
local options = arg.Options
local isOptionsPublished = arg._isOptionsPublished
arg._isOptionsPublished = true

if isOptionsPublished and #tbl18 == #options then
local flag19 = true

for k, v123 in tbl18, nil, nil do
if options[k] ~= v123 then
flag19 = v86[153]
break
end
end

if flag19 then
return
end
end

local value = arg.Value
arg.Options = table.clone(tbl18)
fn37(arg)
fn48(arg)

if arg.Multi then
fn43(arg, true)
fn40(arg)
arg.ValueChanged:Fire(arg.Value)
return
end

local value2 = arg.Value

if type(value2) ~= "string" or arg._indexByName[value2] == nil then
arg.Value = nil
end

fn43(arg, true)
fn40(arg)
arg.ValueChanged:Fire(arg.Value)

if value ~= arg.Value then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

index2.Add = function(arg, arg2)
local v123 = v86[165]
if type(arg2) ~= v123 or arg._indexByName[arg2] ~= nil then
return
end
local v124 = table.clone(arg.Options)
table.insert(v124, arg2)
arg:SetOptions(v124)
end

index2.Remove = function(arg, arg2)
local v123 = arg._indexByName[arg2]
if v123 == nil then
return
end
local v124 = table.clone(arg.Options)
table.remove(v124, v123)
arg:SetOptions(v124)
end

index2.SetOpen = function(arg, arg2)
local v123 = fn50(arg)

if v123 ~= nil then
v123.Popup:SetOpen(arg2)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.H = function()
local h = tbl17.cache.H

if not h then
h = { c = fn35() }
tbl17.cache.H = h
end

return h.c
end
end
do -- I
local function fn35()
tbl17.r()
local v115 = tbl17.s()
tbl17.B()
local v116 = tbl17.w()
local color = Color3.fromRGB(v86[108], 255, 255)
local udim2 = UDim2.fromOffset(14, 14)
local udim22 = UDim2.fromOffset(18, 18)

return {
buildTrack = function(parent, arg, arg2)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.fromScale(0, 0.5)
frame.Size = UDim2.new(1, -arg2 - 11, 0, 2)
frame.BorderSizePixel = 0
frame.BackgroundColor3 = color
frame.Parent = parent
local uiGradient = Instance.new("UIGradient")
arg.Batch:BindGradient(uiGradient, { "GradientDark", v86[187] })
uiGradient.Parent = frame
local uiStroke = Instance.new("UIStroke")
arg.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[63], 0)
uiCorner.Parent = frame
local instance = Instance.new(v86[128])
instance.AnchorPoint = Vector2.new(0.5, 0.5)
instance.Position = UDim2.fromScale(0.5, 0.5)
instance.Size = UDim2.new(1, v86[186], 0, 44)
instance.BackgroundTransparency = 1
instance.BorderSizePixel = v86[186]
instance.Active = true
instance.ZIndex = 0
instance.Parent = frame
return frame, instance
end,
buildThumb = function(parent)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(v86[186], 0.5)
frame.Size = udim2
frame.BorderSizePixel = v86[186]
frame.BackgroundColor3 = color
frame.ZIndex = 2
frame.Parent = parent
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)
uiCorner.Parent = frame
return frame
end,
setThumbPressed = function(arg, arg2, arg3)
arg:Tween(arg2, { Size = arg3 and udim22 or udim2 })
end,
valueAt = function(arg, arg2, arg3, arg4)
return (arg4 - arg3) * (arg2 - arg.AbsolutePosition.X) / arg.AbsoluteSize.X + arg3
end,
newTouchBubble = function(arg, arg2)
local v117 = nil
local v118 = nil

local function fn36()
local v119 = v117
local v120 = v118
if v119 ~= nil and v120 ~= nil then
return v119, v120
end
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(v86[101], 0.5)
frame.Size = UDim2.fromOffset(42, 28)
frame.BorderSizePixel = 0
frame.Visible = false
frame.ZIndex = 20
arg2.Batch:Bind(frame, v86[5], "Background")
arg2.Trove:Add(frame)
frame.Parent = arg:GetOverlayLayer()
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = frame
local instance = Instance.new(v86[135])
instance.FontFace = v115.SemiBold
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = v86[186]
instance.TextSize = 14
instance.ZIndex = 21
arg2.Batch:Bind(instance, "TextColor3", "TextColor")
instance.Parent = frame
v117 = frame
v118 = instance
return frame, instance
end

return {
Show = function(arg3, text)
local v119, v120 = fn36()
v120.Text = text
v119.Size = UDim2.fromOffset(math.max(42, #text * 8 + 16), v86[25])
local n = arg3.AbsolutePosition + arg3.AbsoluteSize / 2
local v121 = v116.absoluteToLayerOffset(arg:GetOverlayLayer(), n)
v119.Position = UDim2.fromOffset(v121.X, v121.Y - 40)
v119.Visible = v86[34]
end,
Hide = function()
if v117 ~= nil then
v117.Visible = false
end
end,
}
end,
}
end

tbl17.I = function()
local i = tbl17.cache.I

if not i then
i = { c = fn35() }
tbl17.cache.I = i
end

return i.c
end
end
do -- J
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.x()
tbl17.B()
local v119 = tbl17.I()
local v120 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2, arg3)
local min = arg.Min
local max = arg.Max
local n = math.clamp(v120.round(arg2, arg.Step), min, max)
local n33 = math.clamp(v120.round(arg3, arg.Step), arg.Min, arg.Max)

if not (n33 < n) then
local v121 = n33
n33 = n
n = v121
end

return n33, n
end

local function fn37(arg, arg2)
if arg.Max == arg.Min then
return v86[186]
end
return (arg2 - arg.Min) / (arg.Max - arg.Min)
end

local function fn38(arg, arg2)
local v121 = fn37(arg, arg.Value.Min)
local v122 = fn37(arg, arg.Value.Max)
arg2.MinThumb.Position = UDim2.fromScale(v121, v86[101])
arg2.MaxThumb.Position = UDim2.fromScale(v122, v86[101])
local udim2 = UDim2.fromScale(v121, 0)
local udim22 = UDim2.fromScale(v122 - v121, v86[63])

if arg._isDragging then
arg2.Accent.Position = udim2
arg2.Accent.Size = udim22
else
arg._menu:Tween(arg2.Accent, { Position = udim2, Size = udim22 }, arg._menu:DragTweenInfo())
end

local v123 = tostring
local max = arg.Value.Max
arg2.ValueLabel.Text = ("%s - %s"):format(tostring(arg.Value.Min), v123(max))
end

local function fn39(arg, parent, arg2, arg3)
local menu = arg._menu
local controlHeight = v117.get().Row.ControlHeight
local v121, v122 = v119.buildTrack(parent, arg2, arg3)
local frame = Instance.new("Frame")
frame.Position = UDim2.new(0, 0, 0, v86[186])
frame.Size = UDim2.fromScale(0, 1)
frame.BorderSizePixel = 0
arg2.Batch:Bind(frame, "BackgroundColor3", v86[139])
frame.Parent = v121
local v123 = v119.buildThumb(v121)
local v124 = v119.buildThumb(v121)
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(v86[63], 0.5)
frame2.Position = UDim2.fromScale(1, 0.5)
frame2.Size = UDim2.fromOffset(arg3, controlHeight)
frame2.BorderSizePixel = v86[186]
frame2.ClipsDescendants = v86[34]
arg2.Batch:Bind(frame2, "BackgroundColor3", "Background")
frame2.Parent = parent
local instance = Instance.new(v86[176])
instance.MinSize = Vector2.new(arg3, controlHeight)
instance.Parent = frame2
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], 5)
uiCorner.Parent = frame2
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = frame2
local textLabel = Instance.new("TextLabel")
textLabel.FontFace = v116.SemiBold
textLabel.Text = ""
textLabel.BackgroundTransparency = 1
textLabel.Size = UDim2.fromScale(1, 1)
textLabel.BorderSizePixel = 0
textLabel.TextSize = 14
arg2.Batch:Bind(textLabel, v86[167], "TextColor")
textLabel.Parent = frame2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingRight = UDim.new(0, 6)
uiPadding.PaddingLeft = UDim.new(0, 6)
uiPadding.Parent = textLabel
local rt = { Outline = v121, Accent = frame, MinThumb = v123, MaxThumb = v124, ValueLabel = textLabel }
arg._rt = rt
local v125 = nil
local v126 = v119.newTouchBubble(menu, arg2)

local function fn40(arg4)
return arg4 == v86[16] and v123 or v124
end

local function fn41(arg4)
local x = v121.AbsolutePosition.X
local x2 = v121.AbsoluteSize.X
local n = x + fn37(arg, arg.Value.Min) * x2
local n33 = x + fn37(arg, arg.Value.Max) * x2
return math.abs(arg4 - n) < math.abs(arg4 - n33) and v86[16] or "max"
end

local function fn42(arg4, arg5)
local v127 = v125

if v127 == nil then
v127 = arg5 or fn41(arg4.Position.X)
v125 = v127
v119.setThumbPressed(menu, fn40(v127), true)
end

local v128 = v119.valueAt(v121, arg4.Position.X, arg.Min, arg.Max)

if v127 == v86[16] then
arg:Set({ Min = v128, Max = arg.Value.Max })
else
arg:Set({ Min = arg.Value.Min, Max = v128 })
end

if arg4.UserInputType == Enum.UserInputType.Touch then
local min = v127 == "min" and arg.Value.Min or arg.Value.Max
local v129 = tostring
v126.Show(fn40(v127), v129(min))
end
end

local tbl18 = nil

local function fn43(isDragging, arg4)
arg._isDragging = isDragging
if isDragging then
tbl18 = { Min = arg.Value.Min, Max = arg.Value.Max }
return
end

if arg4 and tbl18 ~= nil then
arg:Set(tbl18, true)
end

tbl18 = nil

if v125 ~= nil then
v119.setThumbPressed(menu, fn40(v125), false)
v125 = nil
end

v126.Hide()
end

v118.connectDrag(arg2.Trove, v122, function(arg4)
fn42(arg4, nil)
end, fn43)

v118.connectDrag(arg2.Trove, v123, function(arg4)
fn42(arg4, "min")
end, fn43)

v118.connectDrag(arg2.Trove, v124, function(arg4)
fn42(arg4, "max")
end, fn43)

arg2.Trove:Connect(arg.ValueChanged, function()
fn38(arg, rt)
end)

fn38(arg, rt)
end

index2._New = function(arg, arg2, arg3, arg4)
local min = arg4.Min
local max = arg4.Max

local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "RangeSlider",
Row = arg2,
Min = min,
Max = max,
Step = arg4.Step or v86[63],
Value = { Min = min, Max = max },
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_isDragging = false,
_rt = nil,
}, index2)

local default = arg4.Default

if default ~= nil then
local v121, v122 = fn36(obj, default.Min, default.Max)
obj.Value = { Min = v121, Max = v122 }
end

local n = math.max(v86[8], (#tostring(min) + #tostring(max) + 3) * 8 + 20)

arg2:AttachRight(function(arg5, arg6)
fn39(obj, arg5, arg6, n)
return nil
end, nil, nil, arg3)

return obj
end

index2.Set = function(arg, arg2, arg3)
if type(arg2) ~= "table" then
return
end
local v121, v122 = fn36(arg, tonumber(arg2.Min) or arg.Value.Min, tonumber(arg2.Max) or arg.Value.Max)
if v121 == arg.Value.Min and v122 == arg.Value.Max then
return
end
arg.Value = { Min = v121, Max = v122 }
arg.ValueChanged:Fire(arg.Value)

if not arg3 then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.J = function()
local j = tbl17.cache.J

if not j then
local j2 = { c = fn35() }
tbl17.cache.J = j2
j = j2
end

return j.c
end
end
do -- K
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.x()
tbl17.B()
local v119 = tbl17.I()
local v120 = tbl17.w()
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local color = Color3.fromRGB(255, v86[108], 255)
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2)
return math.clamp(v120.round(tonumber(arg2) or arg.Min, arg.Step), arg.Min, arg.Max)
end

local function fn37(arg)
local suffix = arg.Suffix
local step = arg.Step
-- display patch: tostring() of a Step-0.01 value can emit float noise
-- (round(0.35,0.01) -> 0.35000000000000003). Format to the Step's own
-- decimal count and drop trailing zeros. Step >= 1 keeps tostring().
if type(step) == "number" and step > 0 and step < 1 then
local s = tostring(step)
local dot = s:find(".", 1, true)
local decimals = dot and math.min(#s - dot, 6) or 0
local text = string.format("%." .. decimals .. "f", arg.Value)
return (text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")) .. suffix
end
return tostring(arg.Value) .. suffix
end

local function fn38(arg, arg2, arg3)
arg2.ValueText.Text = fn37(arg)

if not arg._isDragging then
arg2.UpdateValueBoxSize()
end

local n = 0

if arg.Max ~= arg.Min then
n = (arg.Value - arg.Min) / (arg.Max - arg.Min)
end

if arg._isDragging or arg3 then
arg2.Accent.Size = UDim2.fromScale(n, 1)
return
end
arg._menu:Tween(arg2.Accent, { Size = UDim2.fromScale(n, 1) }, arg._menu:DragTweenInfo())
end

local function fn39(arg, parent, arg2, arg3)
local menu = arg._menu
local controlHeight = v117.get().Row.ControlHeight
local v121, v122 = v119.buildTrack(parent, arg2, arg3)
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(v86[186], v86[63])
frame.BorderSizePixel = 0
arg2.Batch:Bind(frame, v86[5], "Accent")
frame.Parent = v121
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, v86[27], v86[139])
uiStroke.Parent = frame
local v123 = v119.buildThumb(frame)
v123.Position = UDim2.fromScale(1, 0.5)
local instance = Instance.new(v86[128])
instance.AnchorPoint = Vector2.new(1, 0.5)
instance.Position = UDim2.fromScale(v86[63], 0.5)
instance.Size = UDim2.fromOffset(arg3, controlHeight)
instance.BorderSizePixel = v86[186]
instance.ClipsDescendants = true
instance.BackgroundColor3 = color
instance.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
arg2.Batch:BindGradient(uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = instance
local uiSizeConstraint = Instance.new("UISizeConstraint")
uiSizeConstraint.MinSize = Vector2.new(24, controlHeight)
uiSizeConstraint.Parent = instance
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[175])
uiCorner.Parent = instance
local uiStroke2 = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke2, "Color", v86[120])
uiStroke2.Parent = instance
local textBox = Instance.new("TextBox")
textBox.FontFace = v116.SemiBold
textBox.Text = ""
textBox.BackgroundTransparency = 1
textBox.Size = UDim2.fromScale(1, 1)
textBox.BorderSizePixel = 0
textBox.TextSize = 16
textBox.TextScaled = false
arg2.Batch:Bind(textBox, "TextColor3", "TextColor")
textBox.Parent = instance
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingRight = UDim.new(0, 5)
uiPadding.PaddingLeft = UDim.new(v86[186], 5)
uiPadding.Parent = textBox

local function fn40()
local n = #textBox.Text
local n33 = 16

if n > 5 then
n33 = math.max(v86[181], 16 - n - 5)
end

if textBox.TextSize ~= n33 then
menu:Tween(textBox, { TextSize = n33 }, tweenInfo)
end

local n34 = math.clamp(n * n33 * 0.6 + 12, arg3, 72)

if instance.Size.X.Offset ~= n34 then
menu:Tween(instance, { Size = UDim2.fromOffset(n34, controlHeight) }, tweenInfo)
menu:Tween(v121, { Size = UDim2.new(v86[63], -n34 - v86[181], v86[186], 2) }, tweenInfo)
end
end

local rt = { Outline = v121, Accent = frame, ValueBox = instance, ValueText = textBox, UpdateValueBoxSize = fn40 }
arg._rt = rt

arg2.Trove:Connect(textBox.FocusLost, function()
local num = tonumber(textBox.Text:match("[%d%.%-]+"))

if num == nil then
fn38(arg, rt, true)
else
arg:Set(num)
end

fn40()
end)

local v124 = v119.newTouchBubble(menu, arg2)

local function fn41(arg4)
arg:Set(v119.valueAt(v121, arg4.Position.X, arg.Min, arg.Max))

if arg4.UserInputType == Enum.UserInputType.Touch then
v124.Show(v123, fn37(arg))
end
end

local value = nil

local function fn42(isDragging, arg4)
arg._isDragging = isDragging
v119.setThumbPressed(menu, v123, isDragging)
if isDragging then
value = arg.Value
return
end
v124.Hide()

if arg4 and value ~= nil then
arg:Set(value, true)
end

value = nil
fn40()
end

v118.connectDrag(arg2.Trove, v122, fn41, fn42)
v118.connectDrag(arg2.Trove, v123, fn41, fn42)

arg2.Trove:Connect(arg.ValueChanged, function()
fn38(arg, rt, false)
end)

fn38(arg, rt, true)
fn40()
end

index2._New = function(arg, arg2, arg3, arg4)
local min = arg4.Min
local max = arg4.Max
local suffix = arg4.Suffix or ""

local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = v86[39],
Row = arg2,
Min = min,
Max = max,
Step = arg4.Step or v86[63],
Suffix = suffix,
Value = v86[186],
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_isDragging = false,
_rt = nil,
}, index2)

obj.Value = fn36(obj, arg4.Default or min)
local v121 = v86[183]
local n = math.clamp(math.max(#tostring(min) + #suffix, #tostring(max) + #suffix) * 16 * 0.6 + 12, 24, v121)

arg2:AttachRight(function(arg5, arg6)
fn39(obj, arg5, arg6, n)
return nil
end, nil, nil, arg3)

return obj
end

index2.Set = function(arg, arg2, arg3)
local v121 = fn36(arg, arg2)
if v121 == arg.Value then
return
end
arg.Value = v121
arg.ValueChanged:Fire(v121)

if not arg3 then
arg._onChanged(v121)
arg.Changed:Fire(v121)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.K = function()
local k = tbl17.cache.K

if not k then
local k2 = { c = fn35() }
tbl17.cache.K = k2
k = k2
end

return k.c
end
end
do -- L
local function fn35()
local v115 = tbl17.E()
tbl17.r()
local v116 = tbl17.H()
local v117 = tbl17.s()
local v118 = tbl17.x()
tbl17.G()
local v119 = tbl17.J()
local v120 = tbl17.B()
local v121 = tbl17.K()
local v122 = tbl17.A()
local v123 = tbl17.w()
local color = Color3.fromRGB(v86[108], v86[108], 255)
local tbl18 = { "None", "Rainbow", "Breathing" }
local tbl19 = { "None", "Rainbow" }

local function fn36(parent, arg, arg2)
local n = 12

if arg2 then
n = 27
end

local frame = Instance.new("Frame")
frame.ClipsDescendants = v86[34]
frame.Size = UDim2.fromOffset(0, v86[144])
frame.AutomaticSize = Enum.AutomaticSize.X
frame.BorderSizePixel = v86[186]
frame.BackgroundColor3 = v122.get(v86[168])
frame.Parent = parent
local instance = Instance.new(v86[176])
instance.MinSize = Vector2.new(math.min(arg + n, n + 36), 22)
instance.MaxSize = Vector2.new(arg + n, 22)
instance.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = frame
local instance2 = Instance.new(v86[85])
instance2.Color = v122.get("Outline")
instance2.Parent = frame
local textBox = Instance.new("TextBox")
textBox.ClearTextOnFocus = false
textBox.FontFace = v117.SemiBold
textBox.TextColor3 = v122.get("TextColor")
textBox.Text = ""
textBox.AnchorPoint = Vector2.new(0, 0)
textBox.BorderSizePixel = 0
textBox.BackgroundTransparency = 1
textBox.Position = UDim2.new(0, 0, 0, 0)
textBox.Size = UDim2.new(1, 0, 1, 0)
textBox.AutomaticSize = Enum.AutomaticSize.None
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.TextSize = v86[13]
textBox.Selectable = false
textBox.Active = true
textBox.Parent = frame
local instance3

if arg2 then
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.Padding = UDim.new(0, v86[175])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame
local instance4 = Instance.new(v86[113])
instance4.PaddingRight = UDim.new(0, 5)
instance4.PaddingLeft = UDim.new(0, 5)
instance4.Parent = frame
instance3 = Instance.new(v86[128])
instance3.LayoutOrder = -1
instance3.Size = UDim2.fromOffset(12, 12)
instance3.BorderSizePixel = 0
instance3.Parent = frame
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(0, 3)
uiCorner2.Parent = instance3
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, 2)
uiPadding.PaddingLeft = UDim.new(0, -v86[63])
uiPadding.PaddingRight = UDim.new(0, v86[63])
uiPadding.Parent = textBox
else
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingRight = UDim.new(0, v86[175])
uiPadding.PaddingLeft = UDim.new(0, 1)
uiPadding.Parent = textBox
instance3 = nil
end

frame.Active = true
frame.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function() textBox:CaptureFocus() end)
end
end)
return frame, textBox, instance3
end

return { build = function(arg, arg2, arg3, arg4, arg5)
local trove = arg2.Trove
local batch = arg2.Batch
local root = arg2.Root
local tbl20 = { Menu = arg, Trove = trove, Batch = batch }
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, v86[170])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = root
local instance = Instance.new(v86[113])
instance.PaddingTop = UDim.new(0, 9)
instance.PaddingBottom = UDim.new(0, 10)
instance.PaddingRight = UDim.new(0, 9)
instance.PaddingLeft = UDim.new(0, 9)
instance.Parent = root
local frame = Instance.new("Frame")
frame.LayoutOrder = -1
frame.BackgroundTransparency = 1
frame.Size = UDim2.new(1, 0, 0, 23)
frame.BorderSizePixel = v86[186]
frame.Parent = root
local textLabel = Instance.new("TextLabel")
textLabel.FontFace = v117.Medium
textLabel.Text = v86[184]
textLabel.AnchorPoint = Vector2.new(0, 0.5)
textLabel.BackgroundTransparency = v86[63]
textLabel.Position = UDim2.fromScale(v86[186], 0.5)
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.XY
textLabel.TextSize = v86[13]
batch:Bind(textLabel, "TextColor3", v86[174])
textLabel.Parent = frame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(v86[186], v86[56])
uiPadding.Parent = textLabel
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(1, 0)
frame2.Position = UDim2.fromScale(1, 0)
frame2.BackgroundTransparency = v86[63]
frame2.Size = UDim2.fromScale(0, 1)
frame2.AutomaticSize = Enum.AutomaticSize.X
frame2.BorderSizePixel = 0
frame2.Parent = frame
local instance2 = Instance.new(v86[4])
instance2.SortOrder = Enum.SortOrder.LayoutOrder
instance2.Parent = frame2
local uiPadding2 = Instance.new("UIPadding")
uiPadding2.PaddingTop = UDim.new(0, 1)
uiPadding2.PaddingRight = UDim.new(v86[186], 1)
uiPadding2.PaddingLeft = UDim.new(0, 1)
uiPadding2.Parent = frame2
local v124 = nil

if arg4.Gradient == "editable" then
local v125 = v120.new(arg, { Bare = true })

local tbl21 = {
Inline = v86[34],
MaxWidth = 86,
Options = { "Solid", "Gradient" },
Default = arg3.Mode,
OnChanged = function(arg6)
if type(arg6) == "string" then
arg5.SetMode(arg6)
end
end,
}

v124 = v116._New(arg, v125, trove:Extend(), tbl21)
v125:Realize(frame2, tbl20, 0)
else
frame2.Visible = false
end

local frame3 = Instance.new("Frame")
frame3.LayoutOrder = 0
frame3.BackgroundTransparency = 1
frame3.BorderSizePixel = 0
frame3.AutomaticSize = Enum.AutomaticSize.XY
frame3.Parent = root
local uiListLayout2 = Instance.new("UIListLayout")
uiListLayout2.FillDirection = Enum.FillDirection.Horizontal
uiListLayout2.HorizontalFlex = Enum.UIFlexAlignment.Fill
uiListLayout2.Padding = UDim.new(v86[186], v86[149])
uiListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout2.Parent = frame3
local frame4 = Instance.new("Frame")
frame4.Size = UDim2.fromOffset(241, 234)
frame4.BorderSizePixel = 0
frame4.BackgroundColor3 = Color3.fromRGB(v86[108], 0, 0)
frame4.Parent = frame3
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[133])
uiCorner.Parent = frame4
local frame5 = Instance.new("Frame")
frame5.Size = UDim2.fromScale(1, 1)
frame5.ZIndex = v86[56]
frame5.BorderSizePixel = 0
frame5.BackgroundColor3 = color
frame5.Parent = frame4
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 270
uiGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, v86[186]), NumberSequenceKeypoint.new(1, 1) })
uiGradient.Color = ColorSequence.new(Color3.new(0, 0, 0))
uiGradient.Parent = frame5
local instance3 = Instance.new(v86[98])
instance3.CornerRadius = UDim.new(v86[186], 7)
instance3.Parent = frame5
local frame6 = Instance.new("Frame")
frame6.Size = UDim2.fromScale(v86[63], 1)
frame6.BorderSizePixel = 0
frame6.BackgroundColor3 = color
frame6.Parent = frame4
local uiGradient2 = Instance.new("UIGradient")
uiGradient2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(v86[186], 0), NumberSequenceKeypoint.new(1, 1) })
uiGradient2.Parent = frame6
local instance4 = Instance.new(v86[98])
instance4.CornerRadius = UDim.new(0, 7)
instance4.Parent = frame6
local instance5 = Instance.new(v86[128])
instance5.BackgroundTransparency = 1
instance5.Position = UDim2.fromOffset(v86[122], 7)
instance5.Size = UDim2.new(1, -14, 1, -14)
instance5.ZIndex = v86[56]
instance5.BorderSizePixel = 0
instance5.Parent = frame4
local instance6 = Instance.new(v86[98])
instance6.CornerRadius = UDim.new(v86[186], 7)
instance6.Parent = instance5
local frame7 = Instance.new("Frame")
frame7.AnchorPoint = Vector2.new(0.5, 0.5)
frame7.Position = UDim2.fromScale(0.5, v86[101])
frame7.Size = UDim2.fromOffset(v86[12], 12)
frame7.ZIndex = 100
frame7.BorderSizePixel = 0
frame7.BackgroundColor3 = color
frame7.Parent = instance5
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(v86[186], 7)
uiCorner2.Parent = frame7
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = color
uiStroke.Thickness = 2
uiStroke.Parent = frame7
local frame8 = Instance.new("Frame")
frame8.BackgroundTransparency = 1
frame8.Size = UDim2.fromOffset(v86[186], 234)
frame8.BorderSizePixel = 0
frame8.AutomaticSize = Enum.AutomaticSize.XY
frame8.Parent = frame3
local uiListLayout3 = Instance.new("UIListLayout")
uiListLayout3.Padding = UDim.new(0, 23)
uiListLayout3.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout3.FillDirection = Enum.FillDirection.Horizontal
uiListLayout3.Parent = frame8
local instance7 = Instance.new(v86[113])
instance7.PaddingRight = UDim.new(0, v86[122])
instance7.PaddingLeft = UDim.new(0, v86[175])
instance7.Parent = frame8
local frame9 = Instance.new("Frame")
frame9.Size = UDim2.fromOffset(8, 234)
frame9.BorderSizePixel = 0
frame9.BackgroundColor3 = color
frame9.Parent = frame8
local frame10 = Instance.new("Frame")
frame10.AnchorPoint = Vector2.new(0.5, 0)
frame10.Position = UDim2.fromScale(v86[101], 0)
frame10.Size = UDim2.new(0, 28, 1, 0)
frame10.BackgroundTransparency = 1
frame10.Active = true
frame10.ZIndex = 150
frame10.Parent = frame9
local uiCorner3 = Instance.new("UICorner")
uiCorner3.CornerRadius = UDim.new(0, v86[155])
uiCorner3.Parent = frame9
local uiGradient3 = Instance.new("UIGradient")
uiGradient3.Rotation = v86[45]
local colorSequence = ColorSequence.new
local tbl21 = {}
local v125 = ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, v86[186]))
local v126 = ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0))
local v127 = ColorSequenceKeypoint.new(0.33, Color3.fromRGB(v86[186], 255, 0))
local v128 = ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255))
local v129 = ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255))
local v130 = ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, v86[108]))
tbl21[1] = v125
tbl21[2] = v126
tbl21[3] = v127
tbl21[4] = v128
tbl21[5] = v129
tbl21[6] = v130

do
local values = table.pack(ColorSequenceKeypoint.new(v86[63], Color3.fromRGB(255, 0, v86[186])))
table.move(values, 1, values.n, 7, tbl21)
end

uiGradient3.Color = colorSequence(tbl21)
uiGradient3.Parent = frame9
local frame11 = Instance.new("Frame")
frame11.BackgroundTransparency = 1
frame11.Position = UDim2.fromOffset(0, v86[56])
frame11.Size = UDim2.new(1, 0, 1, -8)
frame11.ZIndex = 2
frame11.BorderSizePixel = 0
frame11.Parent = frame9
local instance8 = Instance.new(v86[128])
instance8.AnchorPoint = Vector2.new(0.5, 0.5)
instance8.Position = UDim2.fromScale(0.5, 0.5)
instance8.Size = UDim2.fromOffset(16, v86[162])
instance8.ZIndex = 100
instance8.BorderSizePixel = 0
instance8.BackgroundColor3 = color
instance8.Parent = frame11
local instance9 = Instance.new(v86[85])
instance9.Color = color
instance9.Thickness = 2
instance9.Parent = instance8
local uiCorner4 = Instance.new("UICorner")
uiCorner4.CornerRadius = UDim.new(v86[63], 0)
uiCorner4.Parent = instance8
local frame12 = Instance.new("Frame")
frame12.Size = UDim2.fromOffset(8, 234)
frame12.BorderSizePixel = 0
frame12.BackgroundColor3 = color
frame12.Visible = arg4.AlphaEnabled
frame12.Parent = frame8
local frame13 = Instance.new("Frame")
frame13.AnchorPoint = Vector2.new(0.5, 0)
frame13.Position = UDim2.fromScale(0.5, 0)
frame13.Size = UDim2.new(v86[186], 28, 1, v86[186])
frame13.BackgroundTransparency = 1
frame13.Active = true
frame13.ZIndex = v86[110]
frame13.Parent = frame12
local uiCorner5 = Instance.new("UICorner")
uiCorner5.CornerRadius = UDim.new(v86[186], 3)
uiCorner5.Parent = frame12
local imageLabel = Instance.new("ImageLabel")
imageLabel.ScaleType = Enum.ScaleType.Tile
imageLabel.Image = "rbxassetid://18274452449"
imageLabel.BackgroundTransparency = v86[63]
imageLabel.Size = UDim2.fromScale(1, 1)
imageLabel.TileSize = UDim2.fromOffset(8, 8)
imageLabel.BorderSizePixel = v86[186]
imageLabel.Parent = frame12
local uiCorner6 = Instance.new("UICorner")
uiCorner6.CornerRadius = UDim.new(0, v86[155])
uiCorner6.Parent = imageLabel
local instance10 = Instance.new(v86[128])
instance10.Size = UDim2.fromScale(1, 1)
instance10.BorderSizePixel = 0
instance10.BackgroundColor3 = arg3.Color
instance10.Parent = frame12
local uiCorner7 = Instance.new("UICorner")
uiCorner7.CornerRadius = UDim.new(v86[186], 3)
uiCorner7.Parent = instance10
local instance11 = Instance.new(v86[46])
instance11.Rotation = 90
instance11.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(v86[63], 0) })
instance11.Parent = instance10
local instance12 = Instance.new(v86[128])
instance12.BackgroundTransparency = v86[63]
instance12.Position = UDim2.fromOffset(0, 4)
instance12.Size = UDim2.new(1, 0, 1, -v86[162])
instance12.ZIndex = 2
instance12.BorderSizePixel = 0
instance12.Parent = frame12
local frame14 = Instance.new("Frame")
frame14.AnchorPoint = Vector2.new(0.5, 0.5)
frame14.Position = UDim2.fromScale(0.5, 0.5)
frame14.Size = UDim2.fromOffset(12, 12)
frame14.ZIndex = 100
frame14.BorderSizePixel = 0
frame14.BackgroundColor3 = color
frame14.Parent = instance12
local uiStroke2 = Instance.new("UIStroke")
uiStroke2.Color = color
uiStroke2.Thickness = 2
uiStroke2.Parent = frame14
local uiCorner8 = Instance.new("UICorner")
uiCorner8.CornerRadius = UDim.new(1, 0)
uiCorner8.Parent = frame14
local frame15 = Instance.new("Frame")
frame15.LayoutOrder = 1
frame15.BackgroundTransparency = 1
frame15.Size = UDim2.new(1, 0, v86[186], v86[159])
frame15.BorderSizePixel = 0
frame15.Parent = root
local textLabel2 = Instance.new("TextLabel")
textLabel2.FontFace = v117.Medium
textLabel2.Text = "Input"
textLabel2.AnchorPoint = Vector2.new(0, v86[101])
textLabel2.BackgroundTransparency = 1
textLabel2.Position = UDim2.fromScale(0, v86[101])
textLabel2.BorderSizePixel = v86[186]
textLabel2.AutomaticSize = Enum.AutomaticSize.XY
textLabel2.TextSize = 16
batch:Bind(textLabel2, "TextColor3", "TextColor")
textLabel2.Parent = frame15
local frame16 = Instance.new("Frame")
frame16.BackgroundTransparency = v86[63]
frame16.Size = UDim2.fromScale(v86[186], 1)
frame16.AutomaticSize = Enum.AutomaticSize.X
frame16.BorderSizePixel = v86[186]
frame16.Parent = frame15
local uiListLayout4 = Instance.new("UIListLayout")
uiListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout4.Parent = frame16
local uiPadding3 = Instance.new("UIPadding")
uiPadding3.PaddingTop = UDim.new(0, 1)
uiPadding3.PaddingLeft = UDim.new(0, v86[63])
uiPadding3.Parent = frame16
local frame17 = Instance.new("Frame")
frame17.AnchorPoint = Vector2.new(1, 0)
frame17.Position = UDim2.new(1, -v86[63], 0, 0)
frame17.BackgroundTransparency = v86[63]
frame17.Size = UDim2.fromScale(0, v86[63])
frame17.AutomaticSize = Enum.AutomaticSize.X
frame17.BorderSizePixel = 0
frame17.Parent = frame15
local uiListLayout5 = Instance.new("UIListLayout")
uiListLayout5.FillDirection = Enum.FillDirection.Horizontal
uiListLayout5.Padding = UDim.new(0, 7)
uiListLayout5.Parent = frame17
local uiPadding4 = Instance.new("UIPadding")
uiPadding4.PaddingTop = UDim.new(0, 1)
uiPadding4.PaddingLeft = UDim.new(0, 1)
uiPadding4.Parent = frame17

local tbl22 = { Repaint = function(...)
end }

local v131 = nil

if arg4.AlphaEnabled then
local v132 = v120.new(arg, { Bare = true })

v132:AttachRight(function(arg6)
local v133, v134 = fn36(arg6, 49, false)
v131 = v134
return v133
end, nil, nil, trove)

v132:Realize(frame17, tbl20, 0)
end

local v132 = nil
local _v133 = nil
local v134 = v120.new(arg, { Bare = true })

v134:AttachRight(function(arg6)
local v135, v136, v137 = fn36(arg6, v86[110], v86[34])
v132 = v136
_v133 = v137
return v135
end, nil, nil, trove)

v134:Realize(frame17, tbl20, 1)

if v131 ~= nil then
local v135 = v131

trove:Connect(v135.FocusLost, function()
local v136 = tonumber
local str7 = v135.Text:gsub("%%", "")
local v137 = v136(str7)

if v137 ~= nil then
arg5.SetAlpha(1 - math.clamp(v137 / 100, 0, 1))
else
tbl22.Repaint(true)
end
end)
end

if v132 ~= nil then
local v135 = v132

trove:Connect(v135.FocusLost, function()
local v136, v137 = v107(Color3.fromHex, v135.Text)

if v136 then
arg5.SetRgb(v137)
end
end)
end

local frame18 = Instance.new("Frame")
frame18.LayoutOrder = v86[56]
frame18.Visible = arg3.Mode == "Gradient"
frame18.BackgroundTransparency = 1
frame18.Size = UDim2.fromScale(v86[63], 0)
frame18.BorderSizePixel = 0
frame18.AutomaticSize = Enum.AutomaticSize.XY
frame18.Parent = root
local frame19 = Instance.new("Frame")
frame19.Active = v86[34]
frame19.Position = UDim2.fromOffset(29, 0)
frame19.Size = UDim2.new(1, -v86[60], 0, v86[144])
frame19.BorderSizePixel = 0
frame19.BackgroundColor3 = color
frame19.Parent = frame18
local instance13 = Instance.new(v86[46])
instance13.Parent = frame19
local uiCorner9 = Instance.new("UICorner")
uiCorner9.CornerRadius = UDim.new(0, 5)
uiCorner9.Parent = frame19
local frame20 = Instance.new("Frame")
frame20.BackgroundTransparency = v86[63]
frame20.Size = UDim2.new(1, 0, 0, 29)
frame20.Position = UDim2.fromOffset(0, -1)
frame20.BorderSizePixel = 0
frame20.ZIndex = 2
frame20.Parent = frame19

local function createTextButton(text, arg6)
local textButton = Instance.new("TextButton")
textButton.Active = v86[34]
textButton.Text = ""
textButton.Size = UDim2.fromOffset(22, 22)
textButton.BorderSizePixel = 0
textButton.AutoButtonColor = false

if arg6 then
textButton.AnchorPoint = Vector2.new(1, 0)
textButton.Position = UDim2.fromScale(1, 0)
end

batch:Bind(textButton, "BackgroundColor3", "Background")
textButton.Parent = frame18
local uiCorner10 = Instance.new("UICorner")
uiCorner10.CornerRadius = UDim.new(0, 5)
uiCorner10.Parent = textButton
local uiStroke3 = Instance.new("UIStroke")
uiStroke3.BorderOffset = UDim.new(v86[186], -v86[63])
uiStroke3.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
batch:Bind(uiStroke3, "Color", v86[120])
uiStroke3.Parent = textButton
local textLabel3 = Instance.new("TextLabel")
textLabel3.FontFace = v117.Medium
textLabel3.TextColor3 = Color3.fromRGB(132, 133, 139)
textLabel3.Text = text
textLabel3.BackgroundTransparency = 1
textLabel3.Size = UDim2.new(1, 1, 1, -2)
textLabel3.BorderSizePixel = v86[186]
textLabel3.TextWrapped = true
textLabel3.TextSize = 22
textLabel3.Parent = textButton
local uiPadding5 = Instance.new("UIPadding")
uiPadding5.PaddingBottom = UDim.new(0, 2)
uiPadding5.PaddingLeft = UDim.new(0, -1)
uiPadding5.PaddingRight = UDim.new(0, v86[63])
uiPadding5.Parent = textLabel3
return textButton
end

local v135 = createTextButton("-", v86[153])
local v136 = createTextButton("+", true)
local imageLabel2 = Instance.new("ImageLabel")
imageLabel2.Active = true
imageLabel2.AnchorPoint = Vector2.new(0.5, 0)
imageLabel2.Image = "rbxassetid://127264563810956"
imageLabel2.BackgroundTransparency = v86[63]
imageLabel2.Position = UDim2.new(0.5, -1, v86[186], -1)
imageLabel2.Size = UDim2.fromOffset(10, 29)
imageLabel2.BorderSizePixel = 0
batch:Bind(imageLabel2, "ImageColor3", "Outline")
imageLabel2.Parent = frame19
local imageLabel3 = Instance.new("ImageLabel")
imageLabel3.Size = UDim2.new(v86[63], -2, 0, 27)
imageLabel3.Image = "rbxassetid://127264563810956"
imageLabel3.BackgroundTransparency = 1
imageLabel3.Position = UDim2.fromOffset(1, 1)
imageLabel3.ZIndex = 2
imageLabel3.BorderSizePixel = 0
imageLabel3.Parent = imageLabel2
local frame21 = Instance.new("Frame")
frame21.Position = UDim2.fromOffset(1, 1)
frame21.Size = UDim2.new(v86[63], -2, 0, v86[71])
frame21.BorderSizePixel = 0
frame21.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
frame21.Parent = imageLabel3
local instance14 = Instance.new(v86[46])
instance14.Rotation = v86[45]
instance14.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, Color3.fromRGB(211, 211, 211)) })
instance14.Parent = frame21
local instance15 = Instance.new(v86[128])
instance15.LayoutOrder = 5
instance15.BackgroundTransparency = 1
instance15.Size = UDim2.new(1, 0, v86[186], 23)
instance15.BorderSizePixel = 0
instance15.Visible = arg4.Animatable
instance15.Parent = root
local textLabel3 = Instance.new("TextLabel")
textLabel3.FontFace = v117.Medium
textLabel3.Text = "Animation"
textLabel3.AnchorPoint = Vector2.new(0, v86[101])
textLabel3.BackgroundTransparency = 1
textLabel3.Position = UDim2.fromScale(v86[186], 0.5)
textLabel3.BorderSizePixel = 0
textLabel3.AutomaticSize = Enum.AutomaticSize.XY
textLabel3.TextSize = v86[13]
batch:Bind(textLabel3, v86[167], v86[174])
textLabel3.Parent = instance15
local frame22 = Instance.new("Frame")
frame22.AnchorPoint = Vector2.new(v86[63], 0)
frame22.Position = UDim2.fromScale(1, 0)
frame22.BackgroundTransparency = 1
frame22.Size = UDim2.fromScale(v86[186], 1)
frame22.AutomaticSize = Enum.AutomaticSize.X
frame22.BorderSizePixel = v86[186]
frame22.Parent = instance15
local uiListLayout6 = Instance.new("UIListLayout")
uiListLayout6.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout6.Parent = frame22
local instance16 = Instance.new(v86[128])
instance16.LayoutOrder = 8
instance16.BackgroundTransparency = 1
instance16.Size = UDim2.fromScale(v86[63], 0)
instance16.AutomaticSize = Enum.AutomaticSize.Y
instance16.BorderSizePixel = v86[186]
instance16.Visible = arg4.Animatable and arg4.AnimationMode == "Breathing"
instance16.Parent = root
local allowBreathing = arg4.AllowBreathing and tbl18 or tbl19
local v137 = v120.new(arg, { Bare = true })

local tbl23 = {
Inline = true,
MaxWidth = 100,
Options = allowBreathing,
Default = arg4.AnimationMode,
OnChanged = function(arg6)
if type(arg6) == "string" then
arg5.SetAnimationMode(arg6)
instance16.Visible = arg4.Animatable and arg6 == "Breathing"
end
end,
}

local v138 = v116._New(arg, v137, trove:Extend(), tbl23)
v137:Realize(frame22, tbl20, 0)
local frame23 = Instance.new("Frame")
frame23.LayoutOrder = 6
frame23.BackgroundTransparency = v86[63]
frame23.Size = UDim2.fromScale(1, v86[186])
frame23.AutomaticSize = Enum.AutomaticSize.Y
frame23.BorderSizePixel = 0
frame23.Visible = arg4.Animatable
frame23.Parent = root
local v139 = v120.new(arg, { Label = "Speed", Height = 24, MediumTitle = true, RightOffset = -1 })

local tbl24 = {
Label = "Speed",
Min = 0,
Max = v86[175],
Step = v86[62],
Default = arg4.AnimationSpeed,
OnChanged = function(arg6)
arg5.SetAnimationSpeed(arg6)
end,
}

local v140 = v121._New(arg, v139, trove:Extend(), tbl24)
v139:Realize(frame23, tbl20, 0)
local n = 100

if arg4.AnimationBreathingMin ~= nil then
n = math.floor((1 - arg4.AnimationBreathingMin) * 100 + 0.5)
end

local n33 = 0

if arg4.AnimationBreathingMax ~= nil then
n33 = math.floor((1 - arg4.AnimationBreathingMax) * v86[91] + 0.5)
end

local v141 = v120.new(arg, { Label = "Alpha Range", Height = 24, MediumTitle = true, RightOffset = -1 })

local tbl25 = {
Label = v86[132],
Min = 0,
Max = 100,
Step = 1,
Default = { Min = n33, Max = n },
OnChanged = function(arg6)
local setAnimationBreathingRange = arg5.SetAnimationBreathingRange

if setAnimationBreathingRange ~= nil then
setAnimationBreathingRange(arg6)
end
end,
}

local v142 = v119._New(arg, v141, trove:Extend(), tbl25)
v141:Realize(instance16, tbl20, 0)
local tbl26 = {}
local v143 = trove:Extend()

local function fn37(arg6)
local n34 = math.clamp((arg6 - frame19.AbsolutePosition.X) / math.max(frame19.AbsoluteSize.X - 1, 1), 0, 1)
local huge = math.huge
local n35 = 1

for k, v144 in arg3.Stops, nil, nil do
local n36 = math.abs(v144.Time - n34)

if n36 < huge then
huge = n36
n35 = k
end
end

return n35
end

local function fn38(arg6)
if arg3.Mode ~= "Gradient" then
return
end

if arg6 then
arg5.SetDragMode(v86[150])
elseif arg3._dragMode == "stop" then
arg5.SetDragMode(nil)
end

tbl22.Repaint(true)
end

local function fn39(arg6)
arg5.MoveActiveStop(math.clamp((arg6.Position.X - frame19.AbsolutePosition.X) / math.max(frame19.AbsoluteSize.X - v86[63], 1), 0, 1))
end

local function fn40()
v143:Destroy()
v143 = trove:Extend()

for _, v144 in tbl26, nil, nil do
v144.Marker:Destroy()
end

table.clear(tbl26)
if arg3.Mode ~= v86[90] then
return
end

for k, v144 in arg3.Stops, nil, nil do
local flag19 = k == arg3.ActiveStopIndex
local imageButton = Instance.new("ImageButton")
imageButton.Active = true
imageButton.AutoButtonColor = false
imageButton.ImageColor3 = v122.get(v86[120])
imageButton.AnchorPoint = Vector2.new(0.5, 0)
imageButton.Image = "rbxassetid://127264563810956"
imageButton.BackgroundTransparency = 1
imageButton.Position = UDim2.new(v144.Time, -v86[63], 0, -v86[63])
imageButton.Size = flag19 and UDim2.fromOffset(10, 29) or UDim2.fromOffset(8, 24)
imageButton.BorderSizePixel = 0
imageButton.Parent = frame20
local imageLabel4 = Instance.new("ImageLabel")
imageLabel4.Size = UDim2.new(v86[63], -2, 1, -v86[56])
imageLabel4.Image = "rbxassetid://127264563810956"
imageLabel4.BackgroundTransparency = 1
imageLabel4.Position = UDim2.fromOffset(v86[63], v86[63])
imageLabel4.BorderSizePixel = 0
imageLabel4.Parent = imageButton
local frame24 = Instance.new("Frame")
frame24.Position = UDim2.fromOffset(1, 1)
frame24.Size = flag19 and UDim2.new(1, -v86[56], 0, 19) or UDim2.new(1, -2, 0, 16)
frame24.BorderSizePixel = v86[186]
frame24.BackgroundColor3 = v144.Value
frame24.Parent = imageLabel4
local uiGradient4 = Instance.new("UIGradient")
uiGradient4.Rotation = 90
local new = ColorSequenceKeypoint.new
local color2 = Color3.fromRGB
uiGradient4.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), new(1, color2(211, 211, 211)) })
uiGradient4.Parent = frame24

if not flag19 then
imageButton.ImageTransparency = v86[62]
end

tbl26[k] = { Marker = imageButton, Accent = frame24 }

v118.connectClick(v143, imageButton, function()
arg5.SelectStop(k)
end)

v118.connectDrag(v143, imageButton, fn39, function(arg6)
if arg6 then
arg5.SelectStop(k)
end

fn38(arg6)
end)
end
end

local function fn41(arg6)
local v144 = arg:DragTweenInfo()

for k, v145 in tbl26, nil, nil do
local v146 = arg3.Stops[k]

if v146 ~= nil then
local imageTransparency = k == arg3.ActiveStopIndex
local udim2 = UDim2.new(v146.Time, -1, 0, -1)
local udim22 = imageTransparency and UDim2.fromOffset(10, 29) or UDim2.fromOffset(v86[162], v86[61])
local udim23 = imageTransparency and UDim2.new(1, -2, 0, 19) or UDim2.new(1, -v86[56], 0, v86[13])
imageTransparency = imageTransparency and 0 or v86[62]

if arg6 then
v145.Marker.Position = udim2
v145.Marker.Size = udim22
v145.Marker.ImageTransparency = imageTransparency
v145.Accent.Size = udim23
v145.Accent.BackgroundColor3 = v146.Value
else
arg:Tween(v145.Marker, { Position = udim2, Size = udim22, ImageTransparency = imageTransparency }, v144)
arg:Tween(v145.Accent, { Size = udim23, BackgroundColor3 = v146.Value }, v144)
end
end
end
end

local function _fn42(arg6)
instance13.Color = v115.toSequence(arg3.Stops)
local v144 = arg3.Stops[arg3.ActiveStopIndex]
local color2 = arg3.Color
local udim2 = UDim2.new(v86[101], -v86[63], 0, -1)

if v144 ~= nil then
color2 = v144.Value
udim2 = UDim2.new(v144.Time, -1, v86[186], -v86[63])
end

frame21.BackgroundColor3 = color2
local udim22 = UDim2.fromOffset(v86[133], v86[123])

if arg3._dragMode == "stop" then
udim22 = UDim2.fromOffset(12, v86[31])
end

if #tbl26 ~= #arg3.Stops then
fn40()
else
fn41(arg6)
end

if arg6 then
imageLabel2.Position = udim2
imageLabel2.Size = udim22
else
arg:Tween(imageLabel2, { Position = udim2, Size = udim22 }, arg:DragTweenInfo())
end
end

v118.connectDrag(trove, frame4, function(arg6)
local n34 = math.max(frame4.AbsoluteSize.X - 1, 1)
local n35 = math.max(frame4.AbsoluteSize.Y - v86[63], 1)
arg5.SetHSVA(arg3.Hue, math.clamp((arg6.Position.X - frame4.AbsolutePosition.X) / n34, v86[186], 1), 1 - math.clamp((arg6.Position.Y - frame4.AbsolutePosition.Y) / n35, 0, v86[63]), arg3.Alpha)
end, function(arg6)
local str7 = nil

if arg6 then
str7 = "sat"
end

arg5.SetDragMode(str7)
end)

v118.connectDrag(trove, frame10, function(arg6)
local v144 = v86[186]
arg5.SetHSVA(math.clamp((arg6.Position.Y - frame9.AbsolutePosition.Y) / math.max(frame9.AbsoluteSize.Y - 1, 1), v144, 1), arg3.Sat, arg3.Val, arg3.Alpha)
end, function(arg6)
local str7 = nil

if arg6 then
str7 = "hue"
end

arg5.SetDragMode(str7)
end)

v118.connectDrag(trove, frame13, function(arg6)
local n34 = math.clamp((arg6.Position.Y - frame12.AbsolutePosition.Y) / math.max(frame12.AbsoluteSize.Y - 1, 1), 0, 1)
arg5.SetHSVA(arg3.Hue, arg3.Sat, arg3.Val, n34)
end, function(arg6)
local str7 = nil

if arg6 then
str7 = "alpha"
end

arg5.SetDragMode(str7)
end)

v118.connectClick(trove, frame19, function()
if arg3.Mode == v86[90] then
arg5.SelectStop(fn37(v123.getPointerPosition().X))
end
end)

v118.connectDrag(trove, frame19, fn39, function(arg6)
if arg3.Mode ~= "Gradient" then
return
end

if arg6 then
arg5.SelectStop(fn37(v123.getPointerPosition().X))
end

fn38(arg6)
if not (n26 >= 4814) then
return
end

-- (anti-tamper freeze trap removed)
end)

v118.connectDrag(trove, imageLabel2, fn39, fn38)

v118.connectClick(trove, v136, function()
arg5.AddStop()
end)

v118.connectClick(trove, v135, function()
arg5.RemoveStop()
end)

local function repaint(snap)
local hueColor = Color3.fromHSV(arg3.Hue, 1, 1)
frame4.BackgroundColor3 = hueColor
frame7.Position = UDim2.new(arg3.Sat, 0, 1 - arg3.Val, 0)
frame7.BackgroundColor3 = arg3.Color
instance8.Position = UDim2.new(0.5, 0, arg3.Hue, 0)
frame14.Position = UDim2.new(0.5, 0, arg3.Alpha, 0)
frame14.BackgroundColor3 = arg3.Color
instance10.BackgroundColor3 = arg3.Color
if arg3.Mode == v86[90] then
_fn42(snap)
else
frame21.BackgroundColor3 = arg3.Color
end
if v132 ~= nil and not v132:IsFocused() then
v132.Text = arg3.Color:ToHex()
end
if v131 ~= nil and not v131:IsFocused() then
v131.Text = tostring(math.floor((1 - arg3.Alpha) * 100 + 0.5))
end
if _v133 ~= nil then
_v133.BackgroundColor3 = arg3.Color
end
end
tbl22.Repaint = repaint

return {
Repaint = repaint,
SyncMode = function(arg6)
frame18.Visible = arg6 == "Gradient"

if v124 ~= nil then
v124:Set(arg6, true)
end
end,
SyncAnimation = function(arg6, arg7)
v138:Set(arg6, true)
v140:Set(arg7, v86[34])
instance16.Visible = arg4.Animatable and arg6 == "Breathing"
end,
SyncAnimationBreathingRange = function(arg6)
v142:Set(arg6, v86[34])
end,
SetAnimationEnabled = function(visible, arg6)
instance15.Visible = visible
frame23.Visible = visible
instance16.Visible = visible and v138.Value == "Breathing"
local v144 = tbl18

if not arg6 then
v144 = tbl19
end

v138:SetOptions(v144)
end,
}
end }
end

tbl17.L = function()
local l = tbl17.cache.L

if not l then
local l2 = { c = fn35() }
tbl17.cache.L = l2
l = l2
end

return l.c
end
end
do -- M
local function fn35()
local v115 = tbl17.g()
tbl17.k()
local v116 = tbl17.L()
local v117 = tbl17.E()
tbl17.r()
local v118 = tbl17.u()
local v119 = tbl17.x()
local v120 = tbl17.G()
tbl17.B()
local color = Color3.fromRGB(255, 255, 255)
local index2 = {}
index2.__index = index2

local function fn36(arg)
return arg.Stops[arg.ActiveStopIndex]
end

local function fn37(arg, arg2)
local flag19 = arg2 == "Gradient" and arg.Gradient ~= "off"
local mode = "Solid"

if flag19 then
mode = "Gradient"
end

arg.Mode = mode

if mode == "Gradient" then
arg.Stops = v117.ensure(arg.Stops, arg.Color)
arg.ActiveStopIndex = math.clamp(arg.ActiveStopIndex, 1, #arg.Stops)
local v121 = fn36(arg)

if v121 ~= nil then
arg.Color = v121.Value
local v122, v123, v124 = v121.Value:ToHSV()
arg.Hue = v122
arg.Sat = v123
arg.Val = v124
end
end

local panel = arg._panel

if panel ~= nil then
panel.SyncMode(mode)
end
end

index2._ApplyState = function(I,W)local N=Color3.fromHSV(I.Hue,I.Sat,I.Val);local P=nil;if I.Mode=="Gradient"then I.Stops= v117 .ensure(I.Stops,N);I.ActiveStopIndex=math.clamp(I.ActiveStopIndex,1,#I.Stops);local a= fn36 (I);if a~=nil then a.Value=N;P=a.Value;else P=N;end;else P=N;end;I.Color=P;N=I._rt;if N~=nil then local a=I.Mode=="Gradient";N.Swatch.BackgroundColor3=if a then  color else P;N.SwatchGradient.Enabled=a;if a then N.SwatchGradient.Color= v117 .toSequence(I.Stops);else N.SwatchGradient.Color=ColorSequence.new(P);end;end;I.Value={Rgb=P,Alpha=I.Alpha,Stops=if I.Mode=="Gradient"then( v117 .clone(I.Stops))else nil};P=I._panel;if P~=nil then P.Repaint(I._dragMode~=nil or I.AnimationMode~="None");end;I.ValueChanged:Fire(I.Value);if not W then I._onChanged(I.Value);I.Changed:Fire(I.Value);end;end

local function fn38(arg, arg2)
local menu = arg._menu

local v121 = v120.new(menu, arg._trove, {
Trigger = arg2,
Size = UDim2.fromOffset(300, 300),
AutomaticSize = Enum.AutomaticSize.Y,
CornerRadius = 13,
FlatBackground = v86[34],
Glow = v86[34],
ParentEntry = arg._parentOverlay,
Place = v120.placeBelow(1, 2),
OnToggle = function(arg3)
if arg3 then
local panel = arg._panel

if panel ~= nil then
panel.Repaint(v86[34])
end
end
end,
})

arg._popup = v121

if v118.Scale ~= 1 then
local uiScale = Instance.new("UIScale")
uiScale.Scale = v118.Scale
uiScale.Parent = v121.Root
end

local v122 = v116.build(menu, v121, arg, {
AlphaEnabled = arg.AlphaEnabled,
Gradient = arg.Gradient,
Animatable = arg.Animatable,
AllowBreathing = arg._allowBreathing,
AnimationMode = arg.AnimationMode,
AnimationSpeed = arg.AnimationSpeed,
AnimationBreathingMin = arg.AnimationBreathingRange and arg.AnimationBreathingRange.Min,
AnimationBreathingMax = arg.AnimationBreathingRange and arg.AnimationBreathingRange.Max,
}, {
SetHSVA = function(hue, sat, val, alpha)
arg.Hue = hue
arg.Sat = sat
arg.Val = val
arg.Alpha = alpha
arg:_ApplyState(false)
end,
SetDragMode = function(dragMode)
arg._dragMode = dragMode
arg.Dragging = dragMode ~= nil
end,
SelectStop = function(arg3)
if arg.Mode ~= "Gradient" or #arg.Stops == 0 then
return
end
arg.ActiveStopIndex = math.clamp(arg3, v86[63], #arg.Stops)
local v122 = fn36(arg)

if v122 ~= nil then
arg.Color = v122.Value
local v123 = arg
local v124 = arg
local v125 = arg
local v126, v127, v128 = v122.Value:ToHSV()
v123.Hue = v126
v124.Sat = v127
v125.Val = v128
end

arg:_ApplyState(true)
end,
MoveActiveStop = function(arg3)
local v122 = fn36(arg)
if arg.Mode ~= "Gradient" or v122 == nil or arg.ActiveStopIndex == 1 or arg.ActiveStopIndex == #arg.Stops then
return
end
v122.Time = math.clamp(arg3, 0, 1)
arg.ActiveStopIndex = v117.sort(arg.Stops, v122)
arg:_ApplyState(false)
end,
AddStop = function()
if arg.Mode ~= "Gradient" then
fn37(arg, "Gradient")
end

local v122 = fn36(arg)
local n = 0.5

if v122 ~= nil then
if arg.ActiveStopIndex < #arg.Stops then
n = (v122.Time + arg.Stops[arg.ActiveStopIndex + 1].Time) * 0.5
elseif arg.ActiveStopIndex > 1 then
n = (arg.Stops[arg.ActiveStopIndex - 1].Time + v122.Time) * v86[101]
end
end

local tbl18 = { Time = n, Value = arg.Color }
table.insert(arg.Stops, tbl18)
arg.ActiveStopIndex = v117.sort(arg.Stops, tbl18)
arg:_ApplyState(false)
end,
RemoveStop = function()
if arg.Mode ~= "Gradient" or #arg.Stops <= v86[56] then
return
end
local activeStopIndex = arg.ActiveStopIndex
if activeStopIndex == 1 or activeStopIndex == #arg.Stops then
return
end
local time = arg.Stops[activeStopIndex].Time
table.remove(arg.Stops, activeStopIndex)
local huge = math.huge
local v122 = nil
local activeStopIndex2 = 1

for k, v123 in arg.Stops, v122, nil do
local n = math.abs(v123.Time - time)

if n < huge then
huge = n
activeStopIndex2 = k
end
end

arg.ActiveStopIndex = activeStopIndex2
arg._dragMode = nil
arg.Dragging = v86[153]
arg:_ApplyState(false)
end,
SetMode = function(arg3)
fn37(arg, arg3)
arg:_ApplyState(false)
end,
SetAlpha = function(arg3)
arg.Alpha = math.clamp(arg3, 0, 1)
arg:_ApplyState(v86[153])
end,
SetRgb = function(arg3)
arg:Set({ Rgb = arg3, Alpha = arg.Alpha, Stops = arg.Value.Stops }, false)
end,
SetAnimationMode = function(arg3)
arg:SetAnimationMode(arg3)
end,
SetAnimationSpeed = function(arg3)
arg:SetAnimationSpeed(arg3)
end,
SetAnimationBreathingRange = function(arg3)
arg:SetAnimationBreathingRange(arg3)
end,
})

arg._panel = v122
v122.Repaint(true)
end

local function createTextButton(arg, parent, arg2)
local textButton = Instance.new("TextButton")
textButton.AnchorPoint = Vector2.new(1, 0.5)
textButton.Position = UDim2.fromScale(1, 0.5)
textButton.Size = UDim2.fromOffset(v86[32], v86[32])
textButton.BorderSizePixel = 0
textButton.BackgroundColor3 = arg.Color
textButton.Text = ""
textButton.AutoButtonColor = false
textButton.Parent = parent
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], v86[175])
uiCorner.Parent = textButton
local uiGradient = Instance.new("UIGradient")
uiGradient.Enabled = arg.Mode == "Gradient"

if arg.Mode == "Gradient" then
uiGradient.Color = v117.toSequence(arg.Stops)
else
uiGradient.Color = ColorSequence.new(arg.Color)
end

uiGradient.Parent = textButton
arg._rt = { Swatch = textButton, SwatchGradient = uiGradient }
arg._parentOverlay = arg2.ParentOverlay

v119.connectClick(arg2.Trove, textButton, function()
if arg._panel == nil then
fn38(arg, textButton)
end

local popup = arg._popup

if popup ~= nil then
popup:Toggle()
end
end)

return textButton
end

index2._New = function(arg, arg2, arg3, arg4)
local gradient = arg4.Gradient or "off"
local default = arg4.Default
local n = v86[63]
local rgb = color
local stops = nil

if default ~= nil then
rgb = color

if default.Rgb ~= nil then
rgb = default.Rgb
end

if default.Alpha ~= nil then
n = math.clamp(default.Alpha, 0, 1)
end

stops = default.Stops
end

local str7 = "Solid"

if gradient ~= "off" then
if gradient == "only" or stops ~= nil and #stops > v86[186] then
str7 = "Gradient"
end
end

local v121 = v117.ensure(stops, rgb)
local v122, v123, v124 = rgb:ToHSV()

local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "ColorPicker",
Row = arg2,
AlphaEnabled = arg4.Alpha == true,
Gradient = gradient,
Mode = str7,
Hue = v122,
Sat = v123,
Val = v124,
Alpha = n,
Color = rgb,
Stops = v121,
ActiveStopIndex = 1,
Dragging = false,
_dragMode = nil,
Animatable = arg4.Animatable == true,
AnimationMode = "None",
AnimationSpeed = 1,
AnimationBreathingRange = nil,
Value = { Rgb = rgb, Alpha = n, Stops = str7 == "Gradient" and v117.clone(v121) or nil },
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
AnimationChanged = arg3:Add(v115.new()),
AnimationSpeedChanged = arg3:Add(v115.new()),
AnimationBreathingRangeChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_allowBreathing = arg4.Alpha == true,
_rt = nil,
_panel = nil,
_popup = nil,
_parentOverlay = nil,
}, index2)

arg2:AttachRight(function(arg5, arg6)
return createTextButton(obj, arg5, arg6)
end, 18, nil, arg3)

return obj
end

index2.Set = function(arg, arg2, arg3)
local rgb = arg2.Rgb or arg.Color
local alpha = arg.Alpha

if arg2.Alpha ~= nil then
alpha = math.clamp(arg2.Alpha, 0, v86[63])
end

local stops = arg2.Stops
local mode = arg.Mode

if arg.Gradient == v86[172] then
stops = nil
mode = "Solid"
elseif stops ~= nil then
if v86[186] < #stops then
mode = "Gradient"
else
mode = "Solid"
end
end

local hue, v121, v122 = rgb:ToHSV()

if mode == "Gradient" then
local ensure = v117.ensure
stops = stops or arg.Stops
arg.Stops = ensure(stops, rgb)
arg.ActiveStopIndex = math.clamp(arg.ActiveStopIndex, 1, #arg.Stops)
local v123 = fn36(arg)

if v123 ~= nil then
v123.Value = rgb
end
elseif stops ~= nil and #stops > 0 then
arg.Stops = v117.ensure(stops, rgb)
end

local flag19 = arg._dragMode == "sat" or arg._dragMode == v86[164]

if not flag19 then
flag19 = not (v122 > 0 and v121 > 0)
end

if flag19 then
hue = arg.Hue
end

fn37(arg, mode)
arg.Hue = hue
arg.Sat = v121
arg.Val = v122
arg.Alpha = alpha
arg:_ApplyState(arg3)
end

index2.EnableAnimation = function(arg, allowBreathing)
arg.Animatable = v86[34]
arg._allowBreathing = allowBreathing
local panel = arg._panel

if panel ~= nil then
panel.SetAnimationEnabled(true, allowBreathing)
end

return arg
end

index2.SetAnimationMode = function(arg, animationMode, arg2)
if arg.AnimationMode ~= animationMode then
arg.AnimationMode = animationMode
local panel = arg._panel

if panel ~= nil then
panel.SyncAnimation(animationMode, arg.AnimationSpeed)
end

if not arg2 then
arg.AnimationChanged:Fire(animationMode)
end
end

return arg
end

index2.SetAnimationSpeed = function(arg, animationSpeed, arg2)
if arg.AnimationSpeed ~= animationSpeed then
arg.AnimationSpeed = animationSpeed
local panel = arg._panel

if panel ~= nil then
panel.SyncAnimation(arg.AnimationMode, animationSpeed)
end

if not arg2 then
arg.AnimationSpeedChanged:Fire(animationSpeed)
end
end

return arg
end

index2.SetAnimationBreathingRange = function(arg, animationBreathingRange, arg2)
arg.AnimationBreathingRange = animationBreathingRange
local panel = arg._panel

if panel ~= nil then
panel.SyncAnimationBreathingRange(animationBreathingRange)
end

if not arg2 then
arg.AnimationBreathingRangeChanged:Fire(animationBreathingRange)
end

return arg
end

index2.SetOpen = function(arg, arg2)
local popup = arg._popup

if popup == nil then
local rt = arg._rt
if rt == nil then
return
end
fn38(arg, rt.Swatch)
popup = arg._popup
end

if popup ~= nil then
popup:SetOpen(arg2)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.M = function()
local m = tbl17.cache.M

if not m then
m = { c = fn35() }
tbl17.cache.M = m
end

return m.c
end
end
do -- N
local function fn35()local I= tbl17 .D(); tbl17 .M(); tbl17 .r();local l={bind=function(W,N)local P=false;local function a()if P or W.Dragging then return;end;local e=N.Read();if e~=nil then W:Set(e,true);end;end;W:OnChanged(function(e)P=true;N.Write(e);P=false;end);for P,P_25 in N.Changed,nil,nil do W:Connect(P_25,a);end;a();return W;end};local function W(N,P)if N.GetBase~=nil then return N:GetBase(P);end;return N:Get(P);end;l.bindConfig=function(N,P,a)local e,c,E=a.Config,a.Transparency,a.Gradient=="editable"or a.Gradient=="only";a={P:Changed(e)};if c~=nil then table.insert(a,P:Changed(c));end;return l.bind(N,{Read=function()local N,p=W(P,e),if c~=nil then(W(P,c))else nil;if E then return I.decodeSequence(N,p);end;return I.decodeSolid(N,p);end,Write=function(W)local N;if E then local E;E,N=I.encodeSequence(W);P:Set(e,E);else local E;E,N=I.encodeSolid(W);P:Set(e,E);end;if c~=nil then P:Set(c,N);end;end,Changed=a});end;return l;end

tbl17.N = function()
local n = tbl17.cache.N

if not n then
local n33 = { c = fn35() }
tbl17.cache.N = n33
n = n33
end

return n.c
end
end
do -- Q
local function fn35()
tbl17.g()
tbl17.k()
tbl17.r()
local v115 = tbl17.s()
tbl17.B()
local index2 = {}
index2.__index = index2

local function createFrame(arg, parent, arg2)
local frame = Instance.new("Frame")
frame.BackgroundTransparency = v86[63]
frame.Size = UDim2.new(1, 0, 0, 16)
frame.BorderSizePixel = v86[186]
frame.Parent = parent
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
uiListLayout.Padding = UDim.new(v86[186], v86[186])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame

local function fn36(layoutOrder)
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = v86[195]
frame2.BorderSizePixel = 0
frame2.Size = UDim2.fromOffset(0, v86[63])
frame2.LayoutOrder = layoutOrder
arg2.Batch:Bind(frame2, v86[5], "TextColor")
frame2.Parent = frame
local uiFlexItem = Instance.new("UIFlexItem")
uiFlexItem.FlexMode = Enum.UIFlexMode.Fill
uiFlexItem.Parent = frame2
end

fn36(0)
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.Size = UDim2.fromScale(0, 1)
textLabel.AutomaticSize = Enum.AutomaticSize.X
textLabel.FontFace = v115.SemiBold
textLabel.Text = arg.Label:upper()
textLabel.TextSize = 12
textLabel.TextXAlignment = Enum.TextXAlignment.Center
textLabel.LayoutOrder = v86[63]
textLabel.Visible = arg.Label ~= ""
arg2.Batch:Bind(textLabel, "TextColor3", "TextColor")
textLabel.Parent = frame
local instance = Instance.new(v86[113])
instance.PaddingLeft = UDim.new(0, v86[162])
instance.PaddingRight = UDim.new(0, 8)
instance.Parent = textLabel
fn36(2)
arg._rt = { Object = frame, Label = textLabel }
return frame
end

index2._New = function(arg, arg2, arg3, arg4)
local obj = setmetatable({ _trove = arg3, _menu = arg, Kind = "Divider", Row = arg2, Label = arg4.Label or "", _rt = nil }, index2)

arg2:AttachRight(function(arg5, arg6)
return createFrame(obj, arg5, arg6)
end, nil, nil, arg3)

return obj
end

index2.SetLabel = function(arg, label)
arg.Label = label
local rt = arg._rt

if rt ~= nil then
rt.Label.Text = label:upper()
rt.Label.Visible = label ~= ""
end

return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.Q = function()
local q = tbl17.cache.Q

if not q then
local q2 = { c = fn35() }
tbl17.cache.Q = q2
q = q2
end

return q.c
end
end
do -- R
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.x()
tbl17.B()
local v118 = tbl17.A()
local index2 = {}
index2.__index = index2

local function fn36(arg)
if arg.Default ~= nil then
return arg.Default
end
local v119 = arg.Options[1]
return (v119 ~= nil and { v119.Name } or { "" })[1]
end

local function fn37(arg, parent, arg2, arg3)
local instance = Instance.new(v86[128])
instance.BackgroundTransparency = v86[63]
instance.BorderSizePixel = 0
instance.Size = UDim2.new(1, 0, 0, arg3)
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, v86[54])
uiListLayout.Parent = instance
local n = arg3 - 12 - v86[155] - 10 - 3
local n33 = #arg._options

for k, v119 in arg._options, nil, nil do
local imageButton = Instance.new("ImageButton")
imageButton.BackgroundTransparency = 1
imageButton.BorderSizePixel = 0
imageButton.AutoButtonColor = false
imageButton.Image = ""
imageButton.LayoutOrder = k
imageButton.Size = UDim2.new(v86[63] / n33, -v86[54], 1, 0)
imageButton.Parent = instance
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Position = UDim2.fromScale(0.5, 0)
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Size = UDim2.new(1, -20, 1, -10)
frame.Parent = imageButton
local uiListLayout2 = Instance.new("UIListLayout")
uiListLayout2.FillDirection = Enum.FillDirection.Vertical
uiListLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListLayout2.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout2.Padding = UDim.new(0, 3)
uiListLayout2.Parent = frame
local imageLabel = Instance.new("ImageLabel")
imageLabel.BackgroundTransparency = 1
imageLabel.BorderSizePixel = 0
imageLabel.LayoutOrder = 1
imageLabel.ScaleType = Enum.ScaleType.Fit
imageLabel.Size = UDim2.new(1, 0, 0, n)
imageLabel.Image = v119.Icon
imageLabel.Parent = frame
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = v86[63]
textLabel.BorderSizePixel = 0
textLabel.FontFace = v116.SemiBold
textLabel.LayoutOrder = v86[56]
textLabel.Size = UDim2.new(1, 0, 0, 14)
textLabel.Text = v119.Name
textLabel.TextSize = 12
textLabel.TextTruncate = Enum.TextTruncate.AtEnd
textLabel.Parent = frame
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = v86[63]
frame2.BorderSizePixel = 0
frame2.Position = UDim2.new(0, 0, 1, -3)
frame2.Size = UDim2.new(v86[63], 0, 0, 10)
arg2.Batch:Bind(frame2, "BackgroundColor3", "Accent")
frame2.Parent = imageButton
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 3)
uiCorner.Parent = frame2
arg._cells[k] = { Icon = imageLabel, Label = textLabel, Accent = frame2, Name = v119.Name }

v117.connectClick(arg2.Trove, imageButton, function()
arg:Set(v119.Name)
end)
end

arg2.Batch:BindStateful(v86[174], function()
arg:_Refresh()
end)

arg2.Batch:BindStateful(v86[96], function()
arg:_Refresh()
end)

arg:_Refresh()
instance.Parent = parent
return instance
end

index2._New = function(arg, arg2, arg3, arg4)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
_options = arg4.Options,
_cells = {},
Kind = "IconStrip",
Row = arg2,
Value = fn36(arg4),
ValueChanged = arg3:Add(v115.new()),
}, index2)

local height = arg4.Height or 62

arg2:AttachRight(function(arg5, arg6)
return fn37(obj, arg5, arg6, height)
end, nil, nil, arg3)

if arg4.OnChanged ~= nil then
arg3:Add(obj.ValueChanged:Connect(arg4.OnChanged))
end

return obj
end

index2._Refresh = function(arg)
local v119 = v118.get(v86[174])
local Unselected = v118.get("Unselected")

for _, v120 in arg._cells, nil, nil do
local backgroundTransparency = 1
local v121

if v120.Name ~= arg.Value then
v121 = Unselected
else
backgroundTransparency = v86[186]
v121 = v119
end

v120.Icon.ImageColor3 = v121
v120.Label.TextColor3 = v121
v120.Accent.BackgroundTransparency = backgroundTransparency
end
end

index2.Set = function(arg, value, arg2)
if value == arg.Value then
return
end
local flag19 = v86[153]

for _, v119 in arg._options, nil, nil do
if v119.Name == value then
flag19 = true
break
end
end

if not flag19 then
return
end
arg.Value = value
arg:_Refresh()

if not arg2 then
arg.ValueChanged:Fire(value)
end
end

index2.Get = function(arg)
return arg.Value
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Add(arg2:Connect(arg3))
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.R = function()
local r = tbl17.cache.R

if not r then
r = { c = fn35() }
tbl17.cache.R = r
end

return r.c
end
end
do -- S
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.x()
tbl17.B()
local v117 = tbl17.A()
local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local color = Color3.fromRGB(255, 255, v86[108])

local function fn36(arg, arg2)
return Color3.new(arg.R * arg2, arg.G * arg2, arg.B * arg2)
end

local index2 = {}
index2.__index = index2

local function fn37(arg, arg2, arg3, arg4)
local backgroundTransparency = v86[63]
local ToggleCircleUnselected = v117.get("ToggleCircleUnselected")
local udim2 = UDim2.fromOffset(v86[155], 2)

if arg3 then
udim2 = UDim2.fromOffset(13, v86[56])
backgroundTransparency = 0
ToggleCircleUnselected = color
end

if arg4 then
arg2.Fill.BackgroundTransparency = backgroundTransparency
arg2.Circle.BackgroundColor3 = ToggleCircleUnselected
arg2.Circle.Position = udim2
return
end

arg._menu:Tween(arg2.Fill, { BackgroundTransparency = backgroundTransparency })
arg._menu:Tween(arg2.Circle, { BackgroundColor3 = ToggleCircleUnselected, Position = udim2 })
end

local function fn38(arg, parent, arg2)
local instance = Instance.new(v86[128])
instance.AnchorPoint = Vector2.new(1, v86[101])
instance.Position = UDim2.fromScale(1, v86[101])
instance.Size = UDim2.fromOffset(32, 20)
instance.BorderSizePixel = 0
instance.BackgroundColor3 = color
instance.Parent = parent
local instance2 = Instance.new(v86[46])
instance2.Rotation = 90
arg2.Batch:BindGradient(instance2, { "ToggleBackgroundUnselected", "GradientDark" })
instance2.Parent = instance
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)
uiCorner.Parent = instance
local instance3 = Instance.new(v86[128])
instance3.Size = UDim2.fromScale(1, 1)
instance3.BorderSizePixel = 0
instance3.BackgroundColor3 = v117.get("Accent")
instance3.BackgroundTransparency = v86[63]
instance3.Parent = instance
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(1, v86[186])
uiCorner2.Parent = instance3
local frame = Instance.new("Frame")
frame.Position = UDim2.fromOffset(v86[155], 2)
frame.Size = UDim2.fromOffset(16, 16)
frame.BorderSizePixel = v86[186]
frame.BackgroundColor3 = v117.get("ToggleCircleUnselected")
frame.Parent = instance
local uiCorner3 = Instance.new("UICorner")
uiCorner3.CornerRadius = UDim.new(1, v86[186])
uiCorner3.Parent = frame
local rt = { Fill = instance3, Circle = frame }
arg._rt = rt
local frame2 = arg.Row.Frame

if frame2 ~= nil then
v116.connectClick(arg2.Trove, frame2, function()
arg:Set(not arg.Value)
end)

v116.connectPress(arg2.Trove, frame2, function()
if arg.Value then
local v118 = v86[105]
arg._menu:Tween(instance3, { BackgroundColor3 = fn36(v117.get("Accent"), v118) }, tweenInfo)
end
end, function()
if arg.Value then
arg._menu:Tween(instance3, { BackgroundColor3 = v117.get(v86[139]) }, tweenInfo)
end
end)
end

arg2.Trove:Connect(arg._menu.AccentChanged, function(arg3)
arg._menu:Tween(instance3, { BackgroundColor3 = arg3 })
end)

arg2.Batch:BindStateful("ToggleCircleUnselected", function(backgroundColor3)
if not arg.Value then
frame.BackgroundColor3 = backgroundColor3
end
end)

arg2.Trove:Connect(arg.ValueChanged, function(arg3)
fn37(arg, rt, arg3, v86[153])
end)

fn37(arg, rt, arg.Value, true)
return instance
end

index2._New = function(arg, arg2, arg3, arg4)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "Toggle",
Row = arg2,
Value = arg4.Default == true,
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_rt = nil,
}, index2)

arg2:AttachRight(function(arg5, arg6)
return fn38(obj, arg5, arg6)
end, 32, nil, arg3)

return obj
end

index2.Set = function(arg, value, arg2)
local v118 = v86[116]
if type(value) ~= v118 or value == arg.Value then
return
end
arg.Value = value
arg.ValueChanged:Fire(value)

if not arg2 then
arg._onChanged(value)
arg.Changed:Fire(value)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.S = function()
local s = tbl17.cache.S

if not s then
local s2 = { c = fn35() }
tbl17.cache.S = s2
s = s2
end

return s.c
end
end
do -- T
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.H()
local v117 = tbl17.s()
local v118 = tbl17.u()
local v119 = tbl17.x()
local v120 = tbl17.G()
local v121 = tbl17.B()
local v122 = tbl17.A()
local v123 = tbl17.S()
local v124 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36(arg)
if typeof(arg) == "EnumItem" then
local v125 = v124.KeyNames[arg]
if type(v125) == "string" then
return v125
end
return arg.Name
end

if type(arg) == "string" then
return arg
end
return "None"
end

local function fn37(arg)
local panel = arg._panel

if panel ~= nil then
panel.KeyValue.Text = "Key: " .. fn36(arg.Value.Key)
end
end

local function fn38(arg)
local active = arg.Active or arg.Value.Mode == v86[21]
local featureEnabled = arg.ShowInList and arg.FeatureEnabled
local hud = arg._hud

if hud ~= nil then
hud:SetKeyText(fn36(arg.Value.Key))
hud:SetMode(arg.Value.Mode)
hud:SetActiveAppearance(active)
hud:SetEnabled(featureEnabled)
end

local mobile = arg._mobile

if mobile ~= nil then
mobile:SetMode(arg.Value.Mode)
mobile:SetActive(active)
mobile:SetVisible(featureEnabled)
end
end

local function createTextLabel(arg, parent, arg2)
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = v86[63]
textButton.Size = UDim2.new(1, 0, 0, 20)
textButton.BorderSizePixel = 0
textButton.AutomaticSize = Enum.AutomaticSize.Y
textButton.Text = ""
textButton.AutoButtonColor = false
textButton.LayoutOrder = 0
textButton.Parent = parent
local textLabel = Instance.new("TextLabel")
textLabel.FontFace = v117.Medium
textLabel.Text = "Keybind"
textLabel.AnchorPoint = Vector2.new(0, 0.5)
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.fromScale(0, v86[101])
textLabel.BorderSizePixel = v86[186]
textLabel.AutomaticSize = Enum.AutomaticSize.XY
textLabel.TextSize = 16
arg2.Batch:Bind(textLabel, v86[167], "TextColor")
textLabel.Parent = textButton
local textButton2 = Instance.new("TextButton")
textButton2.AnchorPoint = Vector2.new(1, v86[186])
textButton2.Position = UDim2.new(1, v86[186], 0, 1)
textButton2.Size = UDim2.fromOffset(2, v86[61])
textButton2.BorderSizePixel = v86[186]
textButton2.AutomaticSize = Enum.AutomaticSize.X
textButton2.Text = ""
textButton2.AutoButtonColor = v86[153]
arg2.Batch:Bind(textButton2, "BackgroundColor3", "Background")
textButton2.Parent = textButton
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = textButton2
local uiStroke = Instance.new("UIStroke")
uiStroke.BorderOffset = UDim.new(v86[186], -v86[63])
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = textButton2
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.Padding = UDim.new(v86[186], 10)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = textButton2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, -1)
uiPadding.PaddingLeft = UDim.new(0, 5)
uiPadding.PaddingRight = UDim.new(v86[186], 5)
uiPadding.Parent = textButton2
local textLabel2 = Instance.new("TextLabel")
textLabel2.FontFace = v117.Medium
textLabel2.TextColor3 = v122.get("TextColor")
textLabel2.Text = ""
textLabel2.AnchorPoint = Vector2.new(0, 0.5)
textLabel2.BackgroundTransparency = 1
textLabel2.Position = UDim2.new(0, 5, v86[101], 0)
textLabel2.BorderSizePixel = 0
textLabel2.AutomaticSize = Enum.AutomaticSize.XY
textLabel2.TextSize = 16
textLabel2.Parent = textButton2
local instance = Instance.new(v86[113])
instance.PaddingBottom = UDim.new(0, v86[56])
instance.Parent = textLabel2

v119.connectClick(arg2.Trove, textButton2, function()
arg:StartCapture()
end)

return textLabel2
end

local function fn39(arg)
local panel = arg._panel
if panel ~= nil then
return panel
end
local rt = arg._rt
if rt == nil then
return nil
end
local menu = arg._menu
local gear = rt.Gear
local n = v86[17]

if v118.IsMobile() then
n = 240
end

local v125 = v120.new(menu, arg._trove, {
Trigger = gear,
Size = UDim2.fromOffset(n, 0),
ParentEntry = arg._parentOverlay,
Place = v120.placeBelow(2, 2),
OnToggle = function(arg2)
local n33 = v86[186]

if arg2 then
n33 = 180
end

menu:Tween(gear, { Rotation = n33 })

if arg2 then
local panel2 = arg._panel

if panel2 ~= nil then
panel2.Scroll.CanvasPosition = Vector2.zero
end
end
end,
})

local v126, v127 = v125:AttachScrollingList(n)
local v128 = v125:RealizeCtx()
local v129 = createTextLabel(arg, v127, v128)
local v130 = v121.new(menu, { Label = v86[97], Height = v86[9] })

local tbl18 = {
Label = "Show in list",
Default = arg.ShowInList,
OnChanged = function(arg2)
arg:SetShowInList(arg2)
end,
}

local v131 = v123._New(menu, v130, arg._trove:Extend(), tbl18)
v130:Realize(v127, v128, 2)
local v132 = nil

if v118.WantsMobileButtons() then
local v133 = v121.new(menu, { Label = v86[112], Height = 20 })

local tbl19 = {
Label = v86[112],
Default = arg.Invisible,
OnChanged = function(arg2)
arg:SetInvisible(arg2)
end,
}

v132 = v123._New(menu, v133, arg._trove:Extend(), tbl19)
v133:Realize(v127, v128, v86[155])
end

local v133 = v121.new(menu, { Label = v86[55], Height = 24 })

local tbl19 = {
Label = "Mode",
Options = arg.Modes,
Default = arg.Value.Mode,
OnChanged = function(arg2)
local v134 = v86[165]

if type(arg2) == v134 then
arg:Set({ Key = arg.Value.Key, Mode = arg2 })
end
end,
}

local v134 = v116._New(menu, v133, arg._trove:Extend(), tbl19)
v133:Realize(v127, v128, v86[26])

local panel2 = {
Popup = v125,
Scroll = v126,
KeyValue = v129,
ShowToggle = v131,
InvisibleToggle = v132,
ModeDropdown = v134,
}

arg._panel = panel2
fn37(arg)
return panel2
end

local function createImageButton(arg, parent, arg2)
local imageButton = Instance.new("ImageButton")
imageButton.Image = "rbxassetid://127083575814915"
imageButton.BackgroundTransparency = 1
imageButton.AnchorPoint = Vector2.new(1, 0.5)
imageButton.Position = UDim2.fromScale(1, 0.5)
imageButton.Size = UDim2.fromOffset(16, 16)
imageButton.BorderSizePixel = 0
imageButton.AutoButtonColor = false
arg2.Batch:Bind(imageButton, "ImageColor3", "TextColor")
imageButton.Parent = parent
arg._rt = { Gear = imageButton }
arg._parentOverlay = arg2.ParentOverlay

v119.connectClick(arg2.Trove, imageButton, function()
local v125 = fn39(arg)

if v125 ~= nil then
v125.Popup:Toggle()
end
end)

return imageButton
end

index2._New = function(arg, arg2, arg3, arg4)
local default = arg4.Default
local str7 = "Toggle"
local key = nil

if default ~= nil then
key = default.Key

if default.Mode ~= nil then
str7 = default.Mode
end
end

local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = v86[73],
Row = arg2,
Modes = arg4.Modes or { "Hold", "Toggle", "Always" },
Value = { Key = key, Mode = str7 },
Active = false,
FeatureEnabled = false,
ShowInList = arg4.InKeybindList == true,
Invisible = v86[153],
ListLabel = arg4.ListLabel or arg4.Label or "Keybind",
Capturing = v86[153],
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
ActiveChanged = arg3:Add(v115.new()),
ShowInListChanged = arg3:Add(v115.new()),
InvisibleChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_cancelCapture = nil,
_rt = nil,
_panel = nil,
_parentOverlay = nil,
_hud = nil,
_mobile = nil,
}, index2)

local v125 = arg:AddKeybindHudEntry()

if v125 ~= nil then
obj._hud = v125
v125:SetLabel(obj.ListLabel)
arg3:Add(v125)
end

local v126 = arg:RegisterMobileButton(arg4.RegistrationKey or obj.ListLabel, obj.ListLabel, obj.Value.Mode, function(arg5)
obj:SetActive(arg5)
end)

if v126 ~= nil then
obj._mobile = v126
arg3:Add(v126)
end

fn38(obj)

arg2:AttachRight(function(arg5, arg6)
return createImageButton(obj, arg5, arg6)
end, v86[13], nil, arg3)

return obj
end

index2._BindConfigMap = function(arg, arg2, arg3)
local flag19 = false

local function fn40(arg4, arg5, arg6, arg7)
if arg4 == nil then
return
end

local function fn41(arg8)
if arg8 == nil then
return
end
flag19 = v86[34]
arg7(arg8)
flag19 = v86[153]
end

fn41(arg2:Get(arg4))

arg._trove:Connect(arg5, function()
if flag19 then
return
end
arg2:Set(arg4, arg6())
end)

arg._trove:Connect(arg2:Changed(arg4, v86[34]), function(arg8)
if flag19 or arg8 == arg6() then
return
end
fn41(arg8)
end)
end

fn40(arg3.Key, arg.Changed, function()
local key = arg.Value.Key
if key == nil then
return v86[75]
end
return key
end, function(arg4)
if typeof(arg4) == "EnumItem" then
arg:SetKey(arg4)
elseif type(arg4) == "string" then
local v125 = arg
local setKey = v125.SetKey
local v126 = v124.deserializeKey(arg4)
setKey(v125, v126)
end
end)

fn40(arg3.Mode, arg.Changed, function()
return arg.Value.Mode
end, function(arg4)
if type(arg4) == "string" then
arg:SetMode(arg4)
end
end)

fn40(arg3.Active, arg.ActiveChanged, function()
return arg.Active
end, function(arg4)
arg:SetActive(arg4 == v86[34])
end)

fn40(arg3.ShowInList, arg.ShowInListChanged, function()
return arg.ShowInList
end, function(arg4)
arg:SetShowInList(arg4 == v86[34])
end)

fn40(arg3.Invisible, arg.InvisibleChanged, function()
return arg.Invisible
end, function(arg4)
arg:SetInvisible(arg4 == true)
end)
end

index2.StartCapture = function(arg)
local panel = arg._panel
if panel == nil then
return
end
arg.Capturing = v86[34]
panel.KeyValue.Text = "Key: ..."
arg._menu:Tween(panel.KeyValue, { TextColor3 = v122.get("Accent") })

arg._cancelCapture = arg._menu:CaptureKey(function(arg2)
arg.Capturing = false
arg._cancelCapture = nil
arg._menu:Tween(panel.KeyValue, { TextColor3 = v122.get("TextColor") })
if arg2 == nil then
fn37(arg)
return
end
arg:Set({ Key = arg2, Mode = arg.Value.Mode })
end)
end

index2.Set = function(arg, arg2, arg3)
local key = arg2.Key
local mode = arg2.Mode or arg.Value.Mode
if key == arg.Value.Key and mode == arg.Value.Mode then
return
end
arg.Value = { Key = key, Mode = mode }
fn37(arg)
fn38(arg)
local panel = arg._panel

if panel ~= nil then
panel.ModeDropdown:Set(mode, true)
end

arg.ValueChanged:Fire(arg.Value)

if not arg3 then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

index2.SetKey = function(arg, arg2, arg3)
arg:Set({ Key = arg2, Mode = arg.Value.Mode }, arg3)
end

index2.SetMode = function(arg, arg2, arg3)
arg:Set({ Key = arg.Value.Key, Mode = arg2 }, arg3)
end

index2.SetActive = function(arg, active, arg2)
if arg.Active == active then
return
end
arg.Active = active
fn38(arg)
arg.ActiveChanged:Fire(active)

if not arg2 then
arg.Changed:Fire(arg.Value)
end
end

index2.SetFeatureEnabled = function(arg, featureEnabled)
if arg.FeatureEnabled == featureEnabled then
return
end
arg.FeatureEnabled = featureEnabled
fn38(arg)
end

index2.SetShowInList = function(arg, arg2, arg3)
local showInList = arg2 == true
if arg.ShowInList == showInList then
return
end
arg.ShowInList = showInList
fn38(arg)
local panel = arg._panel

if panel ~= nil then
panel.ShowToggle:Set(showInList, true)
end

if not arg3 then
arg.ShowInListChanged:Fire(showInList)
end
end

index2.SetInvisible = function(arg, arg2, arg3)
local invisible = arg2 == true
if arg.Invisible == invisible then
return
end
arg.Invisible = invisible
local mobile = arg._mobile

if mobile ~= nil then
mobile:SetInvisible(invisible)
end

local panel = arg._panel

if panel ~= nil then
local invisibleToggle = panel.InvisibleToggle

if invisibleToggle ~= nil then
invisibleToggle:Set(invisible, v86[34])
end
end

if not arg3 then
arg.InvisibleChanged:Fire(invisible)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
local cancelCapture = arg._cancelCapture

if cancelCapture ~= nil then
cancelCapture()
end

arg._trove:Destroy()
end

return index2
end

tbl17.T = function()
local t = tbl17.cache.T

if not t then
t = { c = fn35() }
tbl17.cache.T = t
end

return t.c
end
end
do -- U
local function fn35()
tbl17.g()
tbl17.k()
tbl17.r()
local v115 = tbl17.s()
tbl17.B()
local index2 = {}
index2.__index = index2

local function createTextButton(arg, parent, arg2)
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.new(1, 0, 0, v86[61])
textButton.BorderSizePixel = 0
textButton.AutomaticSize = Enum.AutomaticSize.Y
textButton.Text = ""
textButton.AutoButtonColor = false
textButton.Parent = parent
local textLabel = Instance.new("TextLabel")
textLabel.RichText = v86[34]
textLabel.FontFace = v115.Medium
textLabel.Text = arg.Label
textLabel.AnchorPoint = Vector2.new(v86[186], 0.5)
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.fromScale(v86[186], 0.5)
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.Y
textLabel.Size = UDim2.fromScale(1, 0)
textLabel.TextWrapped = v86[34]
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextSize = arg._textSize or 16

if arg._textColor ~= nil then
textLabel.TextColor3 = arg._textColor
else
arg2.Batch:Bind(textLabel, "TextColor3", "TextColor")
end

textLabel.Parent = textButton
arg._label = textLabel
return textButton
end

index2._New = function(arg, arg2, arg3, arg4)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "Label",
Row = arg2,
Label = arg4.Label or "",
_textColor = arg4.TextColor,
_textSize = arg4.TextSize,
_label = nil,
}, index2)

arg2:AttachRight(function(arg5, arg6)
return createTextButton(obj, arg5, arg6)
end, nil, nil, arg3)

return obj
end

index2.SetLabel = function(arg, label)
arg.Label = label
local label2 = arg._label

if label2 ~= nil then
label2.Text = label
end

return arg
end

index2.SetColor = function(arg, textColor)
local v116 = v86[115]
if typeof(textColor) ~= v116 then
return arg
end
arg._textColor = textColor
local label = arg._label

if label ~= nil then
label.TextColor3 = textColor
end

return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.U = function()
local u = tbl17.cache.U

if not u then
u = { c = fn35() }
tbl17.cache.U = u
end

return u.c
end
end
do -- V
local function fn35()
local v115 = tbl17.g()
tbl17.k()
local v116 = tbl17.F()
tbl17.r()
local v117 = tbl17.x()
tbl17.B()
local v118 = tbl17.A()
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2)
local value = arg.Value
if type(value) == "table" then
return table.find(value, arg2) ~= nil
end
return value == arg2
end

local function fn37(arg, arg2, arg3, arg4)
local Unselected = v118.get("Unselected")
local imageTransparency = v86[63]
local n = v86[175]

if arg3 then
Unselected = v118.get("TextColor")
n = 29
imageTransparency = 0
end

arg2.Tick.ImageColor3 = v118.get(v86[174])
local udim = UDim.new(v86[186], n)

if arg4 then
arg2.Title.TextColor3 = Unselected
arg2.Tick.ImageTransparency = imageTransparency
arg2.Padding.PaddingLeft = udim
return
end

arg._menu:Tween(arg2.Title, { TextColor3 = Unselected })
arg._menu:Tween(arg2.Tick, { ImageTransparency = imageTransparency })
arg._menu:Tween(arg2.Padding, { PaddingLeft = udim })
end

local function fn38(arg, arg2)
local rt = arg._rt
if rt == nil then
return
end

for k, v119 in rt.Rows, nil, nil do
local v120 = arg.Options[k]
fn37(arg, v119, v120 ~= nil and fn36(arg, v120), arg2)
end
end

local function fn39(arg, arg2)
local rt = arg._rt
if rt == nil then
return
end
local str7 = arg2:lower()

for _, v119 in rt.Rows, nil, nil do
v119.Title.Visible = v119.Title.Text:lower():find(str7, 1, true) ~= nil
end
end

local function fn40(arg, arg2)
local v119 = arg.Options[arg2]
if v119 == nil then
return
end

if not arg.Multi then
arg:Set(v119)
return
end
local tbl18 = {}
local v120 = v86[68]

if type(arg.Value) == v120 then
tbl18 = table.clone(arg.Value)
end

local v121 = table.find(tbl18, v119)

if v121 ~= nil then
table.remove(tbl18, v121)
else
table.insert(tbl18, v119)
end

arg:Set(tbl18)
end

local function fn41(arg, arg2, layoutOrder)
local instance = Instance.new(v86[135])
instance.BackgroundTransparency = v86[63]
instance.TextColor3 = v118.get("Unselected")
instance.Text = ""
instance.Size = UDim2.fromScale(1, 0)
instance.ClipsDescendants = true
instance.TextXAlignment = Enum.TextXAlignment.Left
instance.BorderSizePixel = 0
instance.AutomaticSize = Enum.AutomaticSize.XY
instance.TextSize = 16
instance.FontFace = arg._menu.Fonts.Main
instance.LayoutOrder = layoutOrder
instance.Parent = arg2.Scroll
local instance2 = Instance.new(v86[113])
instance2.PaddingTop = UDim.new(0, 5)
instance2.PaddingBottom = UDim.new(0, 5)
instance2.PaddingRight = UDim.new(0, 5)
instance2.PaddingLeft = UDim.new(0, 5)
instance2.Parent = instance
local imageLabel = Instance.new("ImageLabel")
imageLabel.ImageTransparency = v86[63]
imageLabel.Image = "rbxassetid://73347151382921"
imageLabel.ImageColor3 = v118.get(v86[174])
imageLabel.BackgroundTransparency = v86[63]
imageLabel.AnchorPoint = Vector2.new(0, 0.5)
imageLabel.Position = UDim2.new(0, -22, v86[101], v86[186])
imageLabel.Size = UDim2.fromOffset(14, 14)
imageLabel.BorderSizePixel = v86[186]
imageLabel.Parent = instance

v117.connectClick(arg._trove, instance, function()
fn40(arg, layoutOrder)
end)

return { Title = instance, Padding = instance2, Tick = imageLabel }
end

local function fn42(arg)
local rt = arg._rt
if rt == nil then
return
end
local rows = rt.Rows
local options = arg.Options

for k, v119 in options, nil, nil do
local v120 = rows[k]

if v120 == nil then
v120 = fn41(arg, rt, k)
rows[k] = v120
end

if v120.Title.Text ~= v119 then
v120.Title.Text = v119
end

if not v120.Title.Visible then
v120.Title.Visible = true
end
end

for i = #rows, #options + 1, -1 do
rows[i].Title:Destroy()
rows[i] = nil
end
end

local function fn43(arg, arg2, arg3)
local menu = arg._menu
local instance = Instance.new(v86[128])
instance.LayoutOrder = -1
instance.Size = UDim2.fromOffset(v86[157], v86[144])
instance.ClipsDescendants = true
instance.BorderSizePixel = 0
arg3.Batch:Bind(instance, "BackgroundColor3", "Background")
instance.Parent = arg2.Root
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = instance
local uiStroke = Instance.new("UIStroke")
arg3.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = instance
local textBox = Instance.new("TextBox")
textBox.PlaceholderText = v86[190]
textBox.PlaceholderColor3 = v118.get("Unselected")
textBox.FontFace = menu.Fonts.Main
textBox.Text = ""
textBox.AnchorPoint = Vector2.new(v86[186], 0.5)
textBox.Position = UDim2.new(0, v86[54], 0.5, 0)
textBox.Size = UDim2.new(1, -12, 1, v86[186])
textBox.BackgroundTransparency = 1
textBox.BorderSizePixel = 0
textBox.TextSize = 14
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = v86[34]
textBox.Active = true
arg3.Batch:Bind(textBox, "TextColor3", "TextColor")
textBox.Parent = instance
arg2.SearchInput = textBox

arg3.Trove:Connect(textBox:GetPropertyChangedSignal(v86[80]), function()
fn39(arg, textBox.Text)
end)
end

local function fn44(arg, parent, arg2)
local instance = Instance.new(v86[92])
instance.BackgroundTransparency = v86[63]
instance.Size = UDim2.new(1, 0, v86[186], 24)
instance.BorderSizePixel = 0
instance.AutomaticSize = Enum.AutomaticSize.Y
instance.Text = ""
instance.AutoButtonColor = false
instance.Parent = parent
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(v86[186], v86[13])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = instance
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.ScrollBarImageTransparency = 1
scrollingFrame.ScrollBarThickness = v86[186]
scrollingFrame.Selectable = false
scrollingFrame.Size = UDim2.new(1, 0, 0, arg.Height)
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(v86[108], 255, 255)
scrollingFrame.BorderSizePixel = 0
arg2.Batch:Bind(scrollingFrame, "ScrollBarImageColor3", "Accent")
scrollingFrame.Parent = instance
local instance2 = Instance.new(v86[46])
instance2.Rotation = v86[45]
v116.bindSurfaceGradient(arg2.Batch, instance2, { v86[187], "GradientDark" })
instance2.Parent = scrollingFrame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = scrollingFrame
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, "Color", v86[120])
uiStroke.Parent = scrollingFrame
local uiListLayout2 = Instance.new("UIListLayout")
uiListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout2.Parent = scrollingFrame
local rt = { Root = instance, Scroll = scrollingFrame, SearchInput = nil, Rows = {} }
arg._rt = rt

if arg.Search then
fn43(arg, rt, arg2)
end

fn42(arg)
fn38(arg, v86[34])
return instance
end

local function fn45(arg, arg2)
local tbl18 = {}

for _, v119 in arg, nil, nil do
if table.find(arg2, v119) ~= nil then
table.insert(tbl18, v119)
end
end

return tbl18
end

local function fn46(arg, arg2)
if #arg ~= #arg2 then
return false
end

for k, v119 in arg, nil, nil do
if arg2[k] ~= v119 then
return false
end
end

return true
end

local function fn47(arg, arg2, arg3, arg4, arg5, arg6, arg7)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "List",
Row = arg2,
Multi = arg5,
Search = arg4.Search == true,
Height = arg4.Height or v86[110],
Options = table.clone(arg4.Options or {}),
Value = arg6,
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg7,
_rt = nil,
}, index2)

arg2:AttachRight(function(arg8, arg9)
return fn44(obj, arg8, arg9)
end, nil, nil, arg3)

return obj
end

index2._New = function(arg, arg2, arg3, arg4)
local options = arg4.Options or {}
local default = arg4.Default

if not (default ~= nil and table.find(options, default) ~= nil) then
default = nil

if arg4.SelectFirst ~= false then
default = options[1]
end
end

local onChanged = arg4.OnChanged

local function fn48()
end

if onChanged ~= nil then
fn48 = function(arg5)
onChanged(arg5)
end
end

return (fn47(arg, arg2, arg3, arg4, false, default, fn48))
end

index2._NewMulti = function(arg, arg2, arg3, arg4)
local v119 = fn45(arg4.Options or {}, arg4.Default or {})
local onChanged = arg4.OnChanged

local function fn48()
end

if onChanged ~= nil then
fn48 = function(arg5)
onChanged(arg5)
end
end

return (fn47(arg, arg2, arg3, arg4, v86[34], v119, fn48))
end

index2.Set = function(arg, value, arg2)
local flag19 = arg2 == v86[34]

if arg.Multi then
local tbl18 = {}

if type(value) ~= "table" then
local v119 = v86[165]

if type(value) ~= v119 then
value = tbl18
else
value = { value }
end
end

arg.Value = fn45(arg.Options, value)
else
local flag20 = type(value) == "string" and table.find(arg.Options, value) ~= nil
local v119 = nil

if not flag20 then
value = v119
end

arg.Value = value
end

fn38(arg, flag19)
arg.ValueChanged:Fire(arg.Value)

if not arg2 then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

index2.SetOptions = function(arg, arg2)
local value = arg.Value
arg.Options = table.clone(arg2 or {})
fn42(arg)
arg:Set(value, true)
local flag19 = value ~= arg.Value
local multi = arg.Multi

if multi then
local v119 = v86[68]
multi = type(value) == v119
end

if multi and type(arg.Value) == "table" then
flag19 = not fn46(value, arg.Value)
end

if flag19 then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

index2.Add = function(arg, arg2)
if type(arg2) ~= "string" or table.find(arg.Options, arg2) ~= nil then
return
end
local v119 = table.clone(arg.Options)
table.insert(v119, arg2)
arg:SetOptions(v119)
end

index2.Remove = function(arg, arg2)
local v119 = table.find(arg.Options, arg2)
if v119 == nil then
return
end
local v120 = table.clone(arg.Options)
table.remove(v120, v119)
arg:SetOptions(v120)
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.V = function()
local v115 = tbl17.cache.V

if not v115 then
local v116 = { c = fn35() }
tbl17.cache.V = v116
v115 = v116
end

return v115.c
end
end
do -- W
local function fn35()
local v115 = tbl17.F()
local v116 = tbl17.v()
tbl17.A()

return {
nextLayoutOrder = function(arg)
local n = 0

for _, v117 in arg:GetChildren() do
if v117:IsA("GuiObject") then
n += v86[63]
end
end

return n
end,
box = function(arg, parent)
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 0
frame.Size = UDim2.fromScale(1, 0)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BackgroundColor3 = Color3.fromRGB(255, v86[108], 255)
frame.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v115.bindSurfaceGradient(arg, uiGradient, { "GradientMid", v86[70] })
uiGradient.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = frame
local instance = Instance.new(v86[85])
arg:Bind(instance, v86[27], "Outline")
instance.Parent = frame
return frame
end,
elementsContainer = function(parent, position, size)
local section = v116.get().Section
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Position = position or UDim2.fromOffset(section.InnerPadding, section.InnerPadding)
frame.Size = size or UDim2.new(v86[63], -section.InnerPadding * v86[56], v86[186], 0)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Parent = parent
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(v86[186], section.ElementGap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, section.InnerPadding)
uiPadding.Parent = frame
return frame
end,
}
end

tbl17.W = function()
local w = tbl17.cache.W

if not w then
w = { c = fn35() }
tbl17.cache.W = w
end

return w.c
end
end
do -- X
local function fn35()
tbl17.g()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
tbl17.B()
local v118 = tbl17.W()
local v119 = tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2, arg3, arg4)
return setmetatable({
_trove = arg2:Extend(),
_menu = arg,
_resolveParent = arg4,
Sections = arg3,
_activeIndex = 1,
_realized = false,
_ctx = nil,
_tabs = {},
_rootFrame = nil,
}, index2)
end

local function fn36(arg, parent, arg2, layoutOrder)
local section = v117.get().Section
local frame = Instance.new("Frame")
frame.LayoutOrder = layoutOrder or v118.nextLayoutOrder(parent)
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, 0)
frame.BorderSizePixel = v86[186]
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Parent = parent
arg._rootFrame = frame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 3)
uiPadding.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[54])
uiCorner.Parent = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, section.TitleGap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame
local v120 = v118.box(arg2, frame)
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = 0
frame2.ClipsDescendants = true
frame2.Size = UDim2.new(1, 0, 0, section.MultiHeaderHeight)
frame2.BorderSizePixel = v86[186]
frame2.BackgroundColor3 = Color3.fromRGB(v86[108], v86[108], 255)
frame2.Parent = v120
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(0, 6)
uiCorner2.Parent = frame2
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v115.bindSurfaceGradient(arg2, uiGradient, { "GradientTop", "GradientMid" })
uiGradient.Parent = frame2
local frame3 = Instance.new("Frame")
frame3.Position = UDim2.new(0, v86[186], 1, -1)
frame3.Size = UDim2.new(1, v86[186], 0, 1)
frame3.BorderSizePixel = 0
arg2:Bind(frame3, "BackgroundColor3", "Outline")
frame3.Parent = frame2
local instance = Instance.new(v86[128])
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = 0
instance.Parent = frame2
local uiListLayout2 = Instance.new("UIListLayout")
uiListLayout2.Padding = UDim.new(v86[186], section.MultiHeaderGap)
uiListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout2.FillDirection = Enum.FillDirection.Horizontal
uiListLayout2.Parent = instance
local uiPadding2 = Instance.new("UIPadding")
uiPadding2.PaddingRight = UDim.new(0, section.MultiHeaderPadding)
uiPadding2.PaddingLeft = UDim.new(v86[186], section.MultiHeaderPadding)
uiPadding2.Parent = instance
return v120, instance
end

local function fn37(arg, layoutOrder, arg2, parent, arg3)
local section = v117.get().Section
local udim2 = UDim2.new
local n = -section.InnerPadding * v86[56]
local v120 = v118.elementsContainer(arg2, UDim2.fromOffset(section.InnerPadding, section.MultiPaneTop), udim2(1, n, 0, 0))
v120.Visible = false
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.fromScale(0, 1)
textButton.BorderSizePixel = v86[186]
textButton.AutomaticSize = Enum.AutomaticSize.X
textButton.Text = ""
textButton.AutoButtonColor = false
textButton.LayoutOrder = layoutOrder
textButton.Parent = parent
local textLabel = Instance.new("TextLabel")
textLabel.FontFace = v116.SemiBold
textLabel.Text = arg.Sections[layoutOrder].Title
textLabel.TextColor3 = v119.get("Unselected")
textLabel.AnchorPoint = Vector2.new(0, 0.5)
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.fromScale(v86[186], v86[101])
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.X
textLabel.Size = UDim2.fromOffset(0, section.MultiTabTextSize + 5)
textLabel.TextSize = section.MultiTabTextSize
textLabel.Parent = textButton
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Position = UDim2.new(0, 0, v86[63], -v86[155])
frame.Size = UDim2.new(1, 0, 0, 10)
frame.BorderSizePixel = 0
arg3.Batch:Bind(frame, v86[5], v86[139])
frame.Parent = textButton
local instance = Instance.new(v86[98])
instance.CornerRadius = UDim.new(0, 3)
instance.Parent = frame

arg3.Trove:Connect(textButton.MouseButton1Click, function()
arg:_SetActive(layoutOrder)
end)

return { Label = textLabel, Accent = frame, Pane = v120 }
end

index2.Realize = function(arg, arg2)
if arg._realized then
return
end
arg._realized = true
local v120 = arg._trove:Extend()
local v121 = v119.newBatch(v120)
local ctx = { Menu = arg._menu, Trove = v120, Batch = v121 }
arg._ctx = ctx
local v122, v123 = fn36(arg, arg._resolveParent(), v121, arg2)

for k in arg.Sections, nil, nil do
arg._tabs[k] = fn37(arg, k, v122, v123, ctx)
end

v121:BindStateful("TextColor", function(textColor3)
local v124 = arg._tabs[arg._activeIndex]

if v124 ~= nil then
v124.Label.TextColor3 = textColor3
end
end)

v121:BindStateful("Unselected", function(textColor3)
for k, v124 in arg._tabs, nil, nil do
if k ~= arg._activeIndex then
v124.Label.TextColor3 = textColor3
end
end
end)

local v124 = arg._tabs[arg._activeIndex]

if v124 ~= nil then
v124.Label.TextColor3 = v119.get("TextColor")
v124.Accent.BackgroundTransparency = 0
v124.Pane.Visible = true
arg.Sections[arg._activeIndex]:_RealizeAsPane(v124.Pane, ctx)
end
end

index2._SetActive = function(arg, activeIndex)
if activeIndex == arg._activeIndex or arg._tabs[activeIndex] == nil then
return
end
local menu = arg._menu
local v120 = arg._tabs[arg._activeIndex]

if v120 ~= nil then
menu:Tween(v120.Label, { TextColor3 = v119.get(v86[96]) })
menu:Tween(v120.Accent, { BackgroundTransparency = 1 })
v120.Pane.Visible = false
arg.Sections[arg._activeIndex].Opened:Fire(v86[153])
end

arg._activeIndex = activeIndex
local v121 = arg._tabs[activeIndex]
local ctx = arg._ctx

if ctx ~= nil then
arg.Sections[activeIndex]:_RealizeAsPane(v121.Pane, ctx)
end

menu:Tween(v121.Label, { TextColor3 = v119.get("TextColor") })
menu:Tween(v121.Accent, { BackgroundTransparency = 0 })
v121.Pane.Visible = v86[34]
arg.Sections[activeIndex].Opened:Fire(true)
end

index2.SelectPane = function(arg, arg2)
if not arg._realized then
arg:Realize()
end

arg:_SetActive(arg2)
end

index2._SetGridParent = function(arg, parent, layoutOrder)
local rootFrame = arg._rootFrame
if rootFrame == nil then
return
end
rootFrame.LayoutOrder = layoutOrder
rootFrame.Parent = parent
end

index2.SetVisible = function(arg, visible)
local rootFrame = arg._rootFrame

if rootFrame ~= nil then
rootFrame.Visible = visible
end
end

index2.Destroy = function(arg)
local rootFrame = arg._rootFrame

if rootFrame ~= nil then
rootFrame:Destroy()
arg._rootFrame = nil

if n26 >= 4826 then
-- (anti-tamper freeze trap removed)
end
end

arg._trove:Destroy()
end

return index2
end

tbl17.X = function()
local x = tbl17.cache.X

if not x then
x = { c = fn35() }
tbl17.cache.X = x
end

return x.c
end
end
do -- Y
local function fn35()
local v115 = tbl17.g()
tbl17.k()
local v116 = tbl17.F()
tbl17.r()
local v117 = tbl17.s()
local v118 = tbl17.v()
local v119 = tbl17.x()
tbl17.B()
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2)
local tbl18 = {}

for _, v120 in arg2, nil, nil do
if type(v120) == "string" and table.find(arg, v120) ~= nil and table.find(tbl18, v120) == nil then
table.insert(tbl18, v120)
end
end

for _, v120 in arg, nil, nil do
if table.find(tbl18, v120) == nil then
table.insert(tbl18, v120)
end
end

return tbl18
end

local function fn37(arg, arg2, arg3)
local v120 = table.find(arg, arg2)
if v120 == nil then
return false
end
local n = math.clamp(v120 + arg3, 1, #arg)
if n == v120 then
return false
end
table.remove(arg, v120)
table.insert(arg, n, arg2)
return v86[34]
end

local function fn38(arg)
local rt = arg._rt
if rt == nil then
return
end

for k, v120 in rt.Rows, nil, nil do
local layoutOrder = table.find(arg.Order, k) or 0
local autoButtonColor = layoutOrder > v86[63]
local autoButtonColor2 = layoutOrder > v86[186] and layoutOrder < #arg.Order
v120.Object.LayoutOrder = layoutOrder
v120.Index.Text = tostring(layoutOrder)
v120.Up.AutoButtonColor = autoButtonColor
v120.Down.AutoButtonColor = autoButtonColor2
local textTransparency = 0.6

if autoButtonColor then
textTransparency = 0
end

local textTransparency2 = v86[84]

if autoButtonColor2 then
textTransparency2 = 0
end

v120.Up.TextTransparency = textTransparency
v120.Down.TextTransparency = textTransparency2
end
end

local function fn39(arg, arg2)
arg.Value = table.clone(arg.Order)
arg.ValueChanged:Fire(arg.Value)

if not arg2 then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

local function fn40(arg, text, parent, arg2)
local menu = arg._menu
local v120 = v118.get()
local listRowHeight = v120.Row.ListRowHeight
local n = -v86[58]
local isCompact = v120.IsCompact
local n33 = -28
local textSize = 12
local n34 = 22

if isCompact then
n = -v86[53]
n33 = -42
textSize = 14
n34 = 30
end

local frame = Instance.new("Frame")
frame.BackgroundTransparency = 0.5
frame.Size = UDim2.new(1, 0, v86[186], listRowHeight)
frame.BorderSizePixel = v86[186]
arg2.Batch:Bind(frame, "BackgroundColor3", "ElementBackground")
frame.Parent = parent
local instance = Instance.new(v86[98])
instance.CornerRadius = UDim.new(0, v86[26])
instance.Parent = frame
local instance2 = Instance.new(v86[135])
instance2.BackgroundTransparency = 1
instance2.Position = UDim2.fromOffset(8, 0)
instance2.Size = UDim2.new(v86[186], 18, 1, v86[186])
instance2.Text = ""
instance2.TextSize = v86[118]
instance2.TextXAlignment = Enum.TextXAlignment.Left
instance2.FontFace = v117.Medium
arg2.Batch:Bind(instance2, "TextColor3", v86[96])
instance2.Parent = frame
local instance3 = Instance.new(v86[135])
instance3.BackgroundTransparency = 1
instance3.Position = UDim2.fromOffset(30, 0)
instance3.Size = UDim2.new(1, n, 1, 0)
instance3.Text = text
instance3.TextSize = v86[72]
instance3.TextXAlignment = Enum.TextXAlignment.Left
instance3.FontFace = v117.Medium
instance3.TextTruncate = Enum.TextTruncate.AtEnd
arg2.Batch:Bind(instance3, "TextColor3", v86[174])
instance3.Parent = frame
local textButton = Instance.new("TextButton")
textButton.AnchorPoint = Vector2.new(1, 0.5)
textButton.Position = UDim2.new(1, n33, 0.5, 0)
textButton.Size = UDim2.fromOffset(n34, n34)
textButton.BackgroundTransparency = 1
textButton.BorderSizePixel = 0
textButton.Text = "▲"
textButton.TextSize = textSize
textButton.AutoButtonColor = false
textButton.FontFace = menu.Fonts.Main
arg2.Batch:Bind(textButton, v86[167], "TextColor")
textButton.Parent = frame
local textButton2 = Instance.new("TextButton")
textButton2.AnchorPoint = Vector2.new(v86[63], 0.5)
textButton2.Position = UDim2.new(1, -4, 0.5, 0)
textButton2.Size = UDim2.fromOffset(n34, n34)
textButton2.BackgroundTransparency = 1
textButton2.BorderSizePixel = 0
textButton2.Text = "▼"
textButton2.TextSize = textSize
textButton2.AutoButtonColor = v86[153]
textButton2.FontFace = menu.Fonts.Main
arg2.Batch:Bind(textButton2, "TextColor3", "TextColor")
textButton2.Parent = frame

v119.connectClick(arg2.Trove, textButton, function()
if fn37(arg.Order, text, -v86[63]) then
fn38(arg)
fn39(arg)
end
end)

v119.connectClick(arg2.Trove, textButton2, function()
if fn37(arg.Order, text, 1) then
fn38(arg)
fn39(arg)
end
end)

return { Object = frame, Up = textButton, Down = textButton2, Index = instance2 }
end

local function createFrame(arg, parent, arg2)
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, v86[186])
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Parent = parent
local instance = Instance.new(v86[128])
instance.BackgroundColor3 = Color3.fromRGB(v86[108], v86[108], 255)
instance.Size = UDim2.fromScale(1, 0)
instance.AutomaticSize = Enum.AutomaticSize.Y
instance.BorderSizePixel = 0
instance.Parent = frame
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v116.bindSurfaceGradient(arg2.Batch, uiGradient, { "GradientMid", v86[70] })
uiGradient.Parent = instance
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = instance
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = instance
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(v86[186], 1)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = instance
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 4)
uiPadding.PaddingBottom = UDim.new(0, v86[26])
uiPadding.PaddingLeft = UDim.new(v86[186], 4)
uiPadding.PaddingRight = UDim.new(0, v86[26])
uiPadding.Parent = instance
local rt = { Root = frame, Rows = {} }
arg._rt = rt

for _, v120 in arg.Items, nil, nil do
rt.Rows[v120] = fn40(arg, v120, instance, arg2)
end

fn38(arg)
return frame
end

index2._New = function(arg, arg2, arg3, arg4)
local tbl18 = {}

for _, v120 in arg4.Items, nil, nil do
if type(v120) == "string" then
table.insert(tbl18, v120)
end
end

local v120

if arg4.Default ~= nil then
v120 = fn36(tbl18, arg4.Default)
else
v120 = table.clone(tbl18)
end

local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "OrderedList",
Row = arg2,
Items = tbl18,
Order = v120,
Value = table.clone(v120),
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_rt = nil,
}, index2)

arg2:AttachRight(function(arg5, arg6)
return createFrame(obj, arg5, arg6)
end, nil, nil, arg3)

return obj
end

index2.Set = function(arg, arg2, arg3)
if type(arg2) ~= "table" then
return
end
arg.Order = fn36(arg.Items, arg2)
fn38(arg)
fn39(arg, arg3)
end

index2.SetItems = function(arg, arg2)
local items = {}

for _, v120 in arg2, nil, nil do
if type(v120) == "string" then
table.insert(items, v120)
end
end

arg.Items = items
arg.Order = fn36(items, arg.Order)
arg.Value = table.clone(arg.Order)
return arg
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.Y = function()
local y = tbl17.cache.Y

if not y then
local y2 = { c = fn35() }
tbl17.cache.Y = y2
y = y2
end

return y.c
end
end
do -- Z
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.x()
tbl17.B()
local v118 = tbl17.A()
local v119 = tbl17.w()
local color = Color3.fromRGB(v86[119], 159, 159)
local udim2 = UDim2.fromOffset(153, 150)
local udim22 = UDim2.fromOffset(5, 16)
local index2 = {}
index2.__index = index2

local function fn36(arg)
return arg.Title or arg.Name
end

local function fn37(arg, arg2, selected, arg3)
arg2.Selected = selected
local item = arg2.Item
local defaultAccentPosition = arg2.DefaultAccentPosition
local defaultImageSize = arg2.DefaultImageSize
local selectedPreviewColor, n, n33, n34

if selected then
selectedPreviewColor = item.SelectedPreviewColor or v118.get("TabButtonSelected")
defaultAccentPosition = UDim2.new(0.5, 0, 1, -2)
defaultImageSize = UDim2.new(arg2.DefaultImageSize.X.Scale, arg2.DefaultImageSize.X.Offset + 6, arg2.DefaultImageSize.Y.Scale, arg2.DefaultImageSize.Y.Offset + 6)
n = 0
n33 = 0.94
n34 = 0
else
selectedPreviewColor = arg2.DefaultPreviewColor
n = 1
n33 = 1
n34 = 0.08
end

selected = selected and arg2.TitleColor or v118.get("Unselected")

local function fn38(arg4, arg5)
if arg3 then
for k, v120 in arg5, nil, nil do
arg4[k] = v120
end
else
arg._menu:Tween(arg4, arg5)
end
end

fn38(arg2.Card, { BackgroundColor3 = selectedPreviewColor })
fn38(arg2.Title, { TextColor3 = selected })
fn38(arg2.Accent, { Position = defaultAccentPosition, BackgroundTransparency = n34 })
fn38(arg2.SelectIndicator, { BackgroundTransparency = n })
fn38(arg2.SelectIndicatorIcon, { TextTransparency = n })
fn38(arg2.SelectIndicatorStroke, { Transparency = n })
fn38(arg2.Image, { Size = defaultImageSize })
fn38(arg2.Button, { BackgroundTransparency = n33 })
end

local function fn38(arg, arg2)
local visible = arg2 == nil or arg2(arg.Item, arg.SearchKey)

if arg.Object.Visible ~= visible then
arg.Object.Visible = visible
end
end

local function fn39(arg)
if arg == v86[89] then
return "Loading catalog", v86[111]
end

if arg == "Unavailable" then
return v86[69], "The catalog could not be loaded."
end

if arg == "Empty" then
return "No items available", "This catalog does not have any items yet."
end

if arg == "NoMatches" then
return "No matches", v86[177]
end
return "", ""
end

local function fn40(arg)
local rt = arg._rt
if rt == nil then
return
end
local visible = arg.State == "Ready"
rt.Holder.Visible = visible
rt.StateRoot.Visible = not visible
local v120, v121 = fn39(arg.State)
rt.StateTitle.Text = v120
rt.StateMessage.Text = arg._stateMessage or v121
rt.ClearFilter.Visible = arg.State == "NoMatches" and arg._onClearFilter ~= nil
rt.UpdateHeight()
end

local function fn41(arg, arg2, parent, arg3, arg4)
local v120 = fn36(arg2)
local previewColor = arg2.PreviewColor or v118.get(v86[178])
local titleColor = arg2.TitleColor or v118.get("TextColor")
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Size = UDim2.fromOffset(100, 100)
frame.LayoutOrder = arg2.LayoutOrder or 0
frame.Visible = false
frame.Parent = parent
local instance = Instance.new(v86[4])
instance.HorizontalAlignment = Enum.HorizontalAlignment.Center
instance.VerticalAlignment = Enum.VerticalAlignment.Center
instance.HorizontalFlex = Enum.UIFlexAlignment.Fill
instance.VerticalFlex = Enum.UIFlexAlignment.Fill
instance.Padding = UDim.new(0, 16)
instance.SortOrder = Enum.SortOrder.LayoutOrder
instance.ItemLineAlignment = Enum.ItemLineAlignment.Center
instance.Parent = frame
local instance2 = Instance.new(v86[128])
instance2.BackgroundColor3 = previewColor
instance2.BorderSizePixel = v86[186]
instance2.AnchorPoint = Vector2.new(v86[101], 0.5)
instance2.Position = UDim2.fromScale(v86[101], 0.5)
instance2.Size = UDim2.fromScale(1, 1)
instance2.ClipsDescendants = true
instance2.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[54])
uiCorner.Parent = instance2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 10)
uiPadding.PaddingRight = UDim.new(0, 10)
uiPadding.PaddingLeft = UDim.new(0, 10)
uiPadding.PaddingBottom = UDim.new(0, v86[133])
uiPadding.Parent = instance2
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = v86[63]
textButton.BorderSizePixel = 0
textButton.Size = UDim2.fromScale(1, 1)
textButton.Text = ""
textButton.ZIndex = 5
textButton.AutoButtonColor = v86[153]
textButton.Parent = instance2
local instance3 = Instance.new(v86[98])
instance3.CornerRadius = UDim.new(0, v86[54])
instance3.Parent = textButton
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = 1
frame2.BorderSizePixel = 0
frame2.AnchorPoint = Vector2.new(0.5, 0.5)
frame2.Position = UDim2.fromScale(0.5, 0.5)
frame2.AutomaticSize = Enum.AutomaticSize.XY
frame2.Parent = instance2
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.ItemLineAlignment = Enum.ItemLineAlignment.Center
uiListLayout.Parent = frame2
local imageLabel = Instance.new("ImageLabel")
imageLabel.BackgroundTransparency = 1
imageLabel.BorderSizePixel = v86[186]
imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
imageLabel.Position = UDim2.fromScale(0.5, 0.5)
imageLabel.Size = arg2.ImageSize or UDim2.fromOffset(v86[91], 100)
imageLabel.ScaleType = Enum.ScaleType.Fit
imageLabel.Image = arg2.Image or "rbxassetid://89204837120267"
imageLabel.Parent = frame2
local frame3 = Instance.new("Frame")
frame3.AnchorPoint = Vector2.new(1, 0)
frame3.Position = UDim2.new(1, 2, 0, -v86[56])
frame3.Size = UDim2.fromOffset(v86[144], 22)
frame3.BackgroundTransparency = 1
frame3.BorderSizePixel = 0
frame3.ZIndex = 6
arg4:Bind(frame3, "BackgroundColor3", "Accent")
frame3.Parent = instance2
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(1, v86[186])
uiCorner2.Parent = frame3
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Transparency = v86[63]
uiStroke.Thickness = 1.5
uiStroke.Parent = frame3
local instance4 = Instance.new(v86[135])
instance4.BackgroundTransparency = 1
instance4.Size = UDim2.fromScale(1, 1)
instance4.Text = "✓"
instance4.FontFace = v116.Bold
instance4.TextSize = 15
instance4.TextColor3 = Color3.fromRGB(v86[108], v86[108], 255)
instance4.TextTransparency = v86[63]
instance4.ZIndex = 7
instance4.Parent = frame3
local instance5 = Instance.new(v86[128])
instance5.BorderSizePixel = 0
instance5.AnchorPoint = Vector2.new(0.5, 0)
instance5.Position = UDim2.new(v86[101], 0, 1, 5)
instance5.Size = UDim2.fromOffset(v86[91], 100)
instance5.BackgroundTransparency = v86[147]

if arg2.AccentColor ~= nil then
instance5.BackgroundColor3 = arg2.AccentColor
else
arg4:Bind(instance5, "BackgroundColor3", "Accent")
end

instance5.Parent = instance2
Instance.new("UICorner").Parent = instance5
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
local new = ColorSequenceKeypoint.new
local v121 = v86[63]
uiGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(v86[108], 255, v86[108])), new(v121, color) })
uiGradient.Parent = instance5
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = v86[63]
textLabel.BorderSizePixel = 0
textLabel.AnchorPoint = Vector2.new(0, v86[101])
textLabel.Position = UDim2.fromScale(0, 0.5)
textLabel.AutomaticSize = Enum.AutomaticSize.XY
textLabel.TextSize = 16
textLabel.Text = v120
textLabel.FontFace = v116.SemiBold
textLabel.TextColor3 = titleColor
textLabel.Parent = frame

local tbl18 = {
Item = arg2,
Object = frame,
Card = instance2,
Button = textButton,
Title = textLabel,
Image = imageLabel,
SelectIndicator = frame3,
SelectIndicatorIcon = instance4,
SelectIndicatorStroke = uiStroke,
Accent = instance5,
Selected = arg2.Selected == true,
TitleColor = titleColor,
DefaultPreviewColor = previewColor,
DefaultAccentPosition = instance5.Position,
DefaultImageSize = imageLabel.Size,
SearchKey = arg2.Name:lower(),
}

local render = arg2.Render

if render ~= nil then
local frame4 = Instance.new("Frame")
frame4.BackgroundTransparency = v86[63]
frame4.BorderSizePixel = 0
frame4.Size = UDim2.fromScale(1, 1)
frame4.Parent = instance2

render(arg2, {
Content = frame4,
HideImage = function()
imageLabel.Visible = false
end,
})
end

fn37(arg, tbl18, tbl18.Selected, true)

arg3:Connect(textButton.MouseEnter, function()
if tbl18.Selected then
return
end
arg._menu:Tween(tbl18.Card, { BackgroundColor3 = v118.get("Outline") })
end)

arg3:Connect(textButton.MouseLeave, function()
if tbl18.Selected then
return
end
arg._menu:Tween(tbl18.Card, { BackgroundColor3 = tbl18.DefaultPreviewColor })
end)

v117.connectClick(arg3, textButton, function()
arg:Set(arg2.Name)
end)

return tbl18
end

local function fn42(arg)
local value = arg.Value

if value == nil then
for _, v120 in arg._entries, nil, nil do
if v120.Item.Selected then
value = v120.Item.Name
break
end
end

if value == nil and arg._entries[v86[63]] ~= nil then
value = arg._entries[v86[63]].Item.Name
end

if value ~= nil then
arg:Set(value, true)
end

return
end

for _, v120 in arg._entries, nil, nil do
if v120.Item.Name == value then
arg._selectedEntry = v120
fn37(arg, v120, true)
return
end
end
end

local function fn43(arg, arg2)
for _, v120 in arg, nil, nil do
if v120.Name == arg2 then
return true
end
end

return false
end

local function fn44(arg)
for _, v120 in arg, nil, nil do
if v120.Selected then
return v120.Name
end
end

local v120 = arg[1]
if v120 ~= nil then
return v120.Name
end
return nil
end

local function fn45(arg)
if true then
local ctx = arg._ctx
local rt = arg._rt
if ctx == nil or rt == nil then
return
end
arg._buildToken = arg._buildToken + 1
local itemsTrove = arg._itemsTrove

if itemsTrove ~= nil then
itemsTrove:Destroy()
end

for _, v120 in arg._entries, nil, nil do
v120.Object:Destroy()
end

table.clear(arg._entries)
arg._selectedEntry = nil
local v120 = ctx.Trove:Extend()
local v121 = v118.newBatch(v120)
arg._itemsTrove = v120
local buildToken = arg._buildToken
local items = arg.Items

local function fn46(arg2)
for k, v122 in items, nil, nil do
if arg._buildToken ~= buildToken then
return
end
local v123 = fn41(arg, v122, rt.Holder, v120, v121)
table.insert(arg._entries, v123)
fn38(v123, arg._filter)

if arg2 and k % v86[192] == v86[186] then
task.wait()
end
end

if arg._buildToken == buildToken then
fn42(arg)
end
end

if #items <= 30 then
fn46(false)
else
v120:Add(task.spawn(fn46, true))
end

return
end

-- (anti-tamper freeze trap removed)
end

local function fn46(arg, parent, ctx)
local instance = Instance.new(v86[128])
instance.BackgroundTransparency = 1
instance.BorderSizePixel = 0
instance.Size = UDim2.new(1, 0, 0, arg._height)
instance.Parent = parent
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.BorderSizePixel = 0
scrollingFrame.Size = UDim2.fromScale(1, 1)
scrollingFrame.CanvasSize = UDim2.new(v86[186], 0, v86[186], 0)
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollingFrame.ScrollBarThickness = v86[186]
scrollingFrame.ScrollBarImageTransparency = v86[63]
scrollingFrame.Selectable = false
ctx.Batch:Bind(scrollingFrame, v86[154], "Accent")
scrollingFrame.Parent = instance
local active = scrollingFrame.Active
local uiGridLayout = Instance.new("UIGridLayout")
uiGridLayout.CellSize = udim2
uiGridLayout.CellPadding = udim22
uiGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiGridLayout.Parent = scrollingFrame
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Size = UDim2.fromScale(v86[63], 1)
frame.Visible = false
frame.Parent = instance
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(0.5, 0.5)
frame2.Position = UDim2.fromScale(0.5, 0.5)
frame2.Size = UDim2.new(v86[63], -48, 0, 0)
frame2.AutomaticSize = Enum.AutomaticSize.Y
frame2.BackgroundTransparency = 1
frame2.BorderSizePixel = v86[186]
frame2.Parent = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListLayout.Padding = UDim.new(v86[186], 8)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame2
local instance2 = Instance.new(v86[135])
instance2.BackgroundTransparency = 1
instance2.BorderSizePixel = 0
instance2.Size = UDim2.new(1, 0, 0, v86[61])
instance2.FontFace = v116.SemiBold
instance2.Text = ""
instance2.TextSize = 17
instance2.TextWrapped = true
ctx.Batch:Bind(instance2, "TextColor3", "TextColor")
instance2.Parent = frame2
local instance3 = Instance.new(v86[135])
instance3.BackgroundTransparency = 1
instance3.BorderSizePixel = 0
instance3.Size = UDim2.fromScale(1, 0)
instance3.AutomaticSize = Enum.AutomaticSize.Y
instance3.FontFace = arg._menu.Fonts.Main
instance3.Text = ""
instance3.TextSize = 15
instance3.TextWrapped = true
ctx.Batch:Bind(instance3, "TextColor3", v86[96])
instance3.Parent = frame2
local textButton = Instance.new("TextButton")
textButton.Size = UDim2.fromOffset(v86[67], 32)
textButton.BackgroundColor3 = v118.get("ElementBackground")
textButton.BorderSizePixel = 0
textButton.AutoButtonColor = false
textButton.FontFace = v116.SemiBold
textButton.Text = "Clear Search"
textButton.TextSize = 15
textButton.Visible = v86[153]
ctx.Batch:Bind(textButton, "BackgroundColor3", "ElementBackground")
ctx.Batch:Bind(textButton, "TextColor3", "Accent")
textButton.Parent = frame2
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = textButton
local uiStroke = Instance.new("UIStroke")
ctx.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = textButton

ctx.Trove:Connect(textButton.MouseEnter, function()
arg._menu:Tween(textButton, { BackgroundColor3 = v118.get(v86[88]) })
end)

ctx.Trove:Connect(textButton.MouseLeave, function()
arg._menu:Tween(textButton, { BackgroundColor3 = v118.get("ElementBackground") })
end)

v117.connectClick(ctx.Trove, textButton, function()
local onClearFilter = arg._onClearFilter

if onClearFilter ~= nil then
onClearFilter()
end
end)

local v120 = nil
local connection = nil
local n = -1

local function fn47()
local flag19 = arg._heightMode == "Fill"
local scrollingEnabled = not flag19
scrollingFrame.ScrollingEnabled = scrollingEnabled
scrollingFrame.Active = scrollingEnabled and active
local height = arg._height

if flag19 then
local y = uiGridLayout.AbsoluteContentSize.Y

if arg.State ~= "Ready" then
y = 144
end

local height2 = arg._height

if v120 ~= nil then
height2 = math.max(0, v120.AbsoluteSize.Y - instance.AbsolutePosition.Y - v120.AbsolutePosition.Y + v120.CanvasPosition.Y)
end

height = math.max(y, height2)
end

if height == n then
return
end
n = height
instance.Size = UDim2.new(1, 0, 0, height)
end

local offset = udim2.X.Offset
local offset2 = udim22.X.Offset
local y = udim2.Y
local n33 = -1

local function fn48()
local x = scrollingFrame.AbsoluteSize.X
if x < offset then
return
end
local n34 = math.floor((x + offset2) / (offset + offset2))

if n34 < 1 then
n34 = v86[63]
end

local n35 = math.floor((x - offset2 * (n34 - 1)) / n34)
if n35 == n33 then
return
end
n33 = n35
uiGridLayout.CellSize = UDim2.new(0, n35, y.Scale, y.Offset)
end

local function fn49()
local v121 = v119.findScrollingAncestor(instance)
if v121 == v120 then
return
end

if connection ~= nil then
ctx.Trove:Remove(connection)
connection = nil
end

v120 = v121

if v120 ~= nil then
connection = ctx.Trove:Connect(v120:GetPropertyChangedSignal("AbsoluteSize"), fn47)
end

fn47()
end

ctx.Trove:Connect(scrollingFrame:GetPropertyChangedSignal(v86[131]), fn48)
ctx.Trove:Connect(uiGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"), fn47)
ctx.Trove:Connect(instance:GetPropertyChangedSignal("AbsolutePosition"), fn47)
ctx.Trove:Connect(instance.AncestryChanged, fn49)
fn49()
ctx.Trove:Add(task.defer(fn48))
ctx.Trove:Add(task.defer(fn47))
arg._ctx = ctx

arg._rt = {
Holder = scrollingFrame,
StateRoot = frame,
StateTitle = instance2,
StateMessage = instance3,
ClearFilter = textButton,
UpdateHeight = fn47,
}

fn45(arg)
fn40(arg)
return instance
end

index2._New = function(arg, arg2, arg3, arg4)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "SkinChanger",
Row = arg2,
Items = arg4.Items or {},
_areItemsPublished = arg4.Items ~= nil,
Value = nil,
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_height = arg4.Height or 300,
_heightMode = arg4.HeightMode or "Fixed",
State = arg4.State or "Ready",
_stateMessage = arg4.StateMessage,
_onClearFilter = arg4.OnClearFilter,
_filter = nil,
_entries = {},
_selectedEntry = nil,
_buildToken = 0,
_itemsTrove = nil,
_ctx = nil,
_rt = nil,
}, index2)

arg2:AttachRight(function(arg5, arg6)
return fn46(obj, arg5, arg6)
end, nil, nil, arg3)

return obj
end

index2.Set = function(arg, arg2, arg3)
local v120

if arg2 ~= nil and arg._areItemsPublished and not fn43(arg.Items, arg2) then
v120 = nil
else
v120 = arg2
end

local flag19 = arg2 ~= nil and v120 == nil
local v121 = nil

if v120 ~= nil then
v121 = nil

for _, v122 in arg._entries, nil, nil do
if v122.Item.Name == v120 then
v121 = v122
break
else
v121 = nil
end
end
end

if arg.Value == v120 and (v121 == nil or arg._selectedEntry == v121) and not flag19 then
return
end
arg.Value = v120
local selectedEntry = arg._selectedEntry

if selectedEntry ~= nil and selectedEntry ~= v121 then
fn37(arg, selectedEntry, false)
end

arg._selectedEntry = v121

if v121 ~= nil then
fn37(arg, v121, v86[34])
end

arg.ValueChanged:Fire(v120)

if not arg3 then
arg._onChanged(v120)
arg.Changed:Fire(v120)
end
end

index2.SetItems = function(arg, arg2, arg3)
local value = arg.Value
arg.Items = table.clone(arg2)
arg._areItemsPublished = true
local v120 = v86[153]

if value == nil then
value = fn44(arg.Items)
elseif not fn43(arg.Items, value) then
value = fn44(arg.Items)
v120 = v86[34]
end

arg.Value = value
arg.ValueChanged:Fire(value)

if v120 and not arg3 then
arg._onChanged(value)
arg.Changed:Fire(value)
end

fn45(arg)
return arg
end

index2.SetFilter = function(arg, filter)
arg._filter = filter

for _, v120 in arg._entries, nil, nil do
fn38(v120, filter)
end

return arg
end

index2.SetState = function(arg, state, stateMessage)
arg.State = state
arg._stateMessage = stateMessage
fn40(arg)
return arg
end

index2.SetClearFilterAction = function(arg, onClearFilter)
arg._onClearFilter = onClearFilter
fn40(arg)
return arg
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._buildToken = arg._buildToken + 1
arg._trove:Destroy()
end

return index2
end

tbl17.Z = function()
local z = tbl17.cache.Z

if not z then
z = { c = fn35() }
tbl17.cache.Z = z
end

return z.c
end
end
do -- _
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
tbl17.B()
local v118 = tbl17.A()
local index2 = {}
index2.__index = index2

local function createFrame(arg, parent, arg2)
local menu = arg._menu
local controlHeight = v117.get().Row.ControlHeight
local frame = Instance.new("Frame")
frame.ClipsDescendants = true
frame.AnchorPoint = Vector2.new(v86[63], 0.5)
frame.Position = UDim2.new(v86[63], -v86[63], 0.5, 0)
frame.Size = UDim2.fromOffset(0, controlHeight)
frame.BorderSizePixel = 0
arg2.Batch:Bind(frame, v86[5], v86[168])
frame.Parent = parent
local uiSizeConstraint = Instance.new("UISizeConstraint")
uiSizeConstraint.MinSize = Vector2.new(math.min(arg.MaxWidth + v86[12], v86[163]), controlHeight)
uiSizeConstraint.MaxSize = Vector2.new(arg.MaxWidth + 12, controlHeight)
uiSizeConstraint.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, v86[27], "Outline")
uiStroke.Parent = frame
local instance = Instance.new(v86[148])
instance.ClearTextOnFocus = false
instance.PlaceholderText = arg.Placeholder
arg2.Batch:Bind(instance, "PlaceholderColor3", "Unselected")
instance.FontFace = v116.SemiBold
instance.Text = ""
instance.AnchorPoint = Vector2.new(0, 0.5)
instance.BorderSizePixel = 0
instance.BackgroundTransparency = v86[63]
instance.Position = UDim2.new(0, 5, v86[101], 0)
instance.Size = UDim2.new(1, -10, 1, 0)
instance.AutomaticSize = Enum.AutomaticSize.None
instance.TextSize = v86[13]
instance.TextXAlignment = Enum.TextXAlignment.Left
instance.Selectable = v86[153]
instance.Active = v86[34]
arg2.Batch:Bind(instance, "TextColor3", "TextColor")
instance.Parent = frame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingRight = UDim.new(0, v86[175])
uiPadding.PaddingLeft = UDim.new(0, 1)
uiPadding.Parent = instance
arg._rt = { Outline = frame, Input = instance }
frame.Active = true
arg2.Trove:Connect(frame.InputBegan, function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function() instance:CaptureFocus() end)
end
end)
local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, v86[186], false, 0)

local function fn36(arg3)
if instance.TextSize ~= 16 then
instance.TextSize = 16
end

local _tbp = Instance.new("GetTextBoundsParams")
_tbp.Text = instance.Text
_tbp.Size = 16
_tbp.Font = instance.FontFace
_tbp.Width = 100000
local x = game:GetService("TextService"):GetTextBoundsAsync(_tbp).X

if arg.MaxWidth < x then
instance.TextSize = math.max(math.floor(v86[13] * arg.MaxWidth / x), 8)
x = arg.MaxWidth
end

local udim2 = UDim2.fromOffset(x + 12, controlHeight)

if arg3 then
menu:Tween(frame, { Size = udim2 }, tweenInfo)
else
frame.Size = udim2
end
end

arg2.Trove:Connect(instance:GetPropertyChangedSignal("Text"), function()
fn36(true)

if not arg.FocusLostOnly then
arg:Set(instance.Text)
end
end)

arg2.Trove:Connect(instance.Focused, function()
menu:Tween(instance, { TextColor3 = v118.get(v86[139]) })
end)

arg2.Trove:Connect(instance.FocusLost, function()
menu:Tween(instance, { TextColor3 = v118.get("TextColor") })

if arg.FocusLostOnly then
arg:Set(instance.Text)
end
end)

arg2.Trove:Connect(arg.ValueChanged, function(text)
if instance.Text ~= text and not instance:IsFocused() then
instance.Text = text
end
end)

if instance.Text ~= arg.Value then
instance.Text = arg.Value
end

arg2.Trove:Add(task.defer(function()
fn36(false)
end))

return frame
end

index2._New = function(arg, arg2, arg3, arg4)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "Input",
Row = arg2,
Value = arg4.Default or "",
Placeholder = arg4.Placeholder or v86[22],
FocusLostOnly = arg4.FocusLostOnly == v86[34],
MaxWidth = arg4.MaxLength or 200,
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg4.OnChanged or function()
end,
_rt = nil,
}, index2)

arg2:AttachRight(function(arg5, arg6)
return createFrame(obj, arg5, arg6)
end, nil, nil, arg3)

return obj
end

index2.Set = function(arg, arg2, arg3)
if type(arg2) == "boolean" or arg2 == nil then
return
end
local value = tostring(arg2)
if value == arg.Value then
return
end
arg.Value = value
arg.ValueChanged:Fire(value)

if not arg3 then
arg._onChanged(value)
arg.Changed:Fire(value)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17._ = function()
local tbl18 = tbl17.cache._

if not tbl18 then
tbl18 = { c = fn35() }
tbl17.cache._ = tbl18
end

return tbl18.c
end
end
do -- aa
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.x()
tbl17.B()
local v117 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36(arg)
if arg:IsA("Model") then
local boundingBox, v118 = arg:GetBoundingBox()
return boundingBox.Position, math.max(v118.X, v118.Y, v118.Z) * 0.5
end

if arg:IsA("BasePart") then
local size = arg.Size
return arg.Position, math.max(size.X, size.Y, size.Z) * v86[101]
end
return Vector3.zero, 4
end

local function fn37(arg)
if arg._model == nil then
return
end
local modelCenter = arg._modelCenter
local n = math.max(arg._modelRadius * 2.4 * arg._distanceMultiplier, v86[26])
local rotation = arg._rotation
local n33 = math.clamp(arg._elevation, -1.4707963267948965, v86[23])
local v118 = math.cos(n33)
arg._camera.CFrame = CFrame.new(modelCenter + Vector3.new(math.cos(rotation) * n * v118, math.sin(n33) * n, math.sin(rotation) * n * v118), modelCenter)
end

local function createFrame(arg, parent, arg2)
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Size = UDim2.new(1, v86[186], 0, arg._height)
frame.BorderSizePixel = v86[186]
frame.Parent = parent
local instance = Instance.new(v86[128])
instance.Size = UDim2.fromScale(v86[63], 1)
instance.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
instance.BorderSizePixel = 0
instance.ZIndex = 0
instance.Parent = frame
local instance2 = Instance.new(v86[46])
instance2.Rotation = v86[45]
v115.bindSurfaceGradient(arg2.Batch, instance2, { v86[187], v86[70] })
instance2.Parent = instance
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = instance
local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Size = UDim2.fromScale(v86[63], 1)
viewportFrame.BackgroundTransparency = 1
viewportFrame.BorderSizePixel = 0
viewportFrame.LightDirection = Vector3.new(-1, -v86[63], -1).Unit
viewportFrame.LightColor = Color3.fromRGB(v86[108], 255, 255)
viewportFrame.Ambient = Color3.fromRGB(140, 140, 150)
viewportFrame.CurrentCamera = arg._camera
viewportFrame.Parent = frame
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(0, v86[54])
uiCorner2.Parent = viewportFrame
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = viewportFrame
arg._worldModel.Parent = viewportFrame
arg._rt = viewportFrame
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.fromScale(1, 1)
textButton.BorderSizePixel = 0
textButton.Text = ""
textButton.AutoButtonColor = false
textButton.Parent = viewportFrame

arg2.Trove:Connect(textButton.InputBegan, function(arg3)
if arg3.UserInputType ~= Enum.UserInputType.MouseWheel then
return
end
local n = 1

if arg3.Position.Z > 0 then
n = -1
end

arg._distanceMultiplier = math.clamp(arg._distanceMultiplier * 0.85 ^ (-n), 0.2, v86[54])
fn37(arg)
end)

local v118 = nil

v116.connectDrag(arg2.Trove, textButton, function(arg3)
local v119 = v118
local vector2 = Vector2.new(arg3.Position.X, arg3.Position.Y)
v118 = vector2
if v119 == nil then
return
end
local n = vector2 - v119
arg._rotation = arg._rotation - n.X * 0.012
arg._elevation = math.clamp(arg._elevation - n.Y * 0.012, -1.4707963267948965, 1.4707963267948965)
fn37(arg)
end, function(arg3)
v118 = nil
if arg3 then
arg._autoRotate = false
return
end

if arg._userWantsAutoRotate then
arg._autoRotate = true
end
end)

arg2.Trove:Add(arg2.Menu:OnPreRender(function(arg3)
if arg._model == nil or not v117.isEffectivelyVisible(viewportFrame) then
return
end

if arg._autoRotate then
arg._rotation = arg._rotation + arg3 * arg._rotateSpeed
fn37(arg)
end
end))

for _, v119 in arg._onRealized, nil, nil do
v119(viewportFrame)
end

table.clear(arg._onRealized)
return frame
end

index2._New = function(arg, arg2, arg3, arg4)
local camera = Instance.new("Camera")
camera.FieldOfView = arg4.FieldOfView or 50
arg3:Add(camera)
local worldModel = Instance.new("WorldModel")
arg3:Add(worldModel)
local flag19 = arg4.AutoRotate ~= v86[153]

local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = v86[196],
Row = arg2,
_height = arg4.Height or 180,
_rotation = 0,
_elevation = v86[30],
_autoRotate = flag19,
_userWantsAutoRotate = flag19,
_rotateSpeed = arg4.RotateSpeed or 0.6,
_distanceMultiplier = arg4.DistanceMul or 1,
_camera = camera,
_worldModel = worldModel,
_model = nil,
_modelCenter = Vector3.zero,
_modelRadius = 4,
_rt = nil,
_onRealized = {},
}, index2)

arg2:AttachRight(function(arg5, arg6)
return createFrame(obj, arg5, arg6)
end, nil, nil, arg3)

return obj
end

index2.SetModel = function(arg, arg2)
local model = arg._model

if model ~= nil and model.Parent == arg._worldModel then
model:Destroy()
end

arg._model = nil

if arg2 ~= nil then
local clone = arg2:Clone()

if clone ~= nil then
clone.Parent = arg._worldModel
arg._model = clone
local v118, v119 = fn36(clone)
arg._modelCenter = v118
arg._modelRadius = v119
fn37(arg)
end
end

return arg
end

index2.OnRealized = function(arg, arg2)
local rt = arg._rt
if rt ~= nil then
arg2(rt)
return arg
end
table.insert(arg._onRealized, arg2)
return arg
end

index2.SetDistance = function(arg, arg2)
arg._distanceMultiplier = math.max(0.1, arg2)
fn37(arg)
return arg
end

index2.SetRotation = function(arg, rotation)
arg._rotation = rotation
fn37(arg)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.aa = function()
local aa = tbl17.cache.aa

if not aa then
local aa2 = { c = fn35() }
tbl17.cache.aa = aa2
aa = aa2
end

return aa.c
end
end
do -- ab
local function fn35()
local v115 = tbl17.g()
tbl17.k()
local v116 = tbl17.P()
local v117 = tbl17.C()
local v118 = tbl17.N()
local v119 = tbl17.M()
tbl17.r()
local v120 = tbl17.Q()
local v121 = tbl17.H()
local v122 = tbl17.R()
local v123 = tbl17.T()
local v124 = tbl17.U()
local v125 = tbl17.v()
local v126 = tbl17.V()
local v127 = tbl17.X()
local v128 = tbl17.Y()
local v129 = tbl17.u()
local v130 = tbl17.x()
local v131 = tbl17.G()
local v132 = tbl17.J()
local v133 = tbl17.B()
local v134 = tbl17.W()
local v135 = tbl17.Z()
local v136 = tbl17.K()
local v137 = tbl17._()
local v138 = tbl17.A()
local v139 = tbl17.S()
local v140 = tbl17.aa()
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2, arg3, arg4)
return setmetatable({
_trove = arg2,
_menu = arg,
_kind = arg3,
Title = arg4,
Opened = arg2:Add(v115.new()),
_side = nil,
_resolveParent = nil,
_groupSpec = nil,
_entries = {},
_visible = v86[34],
_realized = false,
_realizeTrove = nil,
_batch = nil,
_ctx = nil,
_elements = nil,
_titleLabel = nil,
_rootFrame = nil,
_separatorsDirty = false,
_separatorTrove = arg2:Extend(),
_popup = nil,
_gearOverlayParent = nil,
_gears = {},
_gearTrigger = nil,
_gearTooltip = nil,
_gearOwnerRow = nil,
}, index2)
end

index2.BuildSection = function(arg, arg2, arg3, resolveParent)
local v141 = fn36(arg, arg2:Extend(), "section", arg3.Title or "")
v141._side = arg3.Side
v141._resolveParent = resolveParent
return v141
end

index2.BuildPanes = function(arg, arg2, arg3)
local tbl18 = {}

for _, v141 in arg3, nil, nil do
table.insert(tbl18, fn36(arg, arg2:Extend(), "subsection", v141))
end

return tbl18
end

index2.BuildRoot = function(arg, arg2)
return fn36(arg, arg2:Extend(), "root", "")
end

local function fn37(arg, parent, arg2)
local v141 = v125.get()
local frame = Instance.new("Frame")
frame.LayoutOrder = v134.nextLayoutOrder(parent)
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, 0)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Visible = arg._visible
frame.Parent = parent
arg._rootFrame = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, v141.Section.TitleGap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame

if arg.Title ~= "" then
local instance = Instance.new(v86[135])
instance.Text = arg.Title
instance.AnchorPoint = Vector2.new(0, 0.5)
instance.BackgroundTransparency = 1
instance.Position = UDim2.fromScale(v86[186], 0.5)
instance.BorderSizePixel = 0
instance.AutomaticSize = Enum.AutomaticSize.XY
instance.TextSize = v141.Section.TitleTextSize
instance.FontFace = arg._menu.Fonts.Main
arg2:Bind(instance, "TextColor3", "TextColor")
instance.Parent = frame
arg._titleLabel = instance
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingLeft = UDim.new(0, -v86[63])
uiPadding.Parent = instance
end

local v142 = v134.box(arg2, frame)
arg._elements = v134.elementsContainer(v142)
end

local function createFrame(arg, parent)
local v141 = v125.get()
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, 0)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Visible = arg._visible
frame.Parent = parent
arg._rootFrame = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, v141.Section.GroupGap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame
arg._elements = frame
return frame
end

local function fn38(arg)
local entries = arg._entries
local flag19 = false
local flag20 = false

for i = #entries, 1, -v86[63] do
local v141 = entries[i]
local flag21

if v141.Row ~= nil then
flag21 = v141.Row:IsVisible() and v141.Row.Frame ~= nil
else
flag21 = false

if v141.Group ~= nil then
local rootFrame = v141.Group._rootFrame
flag21 = rootFrame ~= nil and rootFrame.Visible
end
end

local separator = v141.Separator

if separator ~= nil then
separator.Visible = flag21 and flag19 and not flag20
end

if flag21 then
flag20 = v141.IsDivider == v86[34]
flag19 = true
end
end
end

index2._MarkSeparatorsDirty = function(arg)
if arg._separatorsDirty or not arg._realized then
return
end
arg._separatorsDirty = true
arg._separatorTrove:Clean()

arg._separatorTrove:Add(task.defer(function()
arg._separatorsDirty = false
fn38(arg)
end))
end

local function fn39(arg, arg2, arg3)
local elements = arg._elements
local ctx = arg._ctx
local batch = arg._batch
if elements == nil or ctx == nil or batch == nil then
return
end

if arg2.Row ~= nil then
arg2.Row:Realize(elements, ctx, arg3 * 2)
elseif arg2.Group ~= nil then
arg2.Group:_RealizeAsGroup(elements, ctx, arg3 * v86[56])
elseif arg2.Multi ~= nil then
arg2.Multi:Realize(arg3 * 2)
end

if not arg2.NoSeparator and arg2.Separator == nil then
local frame = Instance.new("Frame")
frame.Visible = v86[153]
frame.Size = UDim2.new(1, 0, 0, 1)
frame.BorderSizePixel = 0
frame.LayoutOrder = arg3 * 2 + v86[63]
batch:Bind(frame, v86[5], "Outline")
frame.Parent = elements
arg2.Separator = frame
end
end

local function fn40(arg, ctx)
arg._realizeTrove = ctx.Trove
arg._batch = ctx.Batch
arg._ctx = ctx

for k, v141 in arg._entries, nil, nil do
fn39(arg, v141, k)
end

fn38(arg)
end

index2.Realize = function(arg)
if arg._realized then
return
end
local resolveParent = arg._resolveParent
assert(arg._kind == "section", "Container.Realize is for sections")

if resolveParent == nil then
error("Container.Realize: section has no parent resolver")
end

arg._realized = true
local v141 = arg._trove:Extend()
local v142 = v138.newBatch(v141)
fn37(arg, resolveParent(), v142)
fn40(arg, { Menu = arg._menu, Trove = v141, Batch = v142 })
end

index2._SetGridParent = function(arg, parent, layoutOrder)
if true then
local rootFrame = arg._rootFrame

if rootFrame == nil then
if not flag2 then
return
end
return
end

rootFrame.LayoutOrder = layoutOrder
rootFrame.Parent = parent
return
end

-- (anti-tamper freeze trap removed)
end

index2._RealizeAsGroup = function(arg, arg2, arg3, layoutOrder)
if arg._realized then
return
end
arg._realized = true
local v141 = createFrame(arg, arg2)
v141.LayoutOrder = layoutOrder
local groupSpec = arg._groupSpec

if groupSpec ~= nil then
local function fn41()
v141.Visible = arg._visible and groupSpec.Predicate(groupSpec.Source.Value)
end

arg3.Trove:Connect(groupSpec.Source.ValueChanged, fn41)
fn41()
end

fn40(arg, arg3)
end

index2._RealizeAsPane = function(arg, elements, arg2)
if arg._realized then
return
end
arg._realized = true
arg._elements = elements
arg._rootFrame = elements
fn40(arg, arg2)
end

index2.RealizeRoot = function(arg, elements, arg2)
if arg._realized then
return
end
assert(arg._kind == "root", v86[82])
arg._realized = v86[34]
arg._elements = elements
arg._rootFrame = elements
local v141 = arg._trove:Extend()
fn40(arg, { Menu = arg._menu, Trove = v141, Batch = v138.newBatch(v141), ParentOverlay = arg2 })
end

local function fn41(arg, arg2)
local popup = arg._popup
if popup ~= nil then
return popup
end
local n = 300

if v129.IsMobile() then
n = v86[65]
end

local v141 = nil

local v142 = v131.new(arg._menu, arg._trove, {
Trigger = arg2,
Size = UDim2.fromOffset(n, v86[186]),
AnchorPoint = Vector2.new(1, 0),
CornerRadius = v86[118],
FlatBackground = v86[34],
ParentEntry = arg._gearOverlayParent,
Place = function(arg3)
local absolutePosition = arg3.AbsolutePosition
local absoluteSize = arg3.AbsoluteSize
return math.round(absolutePosition.X + absoluteSize.X), math.round(absolutePosition.Y + absoluteSize.Y + 2)
end,
OnToggle = function(arg3)
if arg3 and v141 ~= nil then
v141.CanvasPosition = Vector2.zero
end
end,
})

arg._popup = v142
local v143
v141, v143 = v142:AttachScrollingList(n, { Top = 9, Bottom = v86[133], Side = 9 })
arg._realized = v86[34]
arg._elements = v143
arg._rootFrame = v142.Root
fn40(arg, v142:RealizeCtx())
return v142
end

index2._RevealGear = function(arg)
local gearTrigger = arg._gearTrigger
if gearTrigger == nil then
return
end
fn41(arg, gearTrigger):SetOpen(v86[34])
end

local function createTextButton(arg, parent, arg2, name)
local n = 28
local n33 = 24

if v129.IsMobile() then
n = 44
n33 = 44
end

local textButton = Instance.new("TextButton")
textButton.Name = name
textButton.Text = name
textButton.TextTransparency = 1
textButton.Size = UDim2.fromOffset(n, n33)
textButton.AnchorPoint = Vector2.new(0, v86[101])
textButton.BackgroundTransparency = 1
textButton.Position = UDim2.fromScale(0, 0.5)
textButton.BorderSizePixel = 0
textButton.AutomaticSize = Enum.AutomaticSize.None
textButton.AutoButtonColor = false
textButton.Selectable = true
local textLabel = Instance.new("TextLabel")
textLabel.Name = "Ellipsis"
textLabel.Text = v86[40]
textLabel.AnchorPoint = Vector2.new(0.5, v86[101])
textLabel.Position = UDim2.fromScale(0.5, v86[101])
textLabel.Size = UDim2.fromOffset(v86[25], v86[61])
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.TextSize = 30
textLabel.FontFace = arg._menu.Fonts.Main
arg2.Batch:Bind(textLabel, "TextColor3", v86[174])
textLabel.Parent = textButton
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, 21)
uiPadding.Parent = textLabel
textButton.Parent = parent

arg2.Menu:AttachTooltip(arg2.Trove, textButton, function()
return name
end)

arg._gearOverlayParent = arg2.ParentOverlay
arg._gearTrigger = textButton

v130.connectClick(arg2.Trove, textButton, function()
fn41(arg, textButton):Toggle()
end)

return textButton
end

index2._AddEntry = function(arg, arg2, arg3)
local tbl18 = { Row = arg2, Group = nil, Separator = nil, NoSeparator = arg3 == v86[34] }
table.insert(arg._entries, tbl18)
arg._menu:InvalidateSearch()

arg2._onVisibilityChanged = function()
arg:_MarkSeparatorsDirty()
end

if arg._realized then
fn39(arg, tbl18, #arg._entries)
arg:_MarkSeparatorsDirty()
end
end

index2._RowFor = function(arg, arg2, arg3)
local row = arg2.Row
if row ~= nil then
return row
end
arg3.Label = arg2.Label
arg3.Tooltip = arg2.Tooltip
local v141 = v133.new(arg._menu, arg3)
arg:_AddEntry(v141, arg2.NoSeparator)
return v141
end

index2._Bind = function(arg, arg2, arg3, arg4, arg5)
local config = arg4.Config
if config == nil then
return
end
local config2 = arg._menu:GetConfig()
if config2 == nil then
return
end
local bind = arg4.Bind
local tbl18

if arg5 and (bind == nil or bind.Debounce == nil) then
tbl18 = {}
bind = bind and bind.WriteBack
tbl18.WriteBack = bind
tbl18.Debounce = true
else
tbl18 = bind
end

v116.bind(arg2, config2, arg3, config, tbl18)
end

index2.AddToggle = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Height = 20 })
local v142 = arg._trove:Extend()
local v143 = v139._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddSlider = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Height = 24, MediumTitle = true, RightOffset = -1 })
local v142 = arg._trove:Extend()
local v143 = v136._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2, true)
return v143
end

index2.AddRangeSlider = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Height = v86[61], MediumTitle = v86[34], RightOffset = -v86[63] })
local v142 = arg._trove:Extend()
local v143 = v132._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2, true)
return v143
end

index2.AddButton = function(arg, arg2)
local flag19 = arg2.Row == nil
return v117._New(arg._menu, arg:_RowFor(arg2, { Bare = true }), arg._trove:Extend(), arg2, flag19)
end

index2.AddLabel = function(arg, arg2)
return v124._New(arg._menu, arg:_RowFor(arg2, { Bare = true }), arg._trove:Extend(), arg2)
end

index2.AddDivider = function(arg, arg2)
local tbl18 = arg2 or {}
tbl18.NoSeparator = v86[34]
local v141 = arg:_RowFor(tbl18, { Bare = v86[34] })
local v142 = arg._entries[#arg._entries]

if v142 ~= nil and v142.Row == v141 then
v142.IsDivider = true
end

return v120._New(arg._menu, v141, arg._trove:Extend(), tbl18)
end

index2.AddTextBox = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Height = 24, MediumTitle = true })
local v142 = arg._trove:Extend()
local v143 = v137._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddDropdown = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Height = 24 })
local v142 = arg._trove:Extend()
local v143 = v121._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddMultiDropdown = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Height = 24 })
local v142 = arg._trove:Extend()
local v143 = v121._NewMulti(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddList = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Bare = true })
local v142 = arg._trove:Extend()
local v143 = v126._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddMultiList = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Bare = true })
local v142 = arg._trove:Extend()
local v143 = v126._NewMulti(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddKeybind = function(arg, arg2)
local v141 = v123._New(arg._menu, arg:_RowFor(arg2, { Height = 20 }), arg._trove:Extend(), arg2)
local configMap = arg2.ConfigMap

if configMap ~= nil then
local config = arg._menu:GetConfig()

if config ~= nil then
v141:_BindConfigMap(config, configMap)
end
end

return v141
end

local function fn42(arg, arg2, arg3)
local config = arg3.Config
local transparency = arg3.Transparency
arg:EnableAnimation(transparency ~= nil)

local function fn43()
local v141 = arg2:Get(config)
arg:SetAnimationMode(v141.Mode, v86[34])
arg:SetAnimationSpeed(v141.Speed, true)

if v141.BreathingMin ~= nil or v141.BreathingMax ~= nil then
arg:SetAnimationBreathingRange({
Min = math.floor((1 - (v141.BreathingMax or 1)) * v86[91] + v86[101]),
Max = math.floor((1 - (v141.BreathingMin or 0)) * 100 + 0.5),
}, true)
end

arg2:Apply(config, transparency, v141)
end

arg:Connect(arg.AnimationChanged, function(arg4)
arg2:SetMode(config, arg4)
end)

arg:Connect(arg.AnimationSpeedChanged, function(arg4)
arg2:SetSpeed(config, arg4)
end)

arg:Connect(arg.AnimationBreathingRangeChanged, function(arg4)
arg2:SetBreathing(config, 1 - arg4.Max / v86[91], 1 - arg4.Min / 100)
end)

arg:Connect(arg2:Changed(), fn43)
fn43()
end

index2.AddColor = function(arg, arg2)
local v141 = v119._New(arg._menu, arg:_RowFor(arg2, { Height = v86[9] }), arg._trove:Extend(), arg2)

if arg2.Config ~= nil then
local config = arg._menu:GetConfig()

if config ~= nil then
v118.bindConfig(v141, config, arg2)
end

if arg2.Animatable then
local colorAnimation = arg._menu:GetColorAnimation()

if colorAnimation ~= nil then
fn42(v141, colorAnimation, arg2)
end
end
end

return v141
end

index2.AddSkinChanger = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Bare = true })
local v142 = arg._trove:Extend()
local v143 = v135._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.AddIconStrip = function(arg, arg2)
local v141 = arg:_RowFor({ Row = nil, NoSeparator = true }, { Bare = v86[34], Height = arg2.Height })
local v142 = arg._trove:Extend()
local v143 = v122._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, { Config = arg2.Config, Bind = arg2.Bind })
return v143
end

index2.AddViewport = function(arg, arg2)
return v140._New(arg._menu, arg:_RowFor({ Label = arg2.Label, Tooltip = arg2.Tooltip, Row = arg2.Row, NoSeparator = arg2.NoSeparator }, { Bare = true }), arg._trove:Extend(), arg2)
end

index2.AddOrderedList = function(arg, arg2)
local v141 = arg:_RowFor(arg2, { Bare = true })
local v142 = arg._trove:Extend()
local v143 = v128._New(arg._menu, v141, v142, arg2)
arg:_Bind(v142, v143, arg2)
return v143
end

index2.GetConfig = function(arg)
return arg._menu:GetConfig()
end

index2.AddGear = function(arg, arg2)
local v141 = fn36(arg._menu, arg._trove:Extend(), "gear", "Gear")
v141._gearTooltip = arg2.Tooltip
local v142 = arg:_RowFor({ Row = arg2.Row }, { Height = v86[61] })
v141._gearOwnerRow = v142

if v129.IsMobile() then
v142._height = math.max(v142._height, 44)
end

local tooltip = arg2.Tooltip

if tooltip == nil then
local label = v142.Label

if label ~= nil and label ~= "" then
tooltip = "Open " .. label .. " details"
else
tooltip = "Open details"
end
end

local n = 28

if v129.IsMobile() then
n = 44
end

v142:AttachRight(function(arg3, arg4)
return createTextButton(v141, arg3, arg4, tooltip)
end, n, true, v141._trove)

table.insert(arg._gears, v141)
arg._menu:InvalidateSearch()
return v141
end

index2.AddGroup = function(arg, arg2)
local source = arg2.Source
local option = arg2.Option
local fn43

if option ~= nil then
fn43 = function(arg3)
if type(arg3) == "string" then
return arg3 == option
end
local v141 = v86[68]
if type(arg3) == v141 then
return arg3[option] == v86[34] or table.find(arg3, option) ~= nil
end
return v86[153]
end
else
fn43 = function(arg3)
return arg3 == true
end
end

local v141 = fn36(arg._menu, arg._trove:Extend(), "group", arg.Title)
v141._groupSpec = { Source = source, Predicate = fn43, Option = option }

if arg2.Visible ~= nil then
v141._visible = arg2.Visible
end

local tbl18 = { Row = nil, Group = v141, Separator = nil, NoSeparator = false }
table.insert(arg._entries, tbl18)
arg._menu:InvalidateSearch()

v141._trove:Connect(source.ValueChanged, function()
arg:_MarkSeparatorsDirty()
end)

if arg._realized then
fn39(arg, tbl18, #arg._entries)
arg:_MarkSeparatorsDirty()
end

return v141
end

index2.AddMultiSection = function(arg, arg2)
local v141 = index2.BuildPanes(arg._menu, arg._trove, arg2.Titles)

local tbl18 = {
Row = nil,
Group = nil,
Multi = v127.new(arg._menu, arg._trove, v141, function()
local elements = arg._elements
assert(elements ~= nil, "Container.AddMultiSection: container has not realized")
return elements
end),
Panes = v141,
Separator = nil,
NoSeparator = v86[34],
}

table.insert(arg._entries, tbl18)
arg._menu:InvalidateSearch()

if arg._realized then
fn39(arg, tbl18, #arg._entries)
end

return table.unpack(v141)
end

index2.CollectSearchHits = function(arg, arg2, arg3, arg4, arg5)
local tbl18 = arg5 or {}
if not arg._visible then
return
end
local groupSpec = arg._groupSpec
local str7, tbl19

if groupSpec == nil then
str7 = arg2
tbl19 = tbl18
else
local row = groupSpec.Source.Row
local v141 = v86[94]

if row ~= nil then
local label = row.Label

if typeof(label) == "string" and label ~= "" then
v141 = label
end
end

str7 = ("%s  ›  Requires %s: %s"):format(arg2, v141, groupSpec.Option or "On")
local resolveFrame = tbl18.ResolveFrame

tbl19 = {
Reveal = tbl18.Reveal,
ResolveFrame = function(arg6)
if not groupSpec.Predicate(groupSpec.Source.Value) and row ~= nil then
arg6 = row.Frame
end

if resolveFrame ~= nil then
return resolveFrame(arg6)
end
return arg6
end,
}
end

for _, v141 in arg._entries, nil, nil do
local row = v141.Row

if row ~= nil then
local label = row.Label

if label ~= nil and label ~= "" then
local resolveFrame = tbl19.ResolveFrame

table.insert(arg4, {
Kind = "control",
Label = label,
Crumb = str7,
Open = arg3,
Reveal = tbl19.Reveal,
GetFrame = function()
if resolveFrame ~= nil then
return resolveFrame(row.Frame)
end
return row.Frame
end,
})
end
end

local group = v141.Group

if group ~= nil then
group:CollectSearchHits(str7, arg3, arg4, tbl19)
end

local panes = v141.Panes
local multi = v141.Multi

if panes ~= nil and multi ~= nil then
for k, v142 in panes, nil, nil do
local reveal = tbl19.Reveal

local tbl20 = {
ResolveFrame = tbl19.ResolveFrame,
Reveal = function()
if reveal ~= nil then
reveal()
end

multi:SelectPane(k)
end,
}

local title = v142.Title
assert(typeof(title) == "string", "Container pane title must be a string")
v142:CollectSearchHits(("%s  ›  %s"):format(str7, title), arg3, arg4, tbl20)
end
end
end

for _, v141 in arg._gears, nil, nil do
local gearOwnerRow = v141._gearOwnerRow
local gearTooltip = v141._gearTooltip

if gearTooltip == nil and gearOwnerRow ~= nil then
gearTooltip = gearOwnerRow.Label
end

gearTooltip = gearTooltip or v86[14]
local reveal = tbl19.Reveal

local tbl20 = {
ResolveFrame = tbl19.ResolveFrame,
Reveal = function()
if reveal ~= nil then
reveal()
end

v141:_RevealGear()
end,
}

v141:CollectSearchHits(("%s  ›  %s"):format(str7, tostring(gearTooltip)), arg3, arg4, tbl20)
end
end

index2.SetTitle = function(arg, title)
arg.Title = title
arg._menu:InvalidateSearch()
local titleLabel = arg._titleLabel

if titleLabel ~= nil then
titleLabel.Text = title
end

return arg
end

index2.SetVisible = function(arg, visible)
if arg._visible == visible then
return
end
arg._visible = visible
arg._menu:InvalidateSearch()
local rootFrame = arg._rootFrame
if rootFrame == nil then
return
end
local groupSpec = arg._groupSpec

if groupSpec ~= nil then
visible = visible and groupSpec.Predicate(groupSpec.Source.Value)
rootFrame.Visible = visible
else
rootFrame.Visible = visible
end
end

index2.Destroy = function(arg)
local rootFrame = arg._rootFrame

if rootFrame ~= nil then
rootFrame:Destroy()
arg._rootFrame = nil
end

arg._trove:Destroy()
end

return index2
end

tbl17.ab = function()
local ab = tbl17.cache.ab

if not ab then
ab = { c = fn35() }
tbl17.cache.ab = ab
end

return ab.c
end
end
do -- ac
local function fn35()
local v115 = tbl17.k()
local v116 = tbl17.F()
local v117 = tbl17.ab()
tbl17.r()
local v118 = tbl17.s()
local v119 = tbl17.u()
local v120 = tbl17.x()
local v121 = tbl17.y()
local v122 = tbl17.W()
local v123 = tbl17.t()
local v124 = tbl17.A()
local v125 = tbl17.w()
local coreGui = v123.CoreGui
local guiService = v123.GuiService
local userInputService = v123.UserInputService
local color = Color3.fromRGB(255, 255, 255)
local color2 = Color3.fromRGB(231, 92, v86[53])
local color3 = Color3.fromRGB(v86[65], 220, 230)
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfo2 = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function fn36(arg, arg2)
return Color3.new(arg.R * arg2, arg.G * arg2, arg.B * arg2)
end

local function fn37(arg, arg2)
local clamp = math.clamp
local n = arg.B * arg2
local v126 = v86[63]
return Color3.new(math.clamp(arg.R * arg2, v86[186], 1), math.clamp(arg.G * arg2, v86[186], v86[63]), clamp(n, 0, v126))
end

local function fn38(arg, arg2, arg3, parent, text, arg4, arg5)
local textButton = Instance.new("TextButton")
textButton.Size = UDim2.fromScale(0, 1)
textButton.BorderSizePixel = v86[186]
textButton.Text = text
textButton.TextSize = 14
textButton.FontFace = v118.Bold
textButton.TextTruncate = Enum.TextTruncate.AtEnd
textButton.AutoButtonColor = false
textButton.Active = v86[34]
textButton.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
arg3:BindGradient(uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = textButton
local instance = Instance.new(v86[98])
instance.CornerRadius = UDim.new(0, 5)
instance.Parent = textButton
local v126 = arg4
local flag19 = true
local flag20 = false

local function fn39()
if not flag19 then
uiGradient.Enabled = false
textButton.BackgroundColor3 = v124.get("ElementBackground")
textButton.TextColor3 = v124.get("Unselected")
textButton.TextTransparency = 0.45
return
end

textButton.TextTransparency = v86[186]

if v126 == "secondary" then
uiGradient.Enabled = false
textButton.BackgroundColor3 = v124.get("ElementBackground")
textButton.TextColor3 = v124.get(v86[174])
elseif v126 == "danger" then
uiGradient.Enabled = false
textButton.BackgroundColor3 = color2
textButton.TextColor3 = color
else
uiGradient.Enabled = false
textButton.BackgroundColor3 = v124.get(v86[139])
textButton.TextColor3 = color
end
end

local function fn40()
if not flag19 then
return
end

if v126 == v86[158] then
arg:Tween(textButton, { BackgroundColor3 = v124.get("TabButtonSelected") }, tweenInfo)
arg:Tween(textButton, { TextColor3 = v124.get("TextColor") }, tweenInfo)
elseif v126 == v86[140] then
arg:Tween(textButton, { BackgroundColor3 = fn37(color2, 1.12) }, tweenInfo)
else
local v127 = v86[138]
arg:Tween(textButton, { BackgroundColor3 = fn37(v124.get(v86[139]), v127) }, tweenInfo)
end
end

local function fn41()
if v126 == "secondary" then
arg:Tween(textButton, { BackgroundColor3 = v124.get("ElementBackground") }, tweenInfo)
elseif v126 == "danger" then
arg:Tween(textButton, { BackgroundColor3 = color2 }, tweenInfo)
else
arg:Tween(textButton, { BackgroundColor3 = v124.get("Accent") }, tweenInfo)
end
end

for _, v127 in { "Accent", v86[120], "ElementBackground", "TextColor", "Unselected" }, nil, nil do
arg3:BindStateful(v127, function()
if not flag20 then
fn39()
end
end)
end

arg2:Connect(textButton.MouseEnter, function()
if not flag19 then
return
end
flag20 = true
fn40()
end)

arg2:Connect(textButton.MouseLeave, function()
flag20 = v86[153]

if flag19 then
fn41()
else
fn39()
end
end)

v120.connectPress(arg2, textButton, function()
if not flag19 then
return
end
arg:Tween(textButton, { BackgroundColor3 = fn36(textButton.BackgroundColor3, 0.85) }, tweenInfo2)
end, function()
if flag20 then
fn40()
elseif flag19 then
fn41()
else
fn39()
end
end)

v120.connectClick(arg2, textButton, function()
if flag19 then
arg5()
end
end)

fn39()

return {
Object = textButton,
SetVariant = function(arg6)
v126 = arg6

if flag20 then
fn40()
else
fn39()
end
end,
SetEnabled = function(active)
flag19 = active
textButton.Active = active

if not active then
flag20 = false
end

fn39()
end,
}
end

local function fn39(arg, parent)
local v126 = v119.IsMobile()
local n = v126 and 14 or 20
local n33 = v126 and v86[181] or 14
local n34 = v126 and 10 or 12
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 0)
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BorderSizePixel = 0
frame.BackgroundColor3 = color
frame.LayoutOrder = 1
frame.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v116.bindSurfaceGradient(arg, uiGradient, { "GradientTop", "GradientMid" })
uiGradient.Parent = frame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, n33)
uiPadding.PaddingRight = UDim.new(0, n)
uiPadding.PaddingBottom = UDim.new(v86[186], n34)
uiPadding.PaddingLeft = UDim.new(0, n)
uiPadding.Parent = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 3)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame
local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, -v86[192], v86[186], v86[186])
textLabel.AutomaticSize = Enum.AutomaticSize.Y
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.Text = ""
textLabel.TextSize = v126 and 16 or v86[100]
textLabel.TextWrapped = true
textLabel.TextTruncate = Enum.TextTruncate.AtEnd
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.FontFace = v118.Bold
textLabel.LayoutOrder = 1
arg:Bind(textLabel, v86[167], v86[174])
textLabel.Parent = frame
local uiSizeConstraint = Instance.new("UISizeConstraint")
uiSizeConstraint.MaxSize = Vector2.new(100000, 44)
uiSizeConstraint.Parent = textLabel
local textLabel2 = Instance.new("TextLabel")
textLabel2.Size = UDim2.fromScale(1, 0)
textLabel2.AutomaticSize = Enum.AutomaticSize.Y
textLabel2.BackgroundTransparency = 1
textLabel2.BorderSizePixel = 0
textLabel2.Text = ""
textLabel2.TextSize = v126 and 11 or 13
textLabel2.TextWrapped = true
textLabel2.TextTruncate = Enum.TextTruncate.AtEnd
textLabel2.TextXAlignment = Enum.TextXAlignment.Left
textLabel2.FontFace = v118.SemiBold
textLabel2.LayoutOrder = 2
arg:Bind(textLabel2, "TextColor3", "Unselected")
textLabel2.Parent = frame
local instance = Instance.new(v86[176])
instance.MaxSize = Vector2.new(100000, v126 and 34 or 40)
instance.Parent = textLabel2
return { Root = frame, Title = textLabel, Description = textLabel2 }
end

local function createFrame(arg, parent, layoutOrder)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 0, v86[63])
frame.BorderSizePixel = 0
frame.LayoutOrder = layoutOrder
arg:Bind(frame, "BackgroundColor3", v86[120])
frame.Parent = parent
return frame
end

local function fn40(arg, parent)
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.Size = UDim2.fromScale(1, 1)
canvasGroup.BackgroundTransparency = 1
canvasGroup.BorderSizePixel = 0
canvasGroup.GroupTransparency = v86[63]
canvasGroup.Visible = false
canvasGroup.Parent = parent
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.fromScale(1, 1)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.BorderSizePixel = 0
scrollingFrame.Active = true
scrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
scrollingFrame.ScrollBarImageTransparency = 0.35
scrollingFrame.ScrollBarThickness = 0
scrollingFrame.Selectable = false
scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
arg:Bind(scrollingFrame, "ScrollBarImageColor3", "Accent")
scrollingFrame.Parent = canvasGroup
return { Group = canvasGroup, Body = scrollingFrame, Fade = { Tweening = false } }
end

local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2, arg3, arg4, arg5, arg6)
local v126 = v115.new()
local v127 = v124.newBatch(v126)
local v128 = fn40(v127, arg2)
v126:Add(v128.Group)
local v129 = v122.box(v127, v128.Body)
v129.Position = UDim2.fromOffset(20, v86[72])
v129.Size = UDim2.new(1, -40, 0, 24)
v129.AutomaticSize = Enum.AutomaticSize.None
local v130 = v122.elementsContainer(v129)
local v131 = v130:FindFirstChildOfClass(v86[4])
local v132 = v117.BuildRoot(arg, v126)
v132:RealizeRoot(v130, arg3)

return setmetatable({
_trove = v126,
_props = arg4,
_view = v128,
_card = v129,
_contentLayout = v131,
_open = arg5,
_syncActionEnabled = arg6,
_isActionEnabled = arg4.ActionEnabled ~= false,
_isDestroyed = false,
Container = v132,
}, index2)
end

index2._PrepareLayout = function(arg, arg2, arg3)
local n = arg._contentLayout.AbsoluteContentSize.Y + 24
arg._card.Position = UDim2.fromOffset(arg2, arg3)
arg._card.Size = UDim2.new(1, -arg2 * 2, 0, n)
return n + arg3 * 2
end

index2._SetViewport = function(arg, arg2, arg3)
arg._view.Body.CanvasSize = UDim2.fromOffset(0, arg3)
arg._view.Body.ScrollBarThickness = arg3 > arg2 + v86[101] and 4 or 0
end

index2.Open = function(arg)
if not arg._isDestroyed then
arg._open()
end
end

index2.SetActionEnabled = function(arg, isActionEnabled)
if arg._isDestroyed or arg._isActionEnabled == isActionEnabled then
return
end
arg._isActionEnabled = isActionEnabled
arg._syncActionEnabled(isActionEnabled)
end

index2.Destroy = function(arg)
if arg._isDestroyed then
return
end
arg._isDestroyed = true
arg._trove:Destroy()
end

local index3 = {}
index3.__index = index3

local function fn41(arg, arg2, arg3, parent, arg4, arg5)
local instance = Instance.new(v86[92])
instance.BorderSizePixel = 0
instance.BackgroundColor3 = color
instance.Text = ""
instance.AutoButtonColor = false
instance.Active = true
instance.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v116.bindSurfaceGradient(arg3, uiGradient, { "ElementBackground", "GradientDark" })
uiGradient.Parent = instance
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = instance
local uiStroke = Instance.new("UIStroke")
uiStroke.Transparency = 1

if arg4.Variant == "danger" then
uiStroke.Color = color2
else
arg3:Bind(uiStroke, "Color", "Accent")
end

uiStroke.Parent = instance
v121.attach(arg, arg2, instance, { CornerRadius = 6 })
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.new(0, v86[181], v86[101], 0)
frame.Size = UDim2.fromOffset(30, 30)
frame.BorderSizePixel = 0
frame.BackgroundTransparency = 0.9
frame.Visible = arg4.Glyph ~= nil

if arg4.Variant == "danger" then
frame.BackgroundColor3 = color2
else
arg3:Bind(frame, v86[5], "Accent")
end

frame.Parent = instance
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(0, 6)
uiCorner2.Parent = frame
local uiStroke2 = Instance.new("UIStroke")
uiStroke2.Transparency = 0.7

if arg4.Variant == v86[140] then
uiStroke2.Color = color2
else
arg3:Bind(uiStroke2, "Color", "Accent")
end

uiStroke2.Parent = frame
local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.fromScale(1, 1)
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.Text = arg4.Glyph or ""
textLabel.TextSize = 17
textLabel.FontFace = v118.SemiBold

if arg4.Variant == "danger" then
textLabel.TextColor3 = color2
else
arg3:Bind(textLabel, "TextColor3", v86[139])
end

textLabel.Parent = frame
local n = arg4.Glyph ~= nil and 51 or 13
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(v86[186], 0.5)
frame2.Position = UDim2.new(0, n, 0.5, 0)
frame2.Size = UDim2.new(v86[63], -n - v86[192], 0, 34)
frame2.BackgroundTransparency = v86[63]
frame2.BorderSizePixel = 0
frame2.Parent = instance
local textLabel2 = Instance.new("TextLabel")
textLabel2.Size = UDim2.new(1, 0, v86[186], 16)
textLabel2.BackgroundTransparency = 1
textLabel2.BorderSizePixel = 0
textLabel2.Text = arg4.Title
textLabel2.TextSize = v86[118]
textLabel2.TextTruncate = Enum.TextTruncate.AtEnd
textLabel2.TextXAlignment = Enum.TextXAlignment.Left
textLabel2.FontFace = v118.Bold
arg3:Bind(textLabel2, "TextColor3", v86[174])
textLabel2.Parent = frame2
local instance2 = Instance.new(v86[135])
instance2.Position = UDim2.fromOffset(0, 18)
instance2.Size = UDim2.new(1, 0, 0, 16)
instance2.BackgroundTransparency = 1
instance2.BorderSizePixel = 0
instance2.Text = arg4.Description or ""
instance2.TextSize = 11
instance2.TextWrapped = v86[153]
instance2.TextTruncate = Enum.TextTruncate.AtEnd
instance2.TextXAlignment = Enum.TextXAlignment.Left
instance2.TextYAlignment = Enum.TextYAlignment.Top
instance2.FontFace = v118.SemiBold
instance2.Visible = arg4.Description ~= nil and arg4.Description ~= ""
arg3:Bind(instance2, "TextColor3", "Unselected")
instance2.Parent = frame2
local textLabel3 = Instance.new("TextLabel")
textLabel3.AnchorPoint = Vector2.new(1, 0.5)
textLabel3.Position = UDim2.new(1, -11, 0.5, 0)
textLabel3.Size = UDim2.fromOffset(16, 24)
textLabel3.BackgroundTransparency = 1
textLabel3.BorderSizePixel = 0
textLabel3.Text = "›"
textLabel3.TextSize = 18
textLabel3.FontFace = v118.SemiBold
arg3:Bind(textLabel3, "TextColor3", "Unselected")
textLabel3.Parent = instance
local flag19 = false

local function fn42(arg6)
if flag19 == arg6 then
return
end
flag19 = arg6
local n33 = 1

if arg6 then
n33 = 0
end

local Accent = arg4.Variant == "danger" and color2 or v124.get("Accent")
local v126 = arg6 and color3 or color
local Unselected = arg6 and Accent or v124.get("Unselected")
local udim2 = UDim2.new(1, arg6 and -7 or -11, 0.5, 0)
arg:Tween(uiStroke, { Transparency = n33 }, tweenInfo)
arg:Tween(instance, { BackgroundColor3 = v126 }, tweenInfo)
arg:Tween(textLabel3, { TextColor3 = Unselected, Position = udim2 }, tweenInfo)
end

local function fn43()
local v126 = v125.getPointerPosition()

for _, v127 in coreGui:GetGuiObjectsAtPosition(v126.X, v126.Y) do
if v127 == instance or v127:IsDescendantOf(instance) then
fn42(true)
return
end
end

fn42(false)
end

arg2:Connect(instance.MouseEnter, function()
fn42(true)
end)

arg2:Connect(instance.MouseLeave, function()
fn42(false)
end)

v120.connectClick(arg2, instance, arg5)
return { Object = instance, SyncHover = fn43 }
end

index3.new = function(arg, arg2, arg3, arg4, arg5)
local v126 = arg3:Extend()
local v127 = v124.newBatch(v126)
local v128 = v119.IsMobile()
local n = v128 and 46 or 50
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.Visible = false
canvasGroup.GroupTransparency = 1
canvasGroup.BackgroundTransparency = v86[63]
canvasGroup.BorderSizePixel = 0
canvasGroup.Active = v86[34]
canvasGroup.ClipsDescendants = v86[34]
canvasGroup.Parent = arg:GetOverlayLayer()
v126:Add(canvasGroup)
local instance = Instance.new(v86[128])
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = 0
instance.BackgroundColor3 = Color3.new(0, 0, v86[186])
instance.BackgroundTransparency = 0.58
instance.ZIndex = 1
instance.Parent = canvasGroup
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[54])
uiCorner.Parent = instance
local canvasGroup2 = Instance.new("CanvasGroup")
canvasGroup2.AnchorPoint = Vector2.new(0.5, 0.5)
canvasGroup2.Position = UDim2.new(v86[101], 0, 0.5, -15)
canvasGroup2.Size = UDim2.fromOffset(520, v86[186])
canvasGroup2.AutomaticSize = Enum.AutomaticSize.Y
canvasGroup2.BorderSizePixel = 0
canvasGroup2.BackgroundTransparency = 1
canvasGroup2.ZIndex = 2
canvasGroup2.Parent = canvasGroup
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BorderSizePixel = 0
frame.BackgroundColor3 = color
frame.ZIndex = v86[186]
frame.Parent = canvasGroup2
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(0, 8)
uiCorner2.Parent = frame
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
v116.bindSurfaceGradient(v127, uiGradient, { "GradientTop", v86[187], v86[70] })
uiGradient.Parent = frame
local uiCorner3 = Instance.new("UICorner")
uiCorner3.CornerRadius = UDim.new(0, 8)
uiCorner3.Parent = canvasGroup2
local uiStroke = Instance.new("UIStroke")
v127:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = canvasGroup2
v116.addGlow(v127, canvasGroup2, { Amount = 5, DampingFactor = 0.65 })
local frame2 = Instance.new("Frame")
frame2.Size = UDim2.fromScale(1, 0)
frame2.AutomaticSize = Enum.AutomaticSize.Y
frame2.BackgroundTransparency = 1
frame2.BorderSizePixel = 0
frame2.Parent = canvasGroup2
local instance2 = Instance.new(v86[4])
instance2.SortOrder = Enum.SortOrder.LayoutOrder
instance2.Parent = frame2
local v129 = fn39(v127, frame2)
createFrame(v127, frame2, 2)
local frame3 = Instance.new("Frame")
frame3.Size = UDim2.new(1, 0, 0, v128 and v86[103] or v86[83])
frame3.BackgroundTransparency = v86[63]
frame3.BorderSizePixel = 0
frame3.LayoutOrder = 3
frame3.ClipsDescendants = v86[34]
frame3.Parent = frame2
local v130 = createFrame(v127, frame2, v86[26])
local frame4 = Instance.new("Frame")
frame4.Size = UDim2.new(1, v86[186], 0, n)
frame4.ClipsDescendants = v86[34]
frame4.BorderSizePixel = 0
frame4.BackgroundTransparency = 0.28
frame4.LayoutOrder = v86[175]
v127:Bind(frame4, "BackgroundColor3", v86[141])
frame4.Parent = frame2
local frame5 = Instance.new("Frame")
frame5.AnchorPoint = Vector2.new(1, 0.5)
frame5.Position = UDim2.new(1, -20, 0.5, 0)
frame5.Size = UDim2.fromOffset(104, 32)
frame5.BackgroundTransparency = 1
frame5.BorderSizePixel = 0

if v128 then
frame5.AnchorPoint = Vector2.new(0.5, v86[101])
frame5.Position = UDim2.fromScale(0.5, v86[101])
frame5.Size = UDim2.new(1, -26, v86[186], 38)
end

frame5.Parent = frame4
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 9)
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame5
local v131 = nil

local back = fn38(arg, v126, v127, frame5, "Back", "secondary", function()
local v132 = v131

if v132 ~= nil then
if v132._isConfirming then
v132:_CancelConfirmation()
else
v132:_ShowHub()
end
end
end)

back.Object.LayoutOrder = v86[63]
back.Object.Visible = v86[153]

local v132 = fn38(arg, v126, v127, frame5, "", "primary", function()
local v132 = v131

if v132 ~= nil then
v132:_RunPageAction()
end
end)

v132.Object.LayoutOrder = 2
v132.Object.Visible = false
local instance3 = Instance.new(v86[92])
instance3.AnchorPoint = Vector2.new(1, v86[186])
instance3.Position = UDim2.new(v86[63], -10, 0, 10)
instance3.Size = UDim2.fromOffset(26, v86[200])
instance3.BackgroundTransparency = v86[63]
instance3.BorderSizePixel = 0
instance3.Text = "×"
instance3.TextSize = 18
instance3.FontFace = v118.SemiBold
instance3.AutoButtonColor = false
instance3.ZIndex = 4
v127:Bind(instance3, "BackgroundColor3", "ElementBackground")
v127:Bind(instance3, "TextColor3", "Unselected")
instance3.Parent = canvasGroup2
local uiCorner4 = Instance.new("UICorner")
uiCorner4.CornerRadius = UDim.new(0, v86[54])
uiCorner4.Parent = instance3
local frame6 = Instance.new("Frame")
frame6.Position = UDim2.fromOffset(0, 0)
frame6.Size = UDim2.new(1, 0, 0, 1)
frame6.BorderSizePixel = 0
frame6.ZIndex = 3
v127:Bind(frame6, "BackgroundColor3", "Accent")
frame6.Parent = canvasGroup2
local uiGradient2 = Instance.new("UIGradient")
local numberSequence = NumberSequence.new
local tbl18 = {}
local v133 = NumberSequenceKeypoint.new(0, 1)
local v134 = NumberSequenceKeypoint.new(v86[62], 0.28)
local v135 = NumberSequenceKeypoint.new(0.5, 0)
local v136 = NumberSequenceKeypoint.new(v86[173], 0.28)
tbl18[1] = v133
tbl18[2] = v134
tbl18[3] = v135
tbl18[4] = v136

do
local values = table.pack(NumberSequenceKeypoint.new(1, v86[63]))
table.move(values, 1, values.n, 5, tbl18)
end

uiGradient2.Transparency = numberSequence(tbl18)
uiGradient2.Parent = frame6
v116.addGlow(v127, frame6, { Amount = 2, DampingFactor = v86[161] })

local v137 = arg:RegisterOverlay(canvasGroup, {
Open = v86[153],
CloseOnOutside = false,
OnToggle = function(arg6)
if arg6 then
canvasGroup.Visible = true
return
end
local v137 = v131

if v137 ~= nil and v137:IsOpen() then
v137:Close()
else
canvasGroup.Visible = false
end
end,
})

v126:Add({ Destroy = function()
arg:UnregisterOverlay(v137)
end })

local v138 = fn40(v127, frame3)
local frame7 = Instance.new("Frame")
frame7.BackgroundTransparency = v86[63]
frame7.BorderSizePixel = 0
frame7.Parent = v138.Body
local instance4 = Instance.new(v86[128])
instance4.Size = UDim2.fromScale(1, v86[186])
instance4.BackgroundTransparency = 1
instance4.BorderSizePixel = v86[186]
instance4.Parent = frame7
local uiGridLayout = Instance.new("UIGridLayout")
uiGridLayout.CellPadding = UDim2.fromOffset(v86[133], 10)
uiGridLayout.FillDirectionMaxCells = v128 and 1 or 2
uiGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiGridLayout.Parent = instance4

local obj = setmetatable({
_trove = v126,
_menu = arg,
_window = arg2,
_batch = v127,
_root = canvasGroup,
_panel = canvasGroup2,
_header = v129,
_closeButton = instance3,
_bodyHost = frame3,
_hubView = v138,
_hubContent = frame7,
_routes = instance4,
_routeLayout = uiGridLayout,
_routeButtons = {},
_footer = frame4,
_actionHolder = frame5,
_footerDivider = v130,
_footerHeightTween = nil,
_backAction = back,
_pageAction = v132,
_entry = v137,
_pages = {},
_activePage = nil,
_activeView = nil,
_bodyHeightTween = nil,
_rootTitle = arg4.Title,
_rootDescription = arg4.Description,
_activeDescription = arg4.Description,
_isConfirming = v86[153],
_onClosed = arg5,
_isOpen = false,
_isResolving = false,
_isDestroyed = false,
_didNotifyClosed = false,
_keyboardSyncToken = v86[186],
_previousSelectedObject = nil,
_hasSelectionGroup = false,
}, index3)

v131 = obj

v120.connectClick(v126, instance3, function()
obj:Close()
end)

v126:Connect(instance3.MouseEnter, function()
arg:Tween(instance3, { BackgroundTransparency = 0, TextColor3 = v124.get("TextColor") }, tweenInfo)
end)

v126:Connect(instance3.MouseLeave, function()
arg:Tween(instance3, { BackgroundTransparency = v86[63], TextColor3 = v124.get("Unselected") }, tweenInfo)
end)

v126:Connect(canvasGroup2:GetPropertyChangedSignal("AbsoluteSize"), function()
if obj._isOpen then
obj._panel.Position = obj:_ResolvePanelPosition(0)
end
end)

v126:Connect(arg2:GetPropertyChangedSignal("AbsolutePosition"), function()
obj:_SyncBounds()
end)

v126:Connect(arg2:GetPropertyChangedSignal("AbsoluteSize"), function()
obj:_SyncBounds()
end)

v126:Connect(arg.VisibilityChanged, function(arg6)
if not arg6 then
obj:Close()
end
end)

v126:Connect(userInputService.InputBegan, function(arg6)
if not obj._isOpen or arg6.KeyCode ~= Enum.KeyCode.Escape then
return
end

if arg:ShouldBlockKeybindCapture(arg6) then
return
end

if obj._isConfirming then
obj:_CancelConfirmation()
elseif obj._activePage ~= nil then
obj:_ShowHub()
else
obj:Close()
end
end)

v125.connectOnScreenKeyboard(v126, function()
obj:_SyncKeyboard()
end)

v126:Connect(userInputService.TextBoxFocused, function(arg6)
if arg6:IsDescendantOf(canvasGroup2) then
obj:_SyncKeyboard()
end
end)

v126:Connect(userInputService.TextBoxFocusReleased, function(arg6)
if arg6:IsDescendantOf(canvasGroup2) then
obj:_SyncKeyboard()
end
end)

obj:_ShowHub()
obj:_SyncBounds()
return obj
end

index3.AddPage = function(arg, arg2, arg3)
if arg._isDestroyed then
error(v86[145], 2)
end

local v126 = nil

local v127 = index2.new(arg._menu, arg._bodyHost, arg._entry, arg2, function()
local v127 = v126

if v127 ~= nil then
arg:_ShowPage(v127)
end
end, function(arg4)
if arg._activePage == v126 then
arg._pageAction.SetEnabled(arg4)
end
end)

arg._trove:Add(v127)
table.insert(arg._pages, v127)

local v128 = fn41(arg._menu, arg._trove, arg._batch, arg._routes, arg2, function()
v127:Open()
end)

v128.Object.LayoutOrder = #arg._pages
table.insert(arg._routeButtons, v128)

arg._trove:Connect(v127._contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
if arg._activePage == v127 then
arg:_UpdateLayout(true)
end
end)

if arg3 ~= nil then
arg3(v127.Container)
end

arg:_UpdateLayout()
v126 = v127
return v127
end

index3._SetHeader = function(arg, text, activeDescription)
local header = arg._header
arg._activeDescription = activeDescription
header.Title.Text = text
header.Description.Text = activeDescription or ""
header.Description.Visible = activeDescription ~= nil and activeDescription ~= "" and not arg:_IsKeyboardVisible()

if arg._isOpen then
header.Title.TextTransparency = 1
header.Description.TextTransparency = v86[63]
arg._menu:Tween(header.Title, { TextTransparency = 0 })
arg._menu:Tween(header.Description, { TextTransparency = 0 })
end
end

index3._ApplyFooter = function(arg, arg2)
local visible = not (arg2 == nil)
arg._backAction.Object.Visible = visible
arg._backAction.Object.Text = arg._isConfirming and "Cancel" or "Back"
local actionText = arg2 and arg2._props.ActionText or nil
local visible2 = actionText ~= nil and actionText ~= ""
arg._pageAction.Object.Visible = visible2

if visible2 and arg2 ~= nil then
local confirmation = arg2._props.Confirmation

if arg._isConfirming and confirmation ~= nil then
arg._pageAction.Object.Text = confirmation.ActionText or "Confirm"
else
arg._pageAction.Object.Text = actionText
end

local str7 = v86[114]

if arg2._props.Variant == "danger" then
str7 = "danger"
end

arg._pageAction.SetVariant(str7)
arg._pageAction.SetEnabled(arg2._isActionEnabled)
end

if not v119.IsMobile() then
local n = visible2 and v86[56] or 1
arg._actionHolder.Size = UDim2.fromOffset(n * 104 + (n - 1) * 9, 32)
end

arg._footerDivider.Visible = visible
local n = 0

if visible then
n = v119.IsMobile() and 46 or 50
end

local udim2 = UDim2.new(1, 0, 0, n)
local footerHeightTween = arg._footerHeightTween

if footerHeightTween ~= nil then
arg._footerHeightTween = nil
footerHeightTween:Cancel()
end

if arg._footer.Size ~= udim2 then
if arg._isOpen then
arg._footerHeightTween = arg._menu:Tween(arg._footer, { Size = udim2 })
else
arg._footer.Size = udim2
end
end
end

index3._ShowHub = function(arg)
if arg._isDestroyed or arg._isResolving then
return
end
arg._isConfirming = false
arg._menu:CloseOverlayDescendants(arg._entry)
arg._activePage = nil
arg._hubView.Body.CanvasPosition = Vector2.zero
arg:_TransitionViews(arg._hubView, -1)
arg:_SetHeader(arg._rootTitle, arg._rootDescription)
arg:_ApplyFooter(nil)
arg:_UpdateLayout(true)
arg:_SyncRouteHover()
end

index3._ShowPage = function(arg, activePage)
if arg._isDestroyed or arg._isResolving or not arg._isOpen then
return
end
arg._isConfirming = false
arg._menu:CloseOverlayDescendants(arg._entry)
arg._activePage = activePage
activePage._view.Body.CanvasPosition = Vector2.zero
arg:_TransitionViews(activePage._view, v86[63])
arg:_SetHeader(activePage._props.Title, activePage._props.Description)
arg:_ApplyFooter(activePage)
local onOpen = activePage._props.OnOpen

if onOpen ~= nil then
local v126, v127 = v107(onOpen)

if not v126 then
error(v127, 2)
end
end

arg:_UpdateLayout(true)
end

index3._BeginConfirmation = function(arg, arg2)
local confirmation = arg2._props.Confirmation
if confirmation == nil then
return
end
local description = confirmation.Description

if type(description) == "function" then
description = description()
end

arg._isConfirming = true
arg:_TransitionViews(nil, 0)
arg:_SetHeader(confirmation.Title or "Confirm action", description)
arg:_ApplyFooter(arg2)
arg:_UpdateLayout(true)
end

index3._CancelConfirmation = function(arg)
local activePage = arg._activePage
if not arg._isConfirming or activePage == nil or arg._isResolving then
return
end
arg._isConfirming = false
arg:_TransitionViews(activePage._view, v86[186])
arg:_SetHeader(activePage._props.Title, activePage._props.Description)
arg:_ApplyFooter(activePage)
arg:_UpdateLayout(true)
end

index3._RunPageAction = function(arg)
local activePage = arg._activePage
if activePage == nil or not activePage._isActionEnabled or arg._isResolving or not arg:IsOpen() then
return
end

if activePage._props.Confirmation ~= nil and not arg._isConfirming then
arg:_BeginConfirmation(activePage)
return
end
arg._isResolving = true
local onAction = activePage._props.OnAction
local flag19 = true
local v126 = nil

if onAction ~= nil then
flag19, v126 = v107(onAction)
end

arg._isResolving = false

if not flag19 then
error(v126, v86[56])
end

if v126 == false or not arg._isOpen or arg._activePage ~= activePage then
return
end
arg:_ShowHub()
end

index3._IsKeyboardVisible = function(arg)
local focusedTextBox = userInputService:GetFocusedTextBox()
return v125.onScreenKeyboardTop() ~= nil and focusedTextBox ~= nil and focusedTextBox:IsDescendantOf(arg._panel)
end

index3._GetKeyboardTop = function()
local guiInset = guiService:GetGuiInset()
return (v125.onScreenKeyboardTop() or 0) - guiInset.Y
end

local function fn42(arg, arg2)
local v126 = v86[56]
return math.round(arg - arg2) % 2 / v126
end

index3._ResolvePanelPosition = function(arg, arg2)
local absoluteSize = arg._root.AbsoluteSize
local absoluteSize2 = arg._panel.AbsoluteSize
local v126 = fn42(absoluteSize.X, absoluteSize2.X)
if not arg:_IsKeyboardVisible() then
return UDim2.new(0.5, v126, v86[101], arg2 + fn42(absoluteSize.Y, absoluteSize2.Y))
end
local y = absoluteSize2.Y
local absolutePosition = arg._root.AbsolutePosition
local v127 = v86[162]
return UDim2.new(0.5, v126, 0, math.round(math.max(absolutePosition.Y + 8 + y / v86[56], math.min(absolutePosition.Y + absoluteSize.Y / 2, arg:_GetKeyboardTop() - v127 - y / 2)) - absolutePosition.Y + arg2))
end

index3._GetActiveBody = function(arg)
local activePage = arg._activePage
if activePage ~= nil then
return activePage._view.Body
end
return arg._hubView.Body
end

index3._ScrollFocusedTextBox = function(arg)
if not arg:_IsKeyboardVisible() then
return
end
local v126 = arg:_GetActiveBody()
local focusedTextBox = userInputService:GetFocusedTextBox()
if focusedTextBox == nil or not focusedTextBox:IsDescendantOf(v126) then
return
end
local y = v126.AbsoluteWindowSize.Y
if y <= 0 then
return
end
local y2 = v126.CanvasPosition.Y
local n = focusedTextBox.AbsolutePosition.Y - v126.AbsolutePosition.Y + y2
local n33 = n + focusedTextBox.AbsoluteSize.Y

if n < y2 + v86[162] then
y2 = n - 8
elseif y2 + y - 8 < n33 then
y2 = n33 - y + 8
end

local n34 = math.max(v86[186], v126.AbsoluteCanvasSize.Y - y)
v126.CanvasPosition = Vector2.new(v126.CanvasPosition.X, math.clamp(y2, 0, n34))
end

index3._SyncKeyboard = function(arg)
if arg._isDestroyed then
return
end
arg._keyboardSyncToken = arg._keyboardSyncToken + 1
local keyboardSyncToken = arg._keyboardSyncToken
local activeDescription = arg._activeDescription
arg._header.Description.Visible = activeDescription ~= nil and activeDescription ~= "" and not arg:_IsKeyboardVisible()

task.defer(function()
if arg._isDestroyed or arg._keyboardSyncToken ~= keyboardSyncToken then
return
end
arg:_UpdateLayout()

task.defer(function()
if arg._isDestroyed or arg._keyboardSyncToken ~= keyboardSyncToken then
return
end
local v126 = arg:_ResolvePanelPosition(0)

if arg._isOpen and arg._root.Visible then
arg._menu:Tween(arg._panel, { Position = v126 })
else
arg._panel.Position = v126
end

arg:_ScrollFocusedTextBox()
end)
end)
end

index3._SetBodyHeight = function(arg, arg2, arg3)
local udim2 = UDim2.new(1, 0, 0, arg2)
local bodyHeightTween = arg._bodyHeightTween

if bodyHeightTween ~= nil then
arg._bodyHeightTween = nil
bodyHeightTween:Cancel()
end

if arg._bodyHost.Size == udim2 then
return
end

if arg3 and arg._isOpen then
arg._bodyHeightTween = arg._menu:Tween(arg._bodyHost, { Size = udim2 })
else
arg._bodyHost.Size = udim2
end
end

index3._TransitionViews = function(arg, activeView, arg2)
local activeView2 = arg._activeView
if activeView2 == activeView then
return
end
arg._activeView = activeView

if not arg._isOpen then
if activeView2 ~= nil then
activeView2.Group.Visible = false
activeView2.Group.GroupTransparency = 1
end

if activeView ~= nil then
activeView.Group.Position = UDim2.fromOffset(0, 0)
activeView.Group.GroupTransparency = 0
activeView.Group.Visible = true
end

return
end

if activeView2 ~= nil then
arg._menu:FadeCanvasGroup(activeView2.Group, v86[153], activeView2.Fade)
end

if activeView ~= nil then
if arg2 ~= 0 then
activeView.Group.Position = UDim2.fromOffset(arg2 * 16, 0)
arg._menu:Tween(activeView.Group, { Position = UDim2.fromOffset(0, 0) })
else
activeView.Group.Position = UDim2.fromOffset(0, 0)
end

arg._menu:FadeCanvasGroup(activeView.Group, true, activeView.Fade)
end
end

index3._SyncRouteHover = function(arg)
if v119.IsMobile() then
return
end

task.defer(function()
if arg._isDestroyed or arg._activeView ~= arg._hubView then
return
end

for _, v126 in arg._routeButtons, nil, nil do
v126.SyncHover()
end
end)
end

index3._UpdateLayout = function(arg, arg2)
if arg._isDestroyed then
return
end
local v126 = v119.IsMobile()
local n = v126 and 8 or v86[144]
local n33 = v126 and v86[103] or 64
local n34 = v126 and v86[118] or 20
local n35 = v126 and v86[181] or 14
local n36 = v126 and 56 or 60
local absoluteSize = arg._root.AbsoluteSize

if absoluteSize.X > 0 then
arg._panel.Size = UDim2.fromOffset(math.max(0, math.min(520, absoluteSize.X - n * 2)), 0)
end

local v127 = math.ceil(#arg._pages / 1)
local n37 = 0

if v127 > 0 then
n37 = v127 * n36 + (v127 - 1) * v86[133]
end

arg._routeLayout.FillDirectionMaxCells = 1
arg._routeLayout.CellSize = UDim2.new(1, 0, 0, n36)
arg._routes.Size = UDim2.new(1, v86[186], 0, n37)
local activePage = arg._activePage
local n38

if activePage == nil then
arg._hubContent.Position = UDim2.fromOffset(n34, n35)
arg._hubContent.Size = UDim2.new(1, -n34 * 2, 0, n37)
n38 = n37 + n35 * 2
else
n38 = activePage:_PrepareLayout(n34, n35)
end

local n39 = 0
local n40 = 1

if activePage ~= nil then
n39 = v126 and 46 or 50
n40 = 2
end

local n41 = arg._header.Root.AbsoluteSize.Y + n39 + n40
local n42 = math.max(0, absoluteSize.Y - n * v86[56] - n41)
local n43

if arg:_IsKeyboardVisible() then
local y = arg._root.AbsolutePosition.Y
n43 = math.min(n42, math.max(0, math.max(0, arg:_GetKeyboardTop() - y - 16) - n41))
else
n43 = n42
end

local n44 = 0

if not arg._isConfirming then
n44 = math.min(math.max(n33, n38), n43)
end

arg:_SetBodyHeight(n44, arg2 == true)

if activePage == nil then
arg._hubView.Body.CanvasSize = UDim2.fromOffset(0, n38)
arg._hubView.Body.ScrollBarThickness = n38 > n44 + v86[101] and v86[26] or 0
else
activePage:_SetViewport(n44, n38)
end
end

index3._SyncBounds = function(arg)
if arg._isDestroyed then
return
end
local v126 = v125.absoluteToLayerOffset(arg._menu:GetOverlayLayer(), arg._window.AbsolutePosition)
local absoluteSize = arg._window.AbsoluteSize
local floor2 = math.floor
local n = v126.Y + 0.5
arg._root.Position = UDim2.fromOffset(math.floor(v126.X + 0.5), floor2(n))
arg._root.Size = UDim2.fromOffset(math.floor(absoluteSize.X + v86[101]), math.floor(absoluteSize.Y + 0.5))
arg:_UpdateLayout()

if arg:_IsKeyboardVisible() then
arg:_SyncKeyboard()
end
end

index3._NotifyClosed = function(arg)
if arg._didNotifyClosed then
return
end
arg._didNotifyClosed = true
arg._onClosed()
end

index3._AcquireSelection = function(arg)
if arg._hasSelectionGroup then
return
end
arg._hasSelectionGroup = true
arg._previousSelectedObject = guiService.SelectedObject
arg._panel.SelectionGroup = true

if userInputService.GamepadEnabled then
guiService.SelectedObject = arg._closeButton
end
end

index3._ReleaseSelection = function(arg)
if not arg._hasSelectionGroup then
return
end
arg._hasSelectionGroup = false
arg._panel.SelectionGroup = false
local selectedObject = guiService.SelectedObject

if selectedObject ~= nil and selectedObject:IsDescendantOf(arg._panel) then
local previousSelectedObject = arg._previousSelectedObject

if previousSelectedObject ~= nil and previousSelectedObject.Parent ~= nil then
guiService.SelectedObject = previousSelectedObject
else
guiService.SelectedObject = nil
end
end

arg._previousSelectedObject = nil
end

index3._AnimateClosed = function(arg)
arg._menu:CloseOverlayDescendants(arg._entry)
local v126 = arg._menu:Tween(arg._root, { GroupTransparency = 1 })
arg._menu:Tween(arg._panel, { Position = arg:_ResolvePanelPosition(-15) })
if v126 == nil then
arg:Destroy()
return
end

arg._trove:Connect(v126.Completed, function()
arg:Destroy()
if not flag3 then
return
end
end)
end

index3._Open = function(arg)
if arg._isDestroyed or arg._isOpen then
return
end
arg._isOpen = true

task.defer(function()
if arg._isDestroyed or not arg._isOpen then
return
end
arg:_SyncBounds()
arg._hubView.Body.CanvasPosition = Vector2.zero
arg._root.GroupTransparency = 1
arg._panel.Position = arg:_ResolvePanelPosition(-15)
arg._menu:SetOverlayOpen(arg._entry, true)
arg:_AcquireSelection()
local v126 = arg:_ResolvePanelPosition(0)
local v127 = arg._menu:Tween(arg._root, { GroupTransparency = v86[186] })
local v128 = arg._menu:Tween(arg._panel, { Position = v126 })

if v127 == nil then
arg._root.GroupTransparency = v86[186]
end

if v128 == nil then
arg._panel.Position = v126
end

arg:_SyncRouteHover()
end)
end

index3.IsOpen = function(arg)
return arg._isOpen and not arg._isDestroyed
end

index3.Close = function(arg)
if not arg:IsOpen() then
return
end
arg._isOpen = v86[153]
arg:_ReleaseSelection()
arg:_NotifyClosed()
arg:_AnimateClosed()
end

index3.Destroy = function(arg)
if arg._isDestroyed then
return
end
arg._isDestroyed = true
arg._isOpen = false
arg:_NotifyClosed()
arg:_ReleaseSelection()
arg._trove:Destroy()
end

return index3
end

tbl17.ac = function()
local ac = tbl17.cache.ac

if not ac then
ac = { c = fn35() }
tbl17.cache.ac = ac
end

return ac.c
end
end
do -- ad
local function fn35()
local v115 = tbl17.b()
tbl17.a()
local index2 = {}
index2.__index = index2

index2.new = function()
local tbl18 = { _errors = {}, _sink = v115.get() }
setmetatable(tbl18, index2)
return tbl18
end

index2.Report = function(arg, arg2)
local errors = arg._errors

if #errors >= v86[137] then
table.remove(errors, v86[63])
end

table.insert(errors, arg2)
local sink = arg._sink

if sink ~= nil then
sink:Report(arg2)
end
end

index2.ReportResult = function(arg, arg2)
if not arg2.Ok then
arg:Report(arg2.Error)
end

return arg2
end

index2.GetErrors = function(arg)
return arg._errors
end

index2.Destroy = function(arg)
table.clear(arg._errors)
arg._sink = nil
end

return index2
end

tbl17.ad = function()
local ad = tbl17.cache.ad

if not ad then
local ad2 = { c = fn35() }
tbl17.cache.ad = ad2
ad = ad2
end

return ad.c
end
end
do -- ae
local function fn35()local I,W= tbl17 .f(), tbl17 .ad(); tbl17 .a(); tbl17 .r();local l={};l.__index=l;local N={AutoSave=false,AutoSaveConfigName=nil,AutoLoad=false,AutoLoadConfigName=nil,Keybind="RightShift",Size=nil,Position=nil,KeybindsListPosition=nil,WatermarkPosition=nil,MobileButtonPositions=nil,ShowKeybinds=nil,ShowWatermark=nil,MenuKeybindInList=nil,HideMobileMenuButton=nil,SilentLoad=nil};local function P(a)return(a:gsub("%.json$",""));end;local function a(e)if type(e)~="table"then return nil;end;local c,E=e[1],e[2];if type(c)~="number"or type(E)~="number"then return nil;end;if c~=c or E~=E then return nil;end;return{c,E};end;local function e(c)if type(c)~="table"then return nil;end;local E,p={},false;for T,t in c,nil,nil do if type(T)~="string"or T==""then continue;end;local c_26=a(t);if c_26==nil then continue;end;E[T]=c_26;p=true;end;return p and E or nil;end;local function c(E)local p=table.clone(N);if type(E)~="table"then return p;end;if type(E.AutoSave)=="boolean"then p.AutoSave=E.AutoSave;end;if type(E.AutoSaveConfigName)=="string"then p.AutoSaveConfigName=P(E.AutoSaveConfigName);end;if type(E.AutoLoad)=="boolean"then p.AutoLoad=E.AutoLoad;end;if type(E.AutoLoadConfigName)=="string"then p.AutoLoadConfigName=P(E.AutoLoadConfigName);end;if type(E.Keybind)=="string"then p.Keybind=E.Keybind;end;if type(E.ShowKeybinds)=="boolean"then p.ShowKeybinds=E.ShowKeybinds;end;if type(E.ShowWatermark)=="boolean"then p.ShowWatermark=E.ShowWatermark;end;if type(E.MenuKeybindInList)=="boolean"then p.MenuKeybindInList=E.MenuKeybindInList;end;if type(E.HideMobileMenuButton)=="boolean"then p.HideMobileMenuButton=E.HideMobileMenuButton;end;if type(E.SilentLoad)=="boolean"then p.SilentLoad=E.SilentLoad;end;p.Size=a(E.Size);p.Position=a(E.Position);p.KeybindsListPosition=a(E.KeybindsListPosition);p.WatermarkPosition=a(E.WatermarkPosition);p.MobileButtonPositions=e(E.MobileButtonPositions);return p;end;local function P_27(a)if type(a)~="table"then return{};end;local e=table.clone(a);a=e.autosave;e.autosave=nil;if type(a)=="string"then e.AutoSave=true;e.AutoSaveConfigName=a;end;a=e.autoload;e.autoload=nil;if type(a)=="string"then e.AutoLoad=true;e.AutoLoadConfigName=a;end;return e;end;local function a_28(e)if type(e)~="table"then return{};end;local E,p=table.clone(e),{"autoSave","autoSaveConfigName","autoLoad","autoLoadConfigName","keybind","size","position","keybindsListPosition","watermarkPosition","mobileButtonPositions","showKeybinds","showWatermark","menuKeybindInList","hideMobileMenuButton","silentLoad"};for T,T_29 in p,nil,nil do e=string.upper(string.sub(T_29,1,1))..string.sub(T_29,2);if E[e]==nil then E[e]=E[T_29];end;E[T_29]=nil;end;return E;end;l.new=function(e)return setmetatable({_errorReporter=W.new(),_manager=I.new({DefaultConfig=N,CurrentVersion=3,SavePath=e,Deserialize=c,Migrations={[1]=P_27,[2]=a_28}})},l);end;l.Load=function(I)if not I._manager:Exists("general")then return I._manager:Reset();end;local W=I._manager:LoadFromFile("general");if W.Ok then return W.Value;end;I._errorReporter:Report(W.Error);return I._manager:Reset();end;l.Save=function(I,W)I._manager:SetData(W);return I._errorReporter:ReportResult(I._manager:SaveToFile("general"));end;l.Destroy=function(I)I._errorReporter:Destroy();end;return l;end

tbl17.ae = function()
local ae = tbl17.cache.ae

if not ae then
ae = { c = fn35() }
tbl17.cache.ae = ae
end

return ae.c
end
end
do -- af
local function fn35()
tbl17.k()
local v115 = tbl17.ab()
tbl17.r()
local v116 = tbl17.v()
local v117 = tbl17.X()
tbl17.A()
local index2 = {}
index2.__index = index2

local function createScrollingFrame(arg, parent, arg2)
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.ScrollBarImageTransparency = 1
scrollingFrame.ScrollBarThickness = 0
scrollingFrame.Size = UDim2.fromScale(v86[63], v86[63])
scrollingFrame.Selectable = v86[153]
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollingFrame.BorderSizePixel = 0
scrollingFrame.CanvasSize = UDim2.new(v86[186], 0, 0, 0)
arg:Bind(scrollingFrame, "ScrollBarImageColor3", "Accent")
scrollingFrame.Parent = parent
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, v86[63])
uiPadding.PaddingBottom = UDim.new(0, 1)
uiPadding.PaddingRight = UDim.new(0, 1)
uiPadding.PaddingLeft = UDim.new(0, v86[63])
uiPadding.Parent = scrollingFrame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, arg2)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
uiListLayout.Parent = scrollingFrame
return scrollingFrame
end

index2.new = function(arg, parent, arg2, arg3, arg4, arg5)
local v118 = v116.get()
local columns = v86[56]

if arg4 ~= nil and arg4.Columns ~= nil then
columns = arg4.Columns
end

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
uiListLayout.Padding = UDim.new(v86[186], v118.Grid.Gap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.VerticalFlex = Enum.UIFlexAlignment.Fill
uiListLayout.Parent = parent
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Visible = false
scrollingFrame.ScrollBarImageTransparency = 1
scrollingFrame.ScrollBarThickness = 0
scrollingFrame.Size = UDim2.fromScale(1, 1)
scrollingFrame.Selectable = v86[153]
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollingFrame.BorderSizePixel = v86[186]
scrollingFrame.CanvasSize = UDim2.new(0, v86[186], v86[186], v86[186])
scrollingFrame.ZIndex = v86[56]
arg3:Bind(scrollingFrame, "ScrollBarImageColor3", "Accent")
scrollingFrame.Parent = parent
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 1)
uiPadding.PaddingBottom = UDim.new(0, 1)
uiPadding.PaddingRight = UDim.new(0, v86[63])
uiPadding.PaddingLeft = UDim.new(0, 1)
uiPadding.Parent = scrollingFrame
local uiListLayout2 = Instance.new("UIListLayout")
uiListLayout2.Padding = UDim.new(0, v118.Section.Gap)
uiListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout2.HorizontalFlex = Enum.UIFlexAlignment.Fill
uiListLayout2.Parent = scrollingFrame
local tbl18 = {}

for i = v86[63], columns do
table.insert(tbl18, createScrollingFrame(arg3, parent, v118.Section.Gap))
end

return setmetatable({
_trove = arg2,
_layoutTrove = arg2:Extend(),
_menu = arg,
_batch = arg3,
_parent = parent,
_effectiveColumns = columns,
Columns = columns,
_columns = tbl18,
_fullPage = scrollingFrame,
_items = {},
_realized = false,
_searchHost = arg5,
_hasFullSection = false,
_layoutQueued = false,
_columnCanvasPositions = {},
_fullCanvasPosition = Vector2.zero,
}, index2)
end

index2._SetMode = function(arg, visible)
if arg._fullPage.Visible == visible then
return
end

if arg._fullPage.Visible then
arg._fullCanvasPosition = arg._fullPage.CanvasPosition
else
for k, v118 in arg._columns, nil, nil do
arg._columnCanvasPositions[k] = v118.CanvasPosition
end
end

arg._fullPage.Visible = visible

for k, v118 in arg._columns, nil, nil do
local visible2 = not visible
v118.Visible = visible2

if visible2 then
v118.CanvasPosition = arg._columnCanvasPositions[k] or Vector2.zero
end
end

if visible then
arg._fullPage.CanvasPosition = arg._fullCanvasPosition
end
end

index2._ResolveColumnCount = function(arg)
if arg._hasFullSection or arg.Columns <= 1 then
return 1
end
local x = arg._parent.AbsoluteSize.X
if x <= 0 then
return arg.Columns
end
local v118 = v116.get()
local gap = v118.Grid.Gap
local n = math.max(1, math.floor((x + gap) / (v118.Grid.MinColumnWidth + gap)))
return math.min(arg.Columns, n)
end

index2._ParentForSide = function(arg, arg2)
if arg._effectiveColumns == 1 or arg2 == "full" then
return arg._fullPage
end

if arg2 == "right" and arg._effectiveColumns >= 2 then
return arg._columns[2]
end
return arg._columns[1]
end

index2._ApplyResponsiveLayout = function(arg)
local v118 = arg:_ResolveColumnCount()
arg._effectiveColumns = v118
arg:_SetMode(v118 == 1)

for k, v119 in arg._items, nil, nil do
v119.Reparent(arg:_ParentForSide(v119.Side), k)
end
end

index2.ColumnParent = function(arg, arg2)
return arg:_ParentForSide(arg2)
end

index2.AddSection = function(arg, arg2)
if arg2.Side == "full" then
arg._hasFullSection = true
end

local v118 = v115.BuildSection(arg._menu, arg._trove, arg2, function()
return arg:ColumnParent(arg2.Side)
end)

arg:_RegisterItem(arg2.Side, function()
v118:Realize()
end, function(arg3, arg4)
v118:_SetGridParent(arg3, arg4)
end)

arg._menu:RegisterSearchSection(arg._searchHost, v118, function(arg3, arg4, arg5)
v118:CollectSearchHits(arg3, arg4, arg5)
end)

return v118
end

index2.AddMultiSection = function(arg, arg2)
if arg2.Side == "full" then
arg._hasFullSection = true
end

local v118 = v115.BuildPanes(arg._menu, arg._trove, arg2.Titles)

local v119 = v117.new(arg._menu, arg._trove, v118, function()
return arg:ColumnParent(arg2.Side)
end)

arg:_RegisterItem(arg2.Side, function()
v119:Realize()
end, function(arg3, arg4)
v119:_SetGridParent(arg3, arg4)
end)

for k, v120 in v118, nil, nil do
arg._menu:RegisterSearchSection(arg._searchHost, v120, function(arg3, arg4, arg5)
v120:CollectSearchHits(arg3, arg4, arg5, { Reveal = function()
v119:SelectPane(k)
end })
end)
end

return table.unpack(v118)
end

index2._RegisterItem = function(arg, arg2, arg3, arg4)
table.insert(arg._items, { Side = arg2, Realize = arg3, Reparent = arg4 })

if arg._realized then
arg3()
arg:_ApplyResponsiveLayout()
end
end

index2.Register = function(arg, arg2)
arg:_RegisterItem(nil, arg2, function()
end)
end

index2.Realize = function(arg)
if arg._realized then
return
end
arg._effectiveColumns = arg:_ResolveColumnCount()
arg:_SetMode(arg._effectiveColumns == v86[63])
arg._realized = true

for _, v118 in arg._items, nil, nil do
v118.Realize()
end

arg:_ApplyResponsiveLayout()

arg._trove:Connect(arg._parent:GetPropertyChangedSignal(v86[131]), function()
if arg._layoutQueued then
return
end
arg._layoutQueued = true
arg._layoutTrove:Clean()

arg._layoutTrove:Add(task.defer(function()
arg._layoutQueued = v86[153]
arg:_ApplyResponsiveLayout()
end))
end)
end

return index2
end

tbl17.af = function()
local af = tbl17.cache.af

if not af then
local af2 = { c = fn35() }
tbl17.cache.af = af2
af = af2
end

return af.c
end
end
do -- ag
local function fn35() tbl17 .k();local I= tbl17 .t();local l,W,N,P=I.UserInputService,I.RunService,I.HttpService,{};P.__index=P;P.new=function(I)return setmetatable({_trove=I,_unlocked=false,_textbox=nil,_binding=nil,_oldMouseIconEnabled=nil},P);end;local function I_30(a)local e=a._textbox;if e~=nil then return e;end;e=Instance.new("TextBox");a._textbox=e;a._trove:Add(e);return e;end;P.Set=function(a,e)if a._unlocked==e then return;end;a._unlocked=e;if not l.KeyboardEnabled then return;end;if e then local e_31=I_30(a);a._oldMouseIconEnabled=l.MouseIconEnabled;local I=N:GenerateGUID(false);a._binding=I;W:BindToRenderStep(I,Enum.RenderPriority.Camera.Value+1,function()if not l.MouseIconEnabled then a._oldMouseIconEnabled=l.MouseIconEnabled;l.MouseIconEnabled=true;end;local f=l:GetFocusedTextBox();if f==nil or f==e_31 then e_31:CaptureFocus();end;end);else if a._binding~=nil then W:UnbindFromRenderStep(a._binding);a._binding=nil;end;if a._oldMouseIconEnabled~=nil then l.MouseIconEnabled=a._oldMouseIconEnabled;a._oldMouseIconEnabled=nil;end;if a._textbox~=nil then a._textbox:ReleaseFocus(false);end;end;end;P.Destroy=function(l)l:Set(false);end;return P;end

tbl17.ag = function()
local ag = tbl17.cache.ag

if not ag then
ag = { c = fn35() }
tbl17.cache.ag = ag
end

return ag.c
end
end
do -- ah
local function fn35()local I= tbl17 .k(); tbl17 .r();local W,N= tbl17 .t().UserInputService,{};N.__index=N;N.new=function(l)local P=I.new();local I={_trove=P,_captureTrove=P:Extend(),_active=nil,_pending=nil,_generation=0,_deliveryTrove=P:Extend(),_capturedInputSet={}};setmetatable(I._capturedInputSet,{__mode="k"});P=setmetatable(I,N);l:Add(P);return P;end;N.ShouldBlockMenuToggle=function(l,I)return l._active~=nil or l._capturedInputSet[I]==true;end;N.Begin=function(l,I)l:Cancel();l._generation=l._generation+1;local P=l._generation;l._active=I;l._captureTrove:Connect(W.InputBegan,function(I,W)if I.UserInputType==Enum.UserInputType.Touch then l:Cancel();return;end;local a=I.UserInputType;local e,c=a==Enum.UserInputType.Keyboard,a==Enum.UserInputType.MouseButton1 or a==Enum.UserInputType.MouseButton2 or a==Enum.UserInputType.MouseButton3;if not e and not c then return;end;c=e and I.KeyCode==Enum.KeyCode.Escape;if e and not c and W then return;end;local W_32=l._active;l:_Disarm();if W_32==nil then return;end;local E="None";if not c then if e then E=I.KeyCode;else E=a;end;end;l._capturedInputSet[I]=true;l._pending=W_32;l._deliveryTrove:Add(task.defer(function()if l._generation~=P or l._pending~=W_32 then return;end;l._pending=nil;l._capturedInputSet[I]=nil;W_32(E);end));end);return function()if l._generation==P then l:Cancel();end;end;end;N._Disarm=function(l)l._captureTrove:Clean();l._active=nil;end;N.Cancel=function(l)local I=l._active or l._pending;l._generation=l._generation+1;l._deliveryTrove:Clean();l:_Disarm();l._pending=nil;table.clear(l._capturedInputSet);if I~=nil then I(nil);end;end;N.Destroy=function(l)l:Cancel();l._trove:Destroy();end;return N;end

tbl17.ah = function()
local ah = tbl17.cache.ah

if not ah then
ah = { c = fn35() }
tbl17.cache.ah = ah
end

return ah.c
end
end
do -- ai
local function fn35()
tbl17.k()
tbl17.r()
local v115 = tbl17.u()
local v116 = tbl17.A()
local v117 = tbl17.w()
local tweenInfo = TweenInfo.new(v86[28], Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2)
return arg._enabled and arg2.Enabled
end

local function fn37(arg, arg2, visible)
local row = arg2.Row
if row == nil then
return
end
local outline = row.Outline
local fadeTween = row.FadeTween

if fadeTween ~= nil then
fadeTween:Cancel()
row.FadeTween = nil
end

local udim2 = UDim2.fromScale(1, 0)
local n = v86[63]

if visible then
udim2 = UDim2.new(v86[63], v86[186], 0, 22)
outline.Visible = v86[34]
n = 0
end

local v118 = arg._menu:Tween(outline, { Size = udim2, GroupTransparency = n }, tweenInfo)
row.FadeTween = v118
if v118 == nil then
outline.Visible = visible
return
end

if not visible then
v118.Completed:Once(function(playbackState)
if playbackState == Enum.PlaybackState.Completed then
outline.Visible = v86[153]
end
end)
end
end

local function fn38(arg)
local row = arg.Row
if row == nil then
return
end

if arg.Active then
row.Label.TextColor3 = v116.get("TextColor")
row.Label.TextTransparency = 0
row.ModeText.TextColor3 = v116.get("Accent")
row.ModeText.TextTransparency = 0
else
row.Label.TextColor3 = v116.get(v86[96])
row.Label.TextTransparency = v86[126]
row.ModeText.TextColor3 = v116.get("Unselected")
row.ModeText.TextTransparency = 0.25
end
end

local function fn39(arg, arg2)
local main = arg._menu.Fonts.Main
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.Visible = false
canvasGroup.GroupTransparency = 1
canvasGroup.BackgroundTransparency = 1
canvasGroup.BorderSizePixel = 0
canvasGroup.Size = UDim2.fromScale(1, 0)
canvasGroup.Parent = arg._rows
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Size = UDim2.fromScale(1, 1)
frame.Parent = canvasGroup
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 10)
uiListLayout.Parent = frame
local instance = Instance.new(v86[135])
instance.TextTransparency = v86[186]
instance.Text = arg2.KeyText
instance.BackgroundTransparency = 1
instance.BorderSizePixel = 0
instance.Size = UDim2.new(0, v86[163], 1, v86[186])
instance.TextXAlignment = Enum.TextXAlignment.Left
instance.TextSize = 12
instance.LayoutOrder = v86[186]
instance.FontFace = main
arg._batch:Bind(instance, "TextColor3", "Accent")
instance.Parent = frame
local instance2 = Instance.new(v86[135])
instance2.Text = arg2.Label
instance2.BackgroundTransparency = 1
instance2.BorderSizePixel = 0
instance2.Size = UDim2.fromScale(v86[186], 1)
instance2.TextXAlignment = Enum.TextXAlignment.Left
instance2.TextTruncate = Enum.TextTruncate.AtEnd
instance2.TextSize = 12
instance2.LayoutOrder = v86[63]
instance2.FontFace = main
instance2.Parent = frame
local uiFlexItem = Instance.new("UIFlexItem")
uiFlexItem.FlexMode = Enum.UIFlexMode.Fill
uiFlexItem.Parent = instance2
local instance3 = Instance.new(v86[135])
instance3.Text = arg2.Mode
instance3.BackgroundTransparency = 1
instance3.BorderSizePixel = 0
instance3.AutomaticSize = Enum.AutomaticSize.X
instance3.Size = UDim2.fromScale(0, v86[63])
instance3.TextXAlignment = Enum.TextXAlignment.Right
instance3.TextSize = v86[133]
instance3.LayoutOrder = 2
instance3.FontFace = main
instance3.Parent = frame
arg2.Row = { Outline = canvasGroup, KeyText = instance, Label = instance2, ModeText = instance3, FadeTween = nil }
fn38(arg2)
end

local function fn40()
local v118 = v86[84]
return UDim2.fromOffset(50, math.min(v86[198], math.floor(v117.currentViewportSize().Y * v118)))
end

local function fn41(arg, arg2)
arg:Add(task.defer(function()
if arg2.Parent ~= nil then
v117.clampGuiToViewport(arg2)
end
end))

arg:Add(task.defer(function()
if arg2.Parent ~= nil then
v117.clampGuiToViewport(arg2)
end
end))
end

local function fn42(arg, arg2, parent, arg3)
local main = arg.Fonts.Main
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.GroupTransparency = 0
canvasGroup.BackgroundTransparency = 1
canvasGroup.Position = fn40()
canvasGroup.BorderSizePixel = v86[186]
canvasGroup.AutomaticSize = Enum.AutomaticSize.XY
canvasGroup.Parent = parent
arg3:Add(canvasGroup)
arg:MakeDraggable(canvasGroup, arg3, { PersistKey = "KeybindsListPosition" })

if v115.Scale ~= v86[63] then
local uiScale = Instance.new("UIScale")
uiScale.Scale = v115.Scale
uiScale.Parent = canvasGroup
end

local canvasGroup2 = Instance.new("CanvasGroup")
canvasGroup2.BackgroundTransparency = 0.06
canvasGroup2.BorderSizePixel = v86[186]
canvasGroup2.Size = UDim2.fromOffset(234, 0)
canvasGroup2.AutomaticSize = Enum.AutomaticSize.Y
canvasGroup2.GroupTransparency = v86[63]
canvasGroup2.Visible = false
arg2:Bind(canvasGroup2, "BackgroundColor3", "GradientDark")
canvasGroup2.Parent = canvasGroup
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = canvasGroup2
local uiStroke = Instance.new("UIStroke")
uiStroke.Transparency = v86[87]
uiStroke.Thickness = 1
arg2:Bind(uiStroke, v86[27], "Outline")
uiStroke.Parent = canvasGroup2
local frame = Instance.new("Frame")
frame.BorderSizePixel = 0
frame.Position = UDim2.fromScale(v86[186], 0)
frame.Size = UDim2.new(0, v86[56], 1, 0)
arg2:Bind(frame, v86[5], "Accent")
frame.Parent = canvasGroup2
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = 1
frame2.BorderSizePixel = 0
frame2.Position = UDim2.fromOffset(2, 0)
frame2.Size = UDim2.new(1, -2, 0, v86[186])
frame2.AutomaticSize = Enum.AutomaticSize.Y
frame2.Parent = canvasGroup2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(v86[186], v86[162])
uiPadding.PaddingBottom = UDim.new(v86[186], 9)
uiPadding.PaddingLeft = UDim.new(0, 12)
uiPadding.PaddingRight = UDim.new(0, 12)
uiPadding.Parent = frame2
local instance = Instance.new(v86[4])
instance.SortOrder = Enum.SortOrder.LayoutOrder
instance.Padding = UDim.new(0, v86[54])
instance.Parent = frame2
local textLabel = Instance.new("TextLabel")
textLabel.Text = "KEYBINDS"
textLabel.BackgroundTransparency = 1
textLabel.Size = UDim2.new(1, 0, 0, 12)
textLabel.BorderSizePixel = 0
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextSize = 10
textLabel.LayoutOrder = 0
textLabel.FontFace = main
arg2:Bind(textLabel, v86[167], "Unselected")
textLabel.Parent = frame2
local instance2 = Instance.new(v86[128])
instance2.BackgroundTransparency = v86[63]
instance2.Size = UDim2.fromScale(v86[63], v86[186])
instance2.AutomaticSize = Enum.AutomaticSize.Y
instance2.BorderSizePixel = 0
instance2.LayoutOrder = 1
instance2.Parent = frame2
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 1)
uiListLayout.Parent = instance2
return canvasGroup, canvasGroup2, instance2
end

index2.new = function(arg, arg2, arg3)
local v118 = arg3:Extend()
local v119 = v116.newBatch(v118)
local stateData = arg:GetStateData()
local flag19 = stateData ~= nil and stateData.ShowKeybinds == false
local flag20 = true

if flag19 then
flag20 = false
end

local v120, v121, v122 = fn42(arg, v119, arg2, v118)

local obj = setmetatable({
_trove = v118,
_menu = arg,
_batch = v119,
_entries = {},
_group = v120,
_card = v121,
_rows = v122,
_enabled = flag20,
_cardFadeState = { Tweening = false },
}, index2)

v119:BindStateful("Accent", function()
for _, v123 in obj._entries, nil, nil do
fn38(v123)
end
end)

v119:BindStateful("Unselected", function()
for _, v123 in obj._entries, nil, nil do
fn38(v123)
end
end)

if flag20 then
arg:FadeCanvasGroup(obj._card, true, obj._cardFadeState)
fn41(obj._trove, obj._group)
end

return obj
end

index2.SetEnabled = function(arg, enabled)
if arg._enabled == enabled then
return
end
arg._enabled = enabled

for _, v118 in arg._entries, nil, nil do
fn37(arg, v118, fn36(arg, v118))
end

arg._menu:FadeCanvasGroup(arg._card, enabled, arg._cardFadeState)

if enabled then
fn41(arg._trove, arg._group)
end

local stateData = arg._menu:GetStateData()

if stateData ~= nil then
stateData.ShowKeybinds = enabled
arg._menu:SaveState()
end
end

index2.IsEnabled = function(arg)
return arg._enabled
end

index2.AddEntry = function(arg)
local tbl18 = {
Label = v86[73],
KeyText = "NONE",
Mode = "TOGGLE",
Active = v86[153],
Enabled = false,
Row = nil,
}

table.insert(arg._entries, tbl18)

return {
SetLabel = function(arg2, label)
tbl18.Label = label
local row = tbl18.Row

if row ~= nil then
row.Label.Text = label
end
end,
SetKeyText = function(arg2, arg3)
tbl18.KeyText = arg3:upper()
local row = tbl18.Row

if row ~= nil then
row.KeyText.Text = tbl18.KeyText
end
end,
SetMode = function(arg2, arg3)
tbl18.Mode = arg3:upper()
local row = tbl18.Row

if row ~= nil then
row.ModeText.Text = tbl18.Mode
end
end,
SetActiveAppearance = function(arg2, active)
tbl18.Active = active
fn38(tbl18)
end,
SetEnabled = function(arg2, enabled)
if tbl18.Enabled == enabled then
return
end
tbl18.Enabled = enabled

if enabled and tbl18.Row == nil then
fn39(arg, tbl18)
end

fn37(arg, tbl18, fn36(arg, tbl18))
end,
Destroy = function()
local v118 = table.find(arg._entries, tbl18)

if v118 ~= nil then
table.remove(arg._entries, v118)
end

local row = tbl18.Row

if row ~= nil then
tbl18.Row = nil
row.Outline:Destroy()
end
end,
}
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.ai = function()
local ai = tbl17.cache.ai

if not ai then
ai = { c = fn35() }
tbl17.cache.ai = ai
end

return ai.c
end
end
do -- aj
local function fn35()
tbl17.k()
tbl17.r()
local v115 = tbl17.s()
local v116 = tbl17.x()
local v117 = tbl17.t()
local v118 = tbl17.A()
local v119 = tbl17.w()
local userInputService = v117.UserInputService
local index2 = {}
index2.__index = index2

local function fn36(arg)
local rt = arg.Rt

if rt ~= nil and rt.Instance.Parent ~= nil then
v119.clampGuiToViewport(rt.Instance)
end
end

index2.new = function(arg, arg2, arg3)
local obj = setmetatable({
_trove = arg3:Extend(),
_menu = arg,
_parent = arg2,
_buttonByFlag = {},
_buttonCount = 0,
_isDragMode = false,
}, index2)

local v120 = obj._trove:Extend()

v119.connectCurrentCameraViewport(obj._trove, function(arg4)
v120:Clean()
if arg4 == nil then
return
end

v120:Add(task.defer(function()
for _, v121 in obj._buttonByFlag, nil, nil do
fn36(v121)
end
end))
end)

return obj
end

local function fn37(arg, arg2)
local rt = arg2.Rt
if rt == nil then
return
end
local str7 = "Background"

if arg2.Active then
str7 = "Accent"
end

arg:Tween(rt.Instance, { BackgroundColor3 = v118.get(str7) })
end

local function fn38(arg)
return arg.Visible and arg.Mode ~= "Always"
end

local function fn39(arg, arg2)
local rt = arg.Rt
if rt == nil then
return
end
local backgroundTransparency = v86[186]

if arg.Invisible and not arg2 then
backgroundTransparency = 1
end

rt.Instance.BackgroundTransparency = backgroundTransparency
rt.Label.TextTransparency = backgroundTransparency
rt.Stroke.Transparency = backgroundTransparency
end

local function fn40(arg)
local v120 = v119.currentViewportSize()
local n = math.min(300, math.floor(v120.Y * 0.45))
local v121 = v86[63]
local n33 = math.max(v86[63], math.floor((v120.Y - n - v86[143]) / 44) + v121)
return UDim2.fromOffset(20 + math.floor(arg / n33) * 140, n + arg % n33 * 44)
end

local function fn41(arg, arg2)
local rt = arg2.Rt
if rt ~= nil then
return rt
end
local menu = arg._menu
local v120 = v118.newBatch(arg2.Trove)
local udim2 = fn40(arg2.Slot)
local stateData = menu:GetStateData()

if stateData ~= nil and stateData.MobileButtonPositions ~= nil then
local v121 = stateData.MobileButtonPositions[arg2.Flag]

if v121 ~= nil and #v121 >= 2 then
udim2 = UDim2.fromOffset(v121[1], v121[2])
end
end

local textButton = Instance.new("TextButton")
textButton.Position = udim2
textButton.Size = UDim2.fromOffset(0, v86[143])
textButton.AutomaticSize = Enum.AutomaticSize.X
textButton.BorderSizePixel = 0
textButton.AutoButtonColor = v86[153]
textButton.Text = ""
textButton.Active = true
textButton.Visible = fn38(arg2)
v120:Bind(textButton, "BackgroundColor3", "Background")
textButton.Parent = arg._parent
arg2.Trove:Add(textButton)
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[175])
uiCorner.Parent = textButton
local instance = Instance.new(v86[85])
instance.Thickness = v86[63]
instance.BorderOffset = UDim.new(0, -1)
instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
v120:Bind(instance, "Color", "Outline")
instance.Parent = textButton
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingLeft = UDim.new(0, 14)
uiPadding.PaddingRight = UDim.new(0, 14)
uiPadding.Parent = textButton
local instance2 = Instance.new(v86[135])
instance2.BackgroundTransparency = 1
instance2.Size = UDim2.fromOffset(v86[186], 36)
instance2.AutomaticSize = Enum.AutomaticSize.X
instance2.Text = arg2.LabelText
instance2.FontFace = v115.Medium
instance2.TextSize = 14
instance2.BorderSizePixel = 0
v120:Bind(instance2, "TextColor3", "TextColor")
instance2.Parent = textButton
local rt2 = { Instance = textButton, Label = instance2, Stroke = instance }
arg2.Rt = rt2

if arg2.Active then
textButton.BackgroundColor3 = v118.get("Accent")
end

fn39(arg2, arg._isDragMode)
arg2.Trove:Add(task.defer(fn36, arg2))
arg2.Trove:Add(task.defer(fn36, arg2))

v116.connectPress(arg2.Trove, textButton, function()
if arg._isDragMode then
return
end

if arg2.Mode == "Hold" then
arg2.Active = true
fn37(menu, arg2)
arg2.OnActivate(v86[34])
elseif arg2.Mode == "Toggle" or arg2.Mode == "Tap" then
arg2.Active = not arg2.Active
fn37(menu, arg2)
arg2.OnActivate(arg2.Active)
end
end, function()
if arg._isDragMode then
return
end

if arg2.Mode == "Hold" then
arg2.Active = false
fn37(menu, arg2)
arg2.OnActivate(false)
end
end)

return rt2
end

local function fn42(arg, arg2)
local v120 = fn38(arg2)

if v120 and arg2.Rt == nil then
fn41(arg, arg2)
end

local rt = arg2.Rt

if rt ~= nil then
rt.Instance.Visible = v120
end
end

index2.Register = function(arg, arg2, arg3, arg4, arg5)
local v120 = arg._buttonByFlag[arg2]

if v120 ~= nil then
v120.Trove:Destroy()
arg._buttonByFlag[arg2] = nil
end

local tbl18 = {
Flag = arg2,
Slot = arg._buttonCount,
Mode = arg4,
Active = false,
Visible = true,
Invisible = false,
LabelText = arg3,
Trove = arg._trove:Extend(),
OnActivate = arg5,
Rt = nil,
}

arg._buttonByFlag[arg2] = tbl18
arg._buttonCount = arg._buttonCount + 1

tbl18.Trove:Add(task.defer(function()
if arg._buttonByFlag[arg2] == tbl18 then
fn42(arg, tbl18)
end
end))

return {
SetActive = function(arg6, active)
tbl18.Active = active
fn37(arg._menu, tbl18)
end,
SetMode = function(arg6, mode)
tbl18.Mode = mode
fn42(arg, tbl18)
end,
SetLabel = function(arg6, labelText)
tbl18.LabelText = labelText
local rt = tbl18.Rt

if rt ~= nil then
rt.Label.Text = labelText
end
end,
SetVisible = function(arg6, visible)
tbl18.Visible = visible
fn42(arg, tbl18)
end,
SetInvisible = function(arg6, invisible)
tbl18.Invisible = invisible
fn39(tbl18, arg._isDragMode)
end,
Destroy = function()
if arg._buttonByFlag[arg2] == tbl18 then
arg._buttonByFlag[arg2] = nil
end

tbl18.Trove:Destroy()
end,
}
end

index2.EnterDragMode = function(arg, arg2)
arg._isDragMode = v86[34]
local menu = arg._menu
local textButton = Instance.new("TextButton")
textButton.AnchorPoint = Vector2.new(v86[101], 0)
textButton.Position = UDim2.new(0.5, 0, 0, 40)
textButton.Size = UDim2.fromOffset(140, 40)
textButton.BackgroundColor3 = v118.get("Accent")
textButton.BorderSizePixel = 0
textButton.Text = "Done"
textButton.FontFace = v115.Medium
textButton.TextSize = 16
textButton.TextColor3 = Color3.fromRGB(255, 255, 255)
textButton.AutoButtonColor = false
textButton.Parent = arg._parent
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = textButton
local v120 = arg._trove:Extend()

for _, v121 in arg._buttonByFlag, nil, nil do
fn39(v121, v86[34])
local rt = v121.Rt

if rt ~= nil then
menu:Tween(rt.Stroke, { Thickness = 2 })
end
end

local v121 = nil
local v122 = nil
local position = nil
local position2 = nil

for _, v123 in arg._buttonByFlag, nil, nil do
local rt = v123.Rt

if rt ~= nil then
v120:Connect(rt.Instance.InputBegan, function(arg3)
local userInputType = arg3.UserInputType
if userInputType ~= Enum.UserInputType.Touch and userInputType ~= Enum.UserInputType.MouseButton1 then
return
end
v121 = v123
v122 = arg3
position = arg3.Position
position2 = rt.Instance.Position
end)
end
end

v120:Connect(userInputService.InputChanged, function(arg3)
local v123 = v121
local v124 = position
local v125 = position2
if v123 == nil or v124 == nil or v125 == nil then
return
end
local rt = v123.Rt
if rt == nil then
return
end

if not v119.matchesPointerDrag(arg3, v122, Enum.UserInputType.MouseMovement) then
return
end
local n = arg3.Position - v124
rt.Instance.Position = UDim2.fromOffset(v125.X.Offset + n.X, v125.Y.Offset + n.Y)
v119.clampGuiToViewport(rt.Instance)
end)

v120:Connect(userInputService.InputEnded, function(arg3)
if v121 == nil then
return
end

if not v119.matchesPointerDrag(arg3, v122, Enum.UserInputType.MouseButton1) then
return
end
v121 = nil
v122 = nil
position = nil
position2 = nil
end)

v120:Connect(textButton.Activated, function()
arg:_ExitDragMode()

for _, v123 in arg._buttonByFlag, nil, nil do
fn39(v123, false)
local rt = v123.Rt

if rt ~= nil then
menu:Tween(rt.Stroke, { Thickness = 1 })
end
end

textButton:Destroy()
v120:Destroy()
arg2()
end)
end

index2._ExitDragMode = function(arg)
arg._isDragMode = false
local stateData = arg._menu:GetStateData()
if stateData == nil then
return
end
local mobileButtonPositions = stateData.MobileButtonPositions or {}

for k, v120 in arg._buttonByFlag, nil, nil do
local rt = v120.Rt

if rt ~= nil then
local position = rt.Instance.Position
mobileButtonPositions[k] = { position.X.Offset, position.Y.Offset }
end
end

stateData.MobileButtonPositions = mobileButtonPositions
arg._menu:SaveState()
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.aj = function()
local aj = tbl17.cache.aj

if not aj then
aj = { c = fn35() }
tbl17.cache.aj = aj
end

return aj.c
end
end
do -- ak
local function fn35()
tbl17.g()
tbl17.k()
tbl17.r()
local userInputService = tbl17.t().UserInputService
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2, arg3)
local obj = setmetatable({
_trove = arg,
_layer = arg2,
_entries = {},
_blocker = nil,
_lastHandledInput = nil,
_onBeforeOpen = nil,
}, index2)

arg:Connect(userInputService.InputBegan, function(arg4, arg5)
local userInputType = arg4.UserInputType
local blocker = obj._blocker
local flag19 = blocker ~= nil and blocker.Parent ~= nil and blocker.Visible == v86[34]
if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.MouseButton2 and userInputType ~= Enum.UserInputType.Touch then
return
end

if arg5 and not flag19 then
return
end

obj:_HandlePointerInput(arg4, flag19 and not arg5)
end)

arg:Connect(arg3, function(arg4)
if not arg4 then
for _, v115 in obj._entries, nil, nil do
if v115.Open then
v115.Open = v86[153]
v115.Root.Visible = false
end
end

obj:_UpdateBlocker()
end
end)

return obj
end

index2._HandlePointerInput = function(arg, lastHandledInput, arg2)
if arg._lastHandledInput == lastHandledInput then
return
end
arg._lastHandledInput = lastHandledInput

task.defer(function()
if arg._lastHandledInput == lastHandledInput then
arg._lastHandledInput = nil
end
end)

local position = lastHandledInput.Position
local v115, v116 = arg:_FindHit(position, arg2 == v86[34])

if v115 then
if v116 then
arg:Toggle(v115)
return
end
local tbl18 = {}
local v117 = v86[153]

for _, v118 in arg._entries, nil, nil do
if v118 ~= v115 and arg:_IsDescendantOf(v118, v115) then
local v119 = v86[153]

for _, v120 in v118.Triggers, nil, nil do
if arg:_ContainsPoint(v120, position) then
v119 = v86[34]
break
end
end

if v119 then
v117 = v86[34]
elseif v118.Open and v118.CloseOnOutside and not arg:_ContainsPoint(v118.Root, position) then
table.insert(tbl18, v118)
end
end
end

for _, v118 in tbl18, nil, nil do
if v118.Open then
arg:_Apply(v118, false)
end
end

if not v117 then
arg:BringToFront(v115)
end

return
end

arg:CloseAll(nil, v86[153])
end

index2._EnsureBlocker = function(arg)
if arg._blocker ~= nil then
if arg._blocker.Parent ~= nil then
return arg._blocker
end
return nil
end

local textButton = Instance.new("TextButton")
textButton.Name = "\0"
textButton.Active = true
textButton.Visible = v86[153]
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.fromScale(v86[63], 1)
textButton.BorderSizePixel = 0
textButton.ZIndex = v86[186]
textButton.Text = ""
textButton.Parent = arg._layer

arg._trove:Connect(textButton.InputBegan, function(arg2)
local userInputType = arg2.UserInputType
if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.MouseButton2 and userInputType ~= Enum.UserInputType.Touch then
return
end
arg:_HandlePointerInput(arg2)
end)

arg._blocker = textButton
return textButton
end

index2._UpdateBlocker = function(arg)
local v115 = arg:_EnsureBlocker()
if v115 == nil then
return
end
local visible = false

for _, v116 in arg._entries, nil, nil do
if v116.Open then
visible = true
break
end
end

v115.Visible = visible
end

index2.SetBeforeOpen = function(arg, onBeforeOpen)
arg._onBeforeOpen = onBeforeOpen
end

index2.Register = function(arg, arg2, arg3)
local triggers = arg3 ~= nil and arg3.Triggers or {}
local parentEntry = arg3 ~= nil and arg3.ParentEntry or nil
local onToggle = arg3 ~= nil and arg3.OnToggle or nil
local flag19 = arg3 ~= nil and arg3.Open == true
local flag20 = arg3 == nil or arg3.CloseOnOutside ~= false

if parentEntry == nil then
local parent

if triggers[1] ~= nil then
parent = triggers[1].Parent
else
parent = arg2.Parent
end

while parent ~= nil do
for _, v115 in arg._entries, nil, nil do
if v115.Root == parent then
parentEntry = v115
break
end
end

if parentEntry == nil then
parent = parent.Parent
continue
end
break
end
end

local tbl18 = {
Root = arg2,
Parent = arg2.Parent,
ParentEntry = parentEntry,
Triggers = triggers,
OnToggle = onToggle,
Open = flag19 or arg2.Visible == true,
CloseOnOutside = flag20,
}

table.insert(arg._entries, tbl18)
arg:_UpdateBlocker()
return tbl18
end

index2.Unregister = function(arg, arg2)
local v115 = table.find(arg._entries, arg2)

if v115 ~= nil then
table.remove(arg._entries, v115)
end

arg:_UpdateBlocker()
end

index2._ContainsPoint = function(arg, arg2, arg3)
if arg2.Visible ~= v86[34] then
return v86[153]
end
local absolutePosition = arg2.AbsolutePosition
local absoluteSize = arg2.AbsoluteSize
return arg3.X >= absolutePosition.X and arg3.X <= absolutePosition.X + absoluteSize.X and arg3.Y >= absolutePosition.Y and arg3.Y <= absolutePosition.Y + absoluteSize.Y
end

index2._FindHit = function(arg, arg2, arg3)
for i = #arg._entries, 1, -1 do
local v115 = arg._entries[i]
if v115.Open and arg:_ContainsPoint(v115.Root, arg2) then
return v115, false
end

if v115.Open or arg3 == true then
for _, v116 in v115.Triggers, nil, nil do
if arg:_ContainsPoint(v116, arg2) then
return v115, true
end
end
end
end

return nil, v86[153]
end

index2._Apply = function(arg, arg2, open)
if not open then
for _, v115 in arg._entries, nil, nil do
if v115.ParentEntry == arg2 and v115.Open then
arg:_Apply(v115, false)
end
end
end

if open then
local onBeforeOpen = arg._onBeforeOpen

if onBeforeOpen ~= nil then
onBeforeOpen()
end
end

arg2.Open = open
local onToggle = arg2.OnToggle

if type(onToggle) == "function" then
onToggle(open)
arg:_UpdateBlocker()
return
end

arg2.Root.Visible = open
arg:_UpdateBlocker()
end

index2._IsDescendantOf = function(arg, arg2, arg3)
local parentEntry = arg2.ParentEntry

while parentEntry do
if parentEntry == arg3 then
return true
end
parentEntry = parentEntry.ParentEntry
end

return false
end

index2._IsRelated = function(arg, arg2, arg3)
return arg2 == arg3 or arg:_IsDescendantOf(arg2, arg3) or arg:_IsDescendantOf(arg3, arg2)
end

index2.BringToFront = function(arg, arg2)
local root = arg2.Root
local parent = root.Parent or arg2.Parent
if parent == nil then
return
end

if root.Parent == parent then
local focusedTextBox = userInputService:GetFocusedTextBox()
if focusedTextBox ~= nil and focusedTextBox:IsDescendantOf(root) then
return
end
root.Parent = nil
end

root.Parent = parent
arg2.Parent = parent
end

index2.CloseAll = function(arg, arg2, arg3)
for _, v115 in arg._entries, nil, nil do
if v115.Open and v115 ~= arg2 and (arg2 == nil or not arg:_IsRelated(v115, arg2)) and (arg3 == true or v115.CloseOnOutside) then
arg:_Apply(v115, false)
end
end
end

index2.CloseDescendants = function(arg, arg2)
for _, v115 in arg._entries, nil, nil do
if v115.Open and arg:_IsDescendantOf(v115, arg2) then
arg:_Apply(v115, false)
end
end
end

index2.SetOpen = function(arg, arg2, arg3)
if arg3 then
arg:CloseAll(arg2, v86[34])
arg:BringToFront(arg2)
end

arg:_Apply(arg2, arg3)
end

index2.Toggle = function(arg, arg2)
arg:SetOpen(arg2, not arg2.Open)
end

return index2
end

tbl17.ak = function()
local ak = tbl17.cache.ak

if not ak then
ak = { c = fn35() }
tbl17.cache.ak = ak
end

return ak.c
end
end
do -- al
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.t()
local v118 = tbl17.A()
local v119 = tbl17.w()
local guiService = v117.GuiService
local userInputService = v117.UserInputService
local runService = v117.RunService
local tweenInfo = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, v86[186], false, 0.4)
local index2 = {}
index2.__index = index2

local function fn36()
return nil
end

local function fn37(arg)
return (arg:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", v86[51]))
end

local function fn38(arg)
if arg == nil then
return false
end
return arg >= 48 and arg <= 57 or arg >= 97 and arg <= 122
end

local function fn39(arg, arg2)
local pos = arg:find(arg2, v86[63], true)

if pos ~= nil then
if arg == arg2 then
return 0
end
local flag19 = not fn38(arg:byte(pos - 1))
local flag20 = not fn38(arg:byte(pos + #arg2 - 1 + 1))
if flag19 and flag20 then
return 5 + pos
end

if flag19 then
return 20 + pos
end
return 40 + pos
end

local n = #arg2
if n < v86[26] then
return nil
end
local n33 = #arg
local n34 = 1
local n35 = 1
local n36 = 0
local n37 = 0
local n38 = 0

while n34 <= n33 and n35 <= n do
if arg:byte(n34) == arg2:byte(n35) then
if n36 == v86[186] then
n36 = n34
end

if n37 ~= 0 then
n38 += n34 - n37 - 1
end

n35 += v86[63]
n37 = n34
end

n34 += 1
end

if n35 <= n then
return nil
end
return 100 + n36 + n38 * 4 + n33 - n
end

local function fn40(arg)
local tbl18 = {}

for match in arg:gmatch("%S+") do
table.insert(tbl18, match)
end

return tbl18
end

local function fn41(arg, arg2, arg3)
local v120 = fn39(arg.Label, arg2)
if v120 ~= nil then
return v120
end

if #arg3 == v86[63] then
return nil
end
local v121 = v86[186]
local flag19 = false

for _, v122 in arg3, nil, nil do
local v123 = fn39(arg.Label, v122)
local v124 = fn39(arg.Crumb, v122)

if v123 ~= nil and (v124 == nil or v123 <= v124 + 50) then
v121 += v123
flag19 = true
continue
end

if v124 ~= nil then
v121 += v124 + 50
continue
end
return nil
end

if not flag19 then
return nil
end
return 500 + v121
end

local function fn42(arg)
if arg == v86[186] then
return v86[143]
end
local v120 = v86[56]
return arg * 36 + math.max(0, arg - 1) * v120 + 8
end

local function fn43(arg, arg2)
table.insert(arg, { Hit = arg2, Label = arg2.Label:lower(), Crumb = arg2.Crumb:lower(), Score = 0 })
end

local function fn44(arg, parent)
if not parent:IsA("GuiObject") then
return
end
local instance = Instance.new(v86[85])
instance.Color = v118.get("Accent")
instance.Thickness = 2
instance.Transparency = 0
instance.LineJoinMode = Enum.LineJoinMode.Round

if parent.ClassName == "TextButton" then
instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

instance.Parent = parent
arg:Tween(instance, { Transparency = v86[63] }, tweenInfo)

task.delay(1.6, function()
if instance.Parent ~= nil then
instance:Destroy()
end
end)
end

local function fn45(arg, parent, arg2)
local instance = Instance.new(v86[92])
instance.Visible = false
instance.BackgroundTransparency = 1
instance.Position = UDim2.fromOffset(v86[26], 4)
instance.Size = UDim2.new(1, -8, 0, v86[143])
instance.BorderSizePixel = 0
instance.Text = ""
instance.LayoutOrder = v86[186]
instance.AutoButtonColor = false
arg2:Bind(instance, "BackgroundColor3", v86[178])
instance.Parent = parent
local instance2 = Instance.new(v86[98])
instance2.CornerRadius = UDim.new(0, 4)
instance2.Parent = instance
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingLeft = UDim.new(0, 8)
uiPadding.PaddingRight = UDim.new(v86[186], 8)
uiPadding.Parent = instance
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = v86[63]
textLabel.Position = UDim2.fromOffset(v86[186], 3)
textLabel.Size = UDim2.new(1, v86[186], v86[186], 16)
textLabel.TextSize = 13
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextTruncate = Enum.TextTruncate.AtEnd
textLabel.FontFace = v116.Medium
arg2:Bind(textLabel, "TextColor3", v86[174])
textLabel.Parent = instance
local textLabel2 = Instance.new("TextLabel")
textLabel2.BackgroundTransparency = 1
textLabel2.Position = UDim2.fromOffset(0, 19)
textLabel2.Size = UDim2.new(v86[63], v86[186], 0, 13)
textLabel2.TextSize = 11
textLabel2.TextXAlignment = Enum.TextXAlignment.Left
textLabel2.TextTruncate = Enum.TextTruncate.AtEnd
textLabel2.FontFace = arg._menu.Fonts.Main
arg2:Bind(textLabel2, "TextColor3", "Unselected")
textLabel2.Parent = instance

arg._trove:Connect(instance.MouseButton1Click, function()
local v120 = arg._scored[instance.LayoutOrder]

if v120 ~= nil then
arg:_NavigateTo(v120.Hit)
end
end)

arg._trove:Connect(instance.MouseEnter, function()
if arg._scored[instance.LayoutOrder] ~= nil then
arg._selectedIndex = instance.LayoutOrder
arg:_RefreshHighlight()
end
end)

return { Button = instance, Title = textLabel, Crumb = textLabel2 }
end

local function fn46(arg)
local ui = arg._ui
if ui == nil then
return
end
local n = #arg._scored
local n33 = 1

if v86[186] < n then
n33 = math.min(math.floor(math.max(0, ui.ResultList.CanvasPosition.Y - v86[26]) / 38) + 1, n)
end

for k, v120 in ui.Rows, nil, nil do
local layoutOrder = n33 + k - 1
local v121 = arg._scored[layoutOrder]

if v121 == nil then
v120.Button.Visible = false
v120.Button.LayoutOrder = v86[186]
v120.Button.BackgroundTransparency = 1
else
local hit = v121.Hit

if v120.Title.Text ~= hit.Label then
v120.Title.Text = hit.Label
end

if v120.Crumb.Text ~= hit.Crumb then
v120.Crumb.Text = hit.Crumb
end

v120.Button.LayoutOrder = layoutOrder
v120.Button.Position = UDim2.fromOffset(4, 4 + (layoutOrder - 1) * v86[107])
v120.Button.BackgroundTransparency = layoutOrder == arg._selectedIndex and 0 or 1
v120.Button.Visible = v86[34]
end
end
end

local function fn47(arg)
local ui = arg._ui
if ui ~= nil then
return ui
end
local menu = arg._menu
local v120 = v118.newBatch(arg._trove)
local instance = Instance.new(v86[128])
instance.Size = UDim2.fromOffset(260, 0)
instance.AutomaticSize = Enum.AutomaticSize.Y
instance.AnchorPoint = Vector2.new(1, 0)
instance.BackgroundColor3 = Color3.fromRGB(v86[108], v86[108], v86[108])
instance.BorderSizePixel = 0
instance.Visible = false
instance.Parent = menu:GetOverlayLayer()
arg._trove:Add(instance)
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v120:BindGradient(uiGradient, { "GradientTop", v86[70] })
uiGradient.Parent = instance
local instance2 = Instance.new(v86[98])
instance2.CornerRadius = UDim.new(0, 8)
instance2.Parent = instance
local uiStroke = Instance.new("UIStroke")
v120:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = instance
v115.addGlow(v120, instance, { Amount = 4, DampingFactor = 0.6 })
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.fromScale(v86[63], 0)
scrollingFrame.AutomaticSize = Enum.AutomaticSize.None
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.BorderSizePixel = v86[186]
scrollingFrame.Active = v86[34]
scrollingFrame.ScrollBarThickness = 3
scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
scrollingFrame.CanvasSize = UDim2.new(0, 0, v86[186], 0)
scrollingFrame.Selectable = v86[153]
v120:Bind(scrollingFrame, "ScrollBarImageColor3", v86[139])
scrollingFrame.Parent = instance
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = v86[63]
textLabel.Position = UDim2.fromOffset(4, 4)
textLabel.Size = UDim2.new(1, -8, v86[186], 28)
textLabel.Text = "No matches."
textLabel.TextSize = 12
textLabel.Visible = v86[153]
textLabel.FontFace = menu.Fonts.Main
v120:Bind(textLabel, "TextColor3", v86[96])
textLabel.Parent = scrollingFrame

local v121 = menu:RegisterOverlay(instance, {
CloseOnOutside = true,
OnToggle = function(arg2)
if not arg2 then
arg:Hide()
end
end,
})

local tbl18 = {}

for i = v86[63], v86[54] do
table.insert(tbl18, fn45(arg, scrollingFrame, v120))
end

local ui2 = { Dropdown = instance, ResultList = scrollingFrame, EmptyHint = textLabel, Batch = v120, Rows = tbl18, Entry = v121 }
arg._ui = ui2

arg._trove:Connect(scrollingFrame:GetPropertyChangedSignal("CanvasPosition"), function()
fn46(arg)
end)

return ui2
end

index2.new = function(arg, arg2)
local v120 = arg2:Extend()

local obj = setmetatable({
_trove = v120,
_menu = arg,
_registrations = {},
_index = nil,
_scored = {},
_selectedIndex = 1,
_activeBar = nil,
_visible = false,
_ui = nil,
}, index2)

v120:Connect(userInputService.InputBegan, function(arg3, arg4)
if arg3.UserInputType ~= Enum.UserInputType.Keyboard then
return
end

if arg3.KeyCode == Enum.KeyCode.Escape then
if obj._visible then
obj:Hide()
local activeBar = obj._activeBar

if activeBar ~= nil then
activeBar.Collapse()
end
end

return
end

if arg3.KeyCode == Enum.KeyCode.F then
if (userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(Enum.KeyCode.RightControl)) and arg.Visible then
local activeBar = obj._activeBar

if activeBar ~= nil then
activeBar.Expand()
end
end

return
end

if not obj._visible then
return
end

if arg3.KeyCode == Enum.KeyCode.Down then
obj:_MoveSelection(v86[63])
elseif arg3.KeyCode == Enum.KeyCode.Up then
obj:_MoveSelection(-1)
elseif arg3.KeyCode == Enum.KeyCode.Return and not arg4 then
local v121 = obj._scored[obj._selectedIndex]

if v121 ~= nil then
obj:_NavigateTo(v121.Hit)
end
end
end)

return obj
end

index2.Register = function(arg, arg2, arg3, arg4)
table.insert(arg._registrations, { Host = arg2, Section = arg3, Collect = arg4 })
arg._index = nil
end

index2.Invalidate = function(arg)
arg._index = nil
end

index2.SetActiveBar = function(arg, activeBar)
arg._activeBar = activeBar
end

local function fn48(arg)
local index3 = arg._index
if index3 ~= nil then
return index3
end
local index4 = {}
local tbl18 = {}
local tbl19 = {}

for _, v120 in arg._registrations, nil, nil do
local host = v120.Host
local tabLabel = host.TabLabel

if not tbl18[tabLabel] then
tbl18[tabLabel] = true

fn43(index4, {
Kind = "navigation",
Label = tabLabel,
Crumb = "Menu",
Open = host.OpenTab,
Reveal = nil,
GetFrame = fn36,
})
end

local pageLabel = host.PageLabel
local str7

if pageLabel == nil then
str7 = tabLabel
else
local str8 = tabLabel .. "\0" .. pageLabel

if not tbl19[str8] then
tbl19[str8] = true

fn43(index4, {
Kind = "navigation",
Label = pageLabel,
Crumb = tabLabel,
Open = host.Open,
Reveal = nil,
GetFrame = fn36,
})
end

str7 = ("%s  ›  %s"):format(tabLabel, pageLabel)
end

local title = v120.Section.Title
local tbl20 = {}
local open = host.Open
v120.Collect(("%s  ›  %s"):format(str7, title), open, tbl20)
local v121 = tbl20[1]
local reveal = nil
local getFrame = fn36

if v121 ~= nil then
reveal = v121.Reveal
getFrame = v121.GetFrame
end

if title ~= "" then
fn43(index4, {
Kind = "navigation",
Label = title,
Crumb = str7,
Open = host.Open,
Reveal = reveal,
GetFrame = getFrame,
})
end

for _, v122 in tbl20, nil, nil do
fn43(index4, v122)
end
end

arg._index = index4
return index4
end

index2.Search = function(arg, arg2)
local scored = arg._scored
table.clear(scored)
arg._selectedIndex = 1
local v120 = fn37(arg2)

if v120 == "" then
local ui = arg._ui

if ui ~= nil then
ui.EmptyHint.Visible = false
ui.ResultList.CanvasPosition = Vector2.zero
ui.ResultList.CanvasSize = UDim2.new(0, 0, 0, 0)
fn46(arg)
end

return 0
end

local v121 = fn40(v120)

for _, v122 in fn48(arg) do
local v123 = fn41(v122, v120, v121)

if v123 ~= nil then
v122.Score = v123
table.insert(scored, v122)
end
end

table.sort(scored, function(arg3, arg4)
if arg3.Score ~= arg4.Score then
return arg3.Score < arg4.Score
end

if arg3.Hit.Kind ~= arg4.Hit.Kind then
return arg3.Hit.Kind == "navigation"
end

if arg3.Label ~= arg4.Label then
return arg3.Label < arg4.Label
end
return arg3.Crumb < arg4.Crumb
end)

local v122 = fn47(arg)
local n = #scored
v122.EmptyHint.Visible = n == 0
local n33 = math.min(math.max(n, 1), 5)
local n34

if n == 0 then
n34 = 36
else
n34 = n33 * 36 + (n33 - 1) * 2 + 8
end

v122.ResultList.Size = UDim2.new(1, 0, 0, n34)
v122.ResultList.CanvasSize = UDim2.fromOffset(v86[186], fn42(n))
v122.ResultList.CanvasPosition = Vector2.zero
arg:_RefreshHighlight()
return n
end

index2.ShowAt = function(arg, arg2)
local v120 = fn47(arg)
local n = arg2.AbsolutePosition + guiService:GetGuiInset()
local absoluteSize = arg2.AbsoluteSize
local n33 = math.floor(absoluteSize.X)
local n34 = math.floor(n.X + absoluteSize.X)
local n35 = math.floor(n.Y + absoluteSize.Y + 4)
local currentCamera = workspace.CurrentCamera
local n36, n37, n38

if currentCamera == nil then
n36 = n34
n37 = n33
n38 = n35
else
local viewportSize = currentCamera.ViewportSize
n37 = math.min(n33, math.floor(viewportSize.X))
n36 = math.clamp(n34, n37, viewportSize.X)
n38 = math.clamp(n35, 0, math.max(0, viewportSize.Y - v120.ResultList.Size.Y.Offset))
end

v120.Dropdown.Size = UDim2.fromOffset(n37, 0)

if not arg._visible then
local n39 = math.max(0, n38 - 8)
v120.Dropdown.Position = UDim2.fromOffset(n36, n39)
v120.Dropdown.Visible = v86[34]
arg._menu:Tween(v120.Dropdown, { Position = UDim2.fromOffset(n36, n38) })
else
v120.Dropdown.Position = UDim2.fromOffset(n36, n38)
end

arg._visible = true
arg._menu:SetOverlayOpen(v120.Entry, v86[34])
end

index2.Hide = function(arg)
local ui = arg._ui
if ui == nil then
return
end
ui.Dropdown.Visible = false
arg._visible = false

if ui.Entry.Open then
arg._menu:SetOverlayOpen(ui.Entry, false)
end
end

index2._RefreshHighlight = function(arg)
local ui = arg._ui
if ui == nil then
return
end
local n = #arg._scored
if n == 0 then
fn46(arg)
return
end
local y = ui.ResultList.AbsoluteWindowSize.Y

if y <= 0 then
y = ui.ResultList.Size.Y.Offset
end

local n33 = 4 + (arg._selectedIndex - v86[63]) * 38
local n34 = n33 + 36
local y2 = ui.ResultList.CanvasPosition.Y

if not (n33 < y2) then
if not (y2 + y < n34) then
n33 = y2
else
n33 = n34 - y
end
end

local n35 = math.max(0, fn42(n) - y)
local n36 = math.clamp(n33, 0, n35)

if n36 ~= ui.ResultList.CanvasPosition.Y then
ui.ResultList.CanvasPosition = Vector2.new(0, n36)
end

fn46(arg)
end

index2._MoveSelection = function(arg, arg2)
local selectedIndex = #arg._scored
if selectedIndex == 0 then
return
end
local n = arg._selectedIndex + arg2

if not (n < 1) then
if not (selectedIndex < n) then
selectedIndex = n
else
selectedIndex = 1
end
end

arg._selectedIndex = selectedIndex
arg:_RefreshHighlight()
end

index2._NavigateTo = function(arg, arg2)
arg:Hide()
local activeBar = arg._activeBar

if activeBar ~= nil then
activeBar.Collapse()
end

arg2.Open()
local reveal = arg2.Reveal

if reveal ~= nil then
reveal()
end

task.spawn(function()
runService.Heartbeat:Wait()
local v120 = arg2.GetFrame()
if v120 == nil or v120.Parent == nil then
return
end
local v121 = v119.findScrollingAncestor(v120)

if v121 ~= nil then
local n = math.max(0, v120.AbsolutePosition.Y - v121.AbsolutePosition.Y + v121.CanvasPosition.Y - 80)
arg._menu:Tween(v121, { CanvasPosition = Vector2.new(0, n) })
end

fn44(arg._menu, v120)
end)
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.al = function()
local al = tbl17.cache.al

if not al then
al = { c = fn35() }
tbl17.cache.al = al
end

return al.c
end
end
do -- am
local function fn35()
tbl17.k()
local v115 = tbl17.v()
tbl17.A()
local tbl18 = {}
local tbl19 = {}
setmetatable(tbl19, { __mode = "k" })

local function fn36(arg, arg2)
if arg2 == "X" then
return arg.AbsoluteCanvasSize.X, arg.AbsoluteWindowSize.X, arg.CanvasPosition.X
end
return arg.AbsoluteCanvasSize.Y, arg.AbsoluteWindowSize.Y, arg.CanvasPosition.Y
end

local function fn37(arg, parent, arg2, arg3, arg4, arg5)
local instance = Instance.new(v86[128])
instance.BackgroundTransparency = 0
instance.BorderSizePixel = v86[186]
instance.ZIndex = arg2.ZIndex + v86[63]
instance.Active = false
instance.Visible = false
arg:Bind(instance, "BackgroundColor3", "GradientDark")
local rotation

if arg3 == "X" then
local n

if arg4 then
instance.Position = arg2.Position
n = 0
else
instance.Position = UDim2.new(arg2.Position.X.Scale + arg2.Size.X.Scale, arg2.Position.X.Offset + arg2.Size.X.Offset, arg2.Position.Y.Scale, arg2.Position.Y.Offset)
n = 1
end

instance.AnchorPoint = Vector2.new(n, v86[186])
instance.Size = UDim2.new(0, arg5, arg2.Size.Y.Scale, arg2.Size.Y.Offset)
rotation = 0
else
local v116 = v86[63]

if arg4 then
v116 = v86[186]
instance.Position = arg2.Position
else
instance.Position = UDim2.new(arg2.Position.X.Scale, arg2.Position.X.Offset, arg2.Position.Y.Scale + arg2.Size.Y.Scale, arg2.Position.Y.Offset + arg2.Size.Y.Offset)
end

instance.AnchorPoint = Vector2.new(v86[186], v116)
instance.Size = UDim2.new(arg2.Size.X.Scale, arg2.Size.X.Offset, v86[186], arg5)
rotation = 90
end

instance.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = rotation

if arg4 then
local new = NumberSequenceKeypoint.new
local v116 = v86[63]
uiGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), new(1, v116) })
else
local new = NumberSequenceKeypoint.new
uiGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, v86[63]), new(1, 0.25) })
end

uiGradient.Parent = instance
return instance
end

tbl18.attachOverflowCues = function(arg, arg2, arg3, arg4, arg5)
local navigation = v115.get().Navigation
local v116 = fn37(arg2, arg4, arg3, arg5, true, navigation.CueDepth)
local v117 = fn37(arg2, arg4, arg3, arg5, false, navigation.CueDepth)

local function fn38()
local v118, v119, v120 = fn36(arg3, arg5)
local n = math.max(0, v118 - v119)
local visibilityEpsilon = navigation.VisibilityEpsilon
local flag19 = n > visibilityEpsilon
v116.Visible = flag19 and v120 > visibilityEpsilon
v117.Visible = flag19 and v120 < n - visibilityEpsilon
end

arg:Connect(arg3:GetPropertyChangedSignal("AbsoluteCanvasSize"), fn38)
arg:Connect(arg3:GetPropertyChangedSignal("AbsoluteWindowSize"), fn38)
arg:Connect(arg3:GetPropertyChangedSignal("CanvasPosition"), fn38)

task.defer(function()
if arg3.Parent ~= nil then
fn38()
end
end)
end

local function fn38(arg, arg2, arg3)
if arg.Parent == nil or arg2.Parent == nil then
return
end
local v116, v117, n = fn36(arg, arg3)
if v117 <= 0 then
return
end
local x, x2, x3

if arg3 == "X" then
x = arg2.AbsolutePosition.X
x2 = arg2.AbsoluteSize.X
x3 = arg.AbsolutePosition.X
else
x = arg2.AbsolutePosition.Y
x2 = arg2.AbsoluteSize.Y
x3 = arg.AbsolutePosition.Y
end

local revealPadding = v115.get().Navigation.RevealPadding
local n33 = x - x3 + n - revealPadding
local n34 = n33 + x2 + revealPadding * 2

if n33 < n then
n = n33
elseif n34 > n + v117 then
n = n34 - v117
end

local n35 = math.clamp(n, v86[186], math.max(0, v116 - v117))

if arg3 == "X" then
arg.CanvasPosition = Vector2.new(n35, arg.CanvasPosition.Y)
else
arg.CanvasPosition = Vector2.new(arg.CanvasPosition.X, n35)
end
end

tbl18.scrollIntoView = function(arg, arg2, arg3)
local n = (tbl19[arg] or 0) + 1
tbl19[arg] = n
fn38(arg, arg2, arg3)

task.defer(function()
if tbl19[arg] == n then
fn38(arg, arg2, arg3)
end
end)
end

return tbl18
end

tbl17.am = function()
local am = tbl17.cache.am

if not am then
local am2 = { c = fn35() }
tbl17.cache.am = am2
am = am2
end

return am.c
end
end
do -- an
local function fn35()
local v115 = tbl17.g()
tbl17.k()
local v116 = tbl17.ab()
tbl17.r()
local v117 = tbl17.af()
local v118 = tbl17.v()
local v119 = tbl17.am()
local v120 = tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2, arg3, arg4, arg5)
local v121 = arg4:Extend()
local v122 = v120.newBatch(v121)
local page = v118.get().Page
local subtabs = arg2._subtabs
assert(subtabs ~= nil, "Page.new requires the tab's page header")
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.fromOffset(page.TabMinWidth, page.TabHeight)
textButton.BorderSizePixel = 0
textButton.AutomaticSize = Enum.AutomaticSize.X
textButton.Text = ""
textButton.AutoButtonColor = false
v122:Bind(textButton, "BackgroundColor3", "TabButtonSelected")
textButton.Parent = subtabs
local instance = Instance.new(v86[98])
instance.CornerRadius = UDim.new(v86[186], 6)
instance.Parent = textButton
local flag19 = arg5.Icon ~= nil and arg5.Icon ~= ""
local imageLabel = nil

if flag19 then
imageLabel = Instance.new("ImageLabel")
imageLabel.ImageColor3 = v120.get(v86[96])
imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
imageLabel.Image = arg5.Icon
imageLabel.BackgroundTransparency = 1
imageLabel.Position = UDim2.fromScale(0.5, 0.5)
imageLabel.Size = UDim2.fromOffset(page.TabIconSize, page.TabIconSize)
imageLabel.BorderSizePixel = 0
imageLabel.Parent = textButton
end

local frame = Instance.new("Frame")
frame.BackgroundTransparency = v86[63]
frame.Size = UDim2.new(0, 0, 0, 0)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.XY
frame.Parent = textButton
local instance2 = Instance.new(v86[135])
instance2.TextTransparency = 0
instance2.Text = arg5.Label
instance2.AnchorPoint = Vector2.new(0, 0.5)
instance2.BorderSizePixel = 0
instance2.BackgroundTransparency = 1
instance2.Position = UDim2.fromScale(0, 0.5)
instance2.AutomaticSize = Enum.AutomaticSize.XY
instance2.TextSize = page.TabTextSize
instance2.FontFace = arg.Fonts.Main
v122:Bind(instance2, "TextColor3", v86[174])
instance2.Parent = frame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(v86[186], 4)
uiPadding.PaddingTop = UDim.new(0, 4)
uiPadding.Parent = instance2
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.Padding = UDim.new(0, v86[26])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame
local instance3 = Instance.new(v86[4])
instance3.VerticalAlignment = Enum.VerticalAlignment.Center

if imageLabel == nil then
instance3.HorizontalAlignment = Enum.HorizontalAlignment.Center
end

instance3.FillDirection = Enum.FillDirection.Horizontal
instance3.Padding = UDim.new(0, page.TabGap)
instance3.SortOrder = Enum.SortOrder.LayoutOrder
instance3.Parent = textButton
local tabPaddingLeft = page.TabPaddingLeft
local tabPaddingRight = page.TabPaddingRight

if imageLabel == nil then
local n = (page.TabIconSize + page.TabGap) / 2
tabPaddingLeft = math.round(tabPaddingLeft + n)
tabPaddingRight = math.round(tabPaddingRight + n)
end

local instance4 = Instance.new(v86[113])
instance4.PaddingRight = UDim.new(0, tabPaddingRight)
instance4.PaddingLeft = UDim.new(0, tabPaddingLeft)
instance4.Parent = textButton
local instance5 = Instance.new(v86[47])
instance5.Visible = false
instance5.BackgroundTransparency = 1
instance5.GroupTransparency = 0
local n = page.HeaderHeight + page.TabsHeight
instance5.Position = UDim2.fromOffset(page.HorizontalInset, n)
instance5.Size = UDim2.new(1, -page.HorizontalInset * 2, v86[63], -n - page.BottomInset)
instance5.BorderSizePixel = v86[186]
instance5.Parent = arg2._page
local instance6 = Instance.new(v86[4])
instance6.SortOrder = Enum.SortOrder.LayoutOrder
instance6.HorizontalFlex = Enum.UIFlexAlignment.Fill
instance6.Padding = UDim.new(v86[186], v118.get().Section.Gap)
instance6.Parent = instance5
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = 1
frame2.BorderSizePixel = 0
frame2.LayoutOrder = 1
frame2.Size = UDim2.fromScale(1, 1)
frame2.Parent = instance5
local uiFlexItem = Instance.new("UIFlexItem")
uiFlexItem.FlexMode = Enum.UIFlexMode.Fill
uiFlexItem.Parent = frame2

local obj = setmetatable({
_trove = v121,
_menu = arg,
_tab = arg2,
_openTab = arg3,
_batch = v122,
Label = arg5.Label,
_button = textButton,
_icon = imageLabel,
_page = instance5,
_body = frame2,
_header = nil,
_fadeState = { Tweening = v86[153] },
_grid = nil,
Opened = v121:Add(v115.new()),
_openedOnce = false,
_pendingOpen = v86[153],
_selected = false,
}, index2)

v121:Connect(textButton.MouseButton1Click, function()
obj:Open()
end)

v122:BindStateful("Accent", function(imageColor3)
local icon = obj._icon

if icon ~= nil and obj._selected then
icon.ImageColor3 = imageColor3
end
end)

v122:BindStateful("Unselected", function(imageColor3)
local icon = obj._icon

if icon ~= nil and not obj._selected then
icon.ImageColor3 = imageColor3
end
end)

if arg2.ActivePage == nil then
obj:Open()
end

return obj
end

index2._SetSelected = function(arg, selected)
arg._selected = selected
local str7 = "Unselected"
local n = 1

if selected then
str7 = "Accent"
n = 0
end

arg._menu:Tween(arg._button, { BackgroundTransparency = n })
local icon = arg._icon

if icon ~= nil then
arg._menu:Tween(icon, { ImageColor3 = v120.get(str7) })
end
end

index2.Open = function(activePage)
local activePage2 = activePage._tab.ActivePage
if activePage2 == activePage then
return
end
activePage._menu:CloseOverlays(nil, v86[34])

if activePage2 ~= nil then
activePage2:_SetSelected(false)
activePage._menu:FadeCanvasGroup(activePage2._page, false, activePage2._fadeState)

if activePage2._pendingOpen then
activePage2._pendingOpen = v86[153]
else
activePage2.Opened:Fire(false)
end
end

activePage:_SetSelected(true)
activePage._menu:FadeCanvasGroup(activePage._page, true, activePage._fadeState)
local subtabs = activePage._tab._subtabs

if subtabs ~= nil then
v119.scrollIntoView(subtabs, activePage._button, v86[124])
end

activePage._tab.ActivePage = activePage

if activePage._tab._openedOnce then
activePage._openedOnce = true
activePage:_MaybeRealize()
activePage.Opened:Fire(true)
else
activePage._pendingOpen = v86[34]
end
end

index2._FlushPendingOpen = function(arg)
if not arg._pendingOpen then
return
end
arg._pendingOpen = false
arg._openedOnce = v86[34]
arg:_MaybeRealize()
arg.Opened:Fire(true)
end

index2._MaybeRealize = function(arg)
if arg._tab.ActivePage ~= arg then
return
end

if not arg._tab._openedOnce then
return
end
local header = arg._header

if header ~= nil then
header:Realize()
end

local grid = arg._grid

if grid ~= nil then
grid:Realize()
end
end

index2.Grid = function(arg, arg2)
local grid = arg._grid
if grid ~= nil then
return grid
end
local openTab = arg._openTab

local v121 = v117.new(arg._menu, arg._body, arg._trove, arg._batch, arg2, {
TabLabel = arg._tab.Label,
PageLabel = arg.Label,
OpenTab = openTab,
Open = function()
openTab()
arg:Open()
end,
})

arg._grid = v121
arg:_MaybeRealize()
return v121
end

index2.Header = function(arg, arg2)
local header = arg._header
if header ~= nil then
return header
end
local frame = Instance.new("Frame")
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.LayoutOrder = v86[186]
frame.Size = UDim2.fromScale(v86[63], 0)
frame.Parent = arg._page
local instance = Instance.new(v86[113])
instance.PaddingTop = UDim.new(0, 1)
instance.PaddingBottom = UDim.new(0, 1)
instance.PaddingLeft = UDim.new(0, 1)
instance.PaddingRight = UDim.new(v86[186], 1)
instance.Parent = frame
local openTab = arg._openTab

local v121 = v116.BuildSection(arg._menu, arg._trove, arg2 or {}, function()
return frame
end)

arg._header = v121

arg._menu:RegisterSearchSection({
TabLabel = arg._tab.Label,
PageLabel = arg.Label,
OpenTab = openTab,
Open = function()
openTab()
arg:Open()
end,
}, v121, function(arg3, arg4, arg5)
v121:CollectSearchHits(arg3, arg4, arg5)
end)

arg:_MaybeRealize()
return v121
end

index2.OnFirstOpen = function(arg, arg2)
local function fn36()
local thread = coroutine.create(arg2)
arg._trove:Add(thread)
task.spawn(thread)
end

if arg._openedOnce then
fn36()
return
end
local connection = nil

connection = arg._trove:Connect(arg.Opened, function(arg3)
if arg3 ~= v86[34] then
return
end
connection:Disconnect()
fn36()
end)
end

index2.Destroy = function(arg)
arg._button:Destroy()
arg._page:Destroy()
arg._trove:Destroy()
end

return index2
end

tbl17.an = function()
local an = tbl17.cache.an

if not an then
local an2 = { c = fn35() }
tbl17.cache.an = an2
an = an2
end

return an.c
end
end
do -- ao
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.am()
local v119 = tbl17.A()
local tbl18 = {}
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function fn36(arg, arg2, parent, arg3)
local v120 = v117.get()
local page = v120.Page
local n = 10

if v120.IsCompact then
n = 6
end

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, v86[101])
frame.Position = UDim2.new(1, -page.SearchRightInset, 0.5, 0)
frame.Size = UDim2.fromOffset(page.SearchCollapsedWidth, page.SearchHeight)
frame.BackgroundColor3 = Color3.fromRGB(v86[108], v86[108], 255)
frame.BorderSizePixel = v86[186]
frame.ClipsDescendants = true
frame.Parent = parent
local instance = Instance.new(v86[46])
instance.Rotation = 90
arg2:BindGradient(instance, { "GradientTop", "GradientMid" })
instance.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], 8)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = v119.get("TabHighlight")
uiStroke.Transparency = v86[186]
uiStroke.Parent = frame
local imageLabel = Instance.new("ImageLabel")
imageLabel.AnchorPoint = Vector2.new(0, 0.5)
imageLabel.Position = UDim2.new(0, n, 0.5, 0)
imageLabel.Size = UDim2.fromOffset(16, v86[13])
imageLabel.BackgroundTransparency = 1
imageLabel.BorderSizePixel = 0
imageLabel.Image = "rbxassetid://72296609649861"
imageLabel.ImageColor3 = v119.get("Unselected")
imageLabel.Parent = frame
local textLabel = Instance.new("TextLabel")
textLabel.AnchorPoint = Vector2.new(0, 0.5)
textLabel.Position = UDim2.new(v86[186], 30, 0.5, 0)
textLabel.Size = UDim2.new(v86[63], -40, 1, 0)
textLabel.BackgroundTransparency = v86[63]
textLabel.Text = "Ctrl+F"
textLabel.TextSize = 12
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.FontFace = v116.SemiBold
arg2:Bind(textLabel, "TextColor3", "Unselected")
textLabel.Visible = not v120.IsCompact
textLabel.Parent = frame
local textBox = Instance.new("TextBox")
textBox.AnchorPoint = Vector2.new(0, v86[101])
textBox.Position = UDim2.new(0, 32, 0.5, 0)
textBox.Size = UDim2.new(1, -72, 1, -v86[162])
textBox.BackgroundTransparency = 1
textBox.BorderSizePixel = v86[186]
textBox.Text = ""
textBox.PlaceholderText = "Search..."
textBox.PlaceholderColor3 = v119.get("Unselected")
textBox.TextSize = v86[72]
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = v86[153]
textBox.FontFace = v116.SemiBold
textBox.Visible = false
arg2:Bind(textBox, "TextColor3", "TextColor")
textBox.Parent = frame
local textLabel2 = Instance.new("TextLabel")
textLabel2.AnchorPoint = Vector2.new(v86[63], v86[101])
textLabel2.Position = UDim2.new(1, -v86[143], 0.5, v86[186])
textLabel2.Size = UDim2.fromOffset(24, v86[32])
textLabel2.BackgroundTransparency = v86[105]
textLabel2.BorderSizePixel = 0
textLabel2.Text = v86[18]
textLabel2.TextSize = v86[181]
textLabel2.FontFace = v116.Bold
textLabel2.Visible = v86[153]
arg2:Bind(textLabel2, "BackgroundColor3", "Accent")
arg2:Bind(textLabel2, v86[167], "Accent")
textLabel2.Parent = frame
local instance2 = Instance.new(v86[98])
instance2.CornerRadius = UDim.new(0, 4)
instance2.Parent = textLabel2
local imageButton = Instance.new("ImageButton")
imageButton.AnchorPoint = Vector2.new(1, 0.5)
imageButton.Position = UDim2.new(1, -v86[162], 0.5, 0)
imageButton.Size = UDim2.fromOffset(16, 16)
imageButton.BackgroundTransparency = 1
imageButton.BorderSizePixel = 0
imageButton.Image = "rbxassetid://116396312853810"
imageButton.ImageColor3 = v119.get("Unselected")
imageButton.Visible = false
imageButton.AutoButtonColor = false
imageButton.Parent = frame
local flag19 = false

local function fn37()
if flag19 then
return
end
flag19 = v86[34]
textLabel.Visible = false
textBox.Visible = true
textBox:CaptureFocus()
arg:Tween(frame, { Size = UDim2.fromOffset(page.SearchExpandedWidth, page.SearchHeight) }, tweenInfo)
arg:Tween(uiStroke, { Color = v119.get(v86[139]), Transparency = v86[186] }, tweenInfo)
arg:Tween(imageLabel, { ImageColor3 = v119.get(v86[139]) }, tweenInfo)
end

local function fn38()
if not flag19 then
return
end
flag19 = false
textBox:ReleaseFocus()
textBox.Text = ""
textBox.Visible = false
textLabel.Visible = not v120.IsCompact
imageButton.Visible = false
textLabel2.Visible = false
arg:Tween(frame, { Size = UDim2.fromOffset(page.SearchCollapsedWidth, page.SearchHeight) }, tweenInfo)
arg:Tween(uiStroke, { Color = v119.get("TabHighlight"), Transparency = v86[186] }, tweenInfo)
arg:Tween(imageLabel, { ImageColor3 = v119.get(v86[96]) }, tweenInfo)
arg:HideSearchResults()
end

local instance3 = Instance.new(v86[92])
instance3.Size = UDim2.fromScale(1, v86[63])
instance3.BackgroundTransparency = 1
instance3.Text = ""
instance3.ZIndex = v86[186]
instance3.AutoButtonColor = v86[153]
instance3.Parent = frame
arg3:Connect(instance3.MouseButton1Click, fn37)

arg3:Connect(textBox:GetPropertyChangedSignal("Text"), function()
local text = textBox.Text
local visible = text ~= ""
imageButton.Visible = visible
local v121 = arg:SearchQuery(text)
textLabel2.Text = tostring(v121)
textLabel2.Visible = visible and v121 > v86[186]

if visible then
arg:ShowSearchResults(frame)
else
arg:HideSearchResults()
end
end)

arg3:Connect(textBox.FocusLost, function()
if textBox.Text == "" then
fn38()
end
end)

arg3:Connect(imageButton.MouseButton1Click, function()
textBox.Text = ""
textBox:CaptureFocus()
end)

return { Expand = fn37, Collapse = fn38 }
end

tbl18.create = function(arg, arg2, parent, arg3, text, text2)
local page = v117.get().Page
local horizontalInset = page.HorizontalInset
local headerHeight = page.HeaderHeight
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, 1)
frame.BorderSizePixel = 0
frame.Parent = parent
local textLabel = nil
local frame2 = nil
local textLabel2 = nil
local v120 = nil

if page.HasTitleBlock then
frame2 = Instance.new("Frame")
frame2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
frame2.Size = UDim2.new(1, 0, v86[186], headerHeight)
frame2.BorderSizePixel = 0
frame2.Parent = frame
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
v115.bindSurfaceGradient(arg2, uiGradient, { v86[134], "GradientMid", "GradientDark" })
uiGradient.Parent = frame2
local frame3 = Instance.new("Frame")
frame3.Position = UDim2.new(0, 1, 1, -1)
frame3.Size = UDim2.new(1, -1, 0, 1)
frame3.BorderSizePixel = 0
arg2:Bind(frame3, "BackgroundColor3", "Outline")
frame3.Parent = frame2
local frame4 = Instance.new("Frame")
frame4.BackgroundTransparency = v86[63]
frame4.Position = UDim2.fromOffset(horizontalInset, v86[186])
frame4.Size = UDim2.new(v86[63], -horizontalInset, 0, headerHeight)
frame4.BorderSizePixel = 0
frame4.Parent = frame2
local instance = Instance.new(v86[128])
instance.BackgroundTransparency = 1
instance.AnchorPoint = Vector2.new(0, 0.5)
instance.Position = UDim2.fromScale(v86[186], 0.5)
instance.BorderSizePixel = 0
instance.AutomaticSize = Enum.AutomaticSize.XY
instance.Parent = frame4
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.Padding = UDim.new(0, 2)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = instance
textLabel = Instance.new("TextLabel")
textLabel.TextSize = page.TitleTextSize
textLabel.FontFace = v116.Bold
textLabel.Text = text
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.XY
arg2:Bind(textLabel, v86[167], "TextColor")
textLabel.Parent = instance
textLabel2 = Instance.new("TextLabel")
textLabel2.TextSize = page.DescriptionTextSize
textLabel2.FontFace = v116.SemiBold
textLabel2.Text = text2
textLabel2.BackgroundTransparency = 1
textLabel2.BorderSizePixel = 0
textLabel2.AutomaticSize = Enum.AutomaticSize.XY
arg2:Bind(textLabel2, "TextColor3", "Unselected")
textLabel2.Parent = instance
v120 = fn36(arg, arg2, frame4, arg3)
end

local instance = Instance.new(v86[128])
instance.Position = UDim2.fromOffset(0, headerHeight)
instance.Size = UDim2.new(v86[63], v86[186], 1, -headerHeight)
instance.BorderSizePixel = 0
instance.ZIndex = 0
arg2:Bind(instance, "BackgroundColor3", "GradientDark")
instance.Parent = frame
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.Position = UDim2.fromOffset(horizontalInset, headerHeight)
scrollingFrame.Size = UDim2.new(1, -horizontalInset * 2, 0, page.TabsHeight)
scrollingFrame.BorderSizePixel = v86[186]
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
scrollingFrame.CanvasSize = UDim2.new(v86[186], 0, v86[186], v86[186])
scrollingFrame.ScrollBarImageTransparency = 1
scrollingFrame.ScrollBarThickness = 0
scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.X
scrollingFrame.ElasticBehavior = Enum.ElasticBehavior.Never
arg2:Bind(scrollingFrame, "ScrollBarImageColor3", "Accent")
scrollingFrame.Parent = frame

if not page.HasTitleBlock then
scrollingFrame.Size = UDim2.new(v86[63], -horizontalInset - page.SearchCollapsedWidth + page.SearchRightInset + page.TabGap, v86[186], page.TabsHeight)
local instance2 = Instance.new(v86[128])
instance2.BackgroundTransparency = 1
instance2.Size = UDim2.new(1, 0, 0, page.TabsHeight)
instance2.BorderSizePixel = 0
instance2.ZIndex = scrollingFrame.ZIndex + 2
instance2.Parent = frame
v120 = fn36(arg, arg2, instance2, arg3)
end

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.Padding = UDim.new(0, 4)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollingFrame
v118.attachOverflowCues(arg3, arg2, scrollingFrame, frame, "X")

return {
Holder = frame,
Top = frame2,
Subtabs = scrollingFrame,
TitleLabel = textLabel,
DescriptionLabel = textLabel2,
SearchBar = assert(v120),
}
end

return tbl18
end

tbl17.ao = function()
local ao = tbl17.cache.ao

if not ao then
ao = { c = fn35() }
tbl17.cache.ao = ao
end

return ao.c
end
end
do -- ap
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, parent, arg2, arg3, arg4)
local rail = v117.get().Rail
local instance = Instance.new(v86[92])
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromOffset(rail.TabSize, rail.TabSize)
instance.BorderSizePixel = 0
instance.Text = ""
instance.TextTransparency = v86[63]

if not rail.ShowLabels then
instance.Text = arg4.Label
end

instance.AutoButtonColor = false
arg3:Bind(instance, v86[5], "TabButtonSelected")
instance.Parent = parent
local imageLabel = Instance.new("ImageLabel")
imageLabel.AnchorPoint = Vector2.new(v86[101], 0.5)
imageLabel.Image = arg4.Icon
imageLabel.BackgroundTransparency = 1
imageLabel.Position = UDim2.fromScale(v86[101], 0.5)
imageLabel.Size = UDim2.fromOffset(rail.TabIconSize, rail.TabIconSize)

if rail.ShowLabels then
imageLabel.AnchorPoint = Vector2.new(0.5, v86[186])
imageLabel.Position = UDim2.new(0.5, 0, 0, 10)
end

imageLabel.BorderSizePixel = 0
imageLabel.ImageColor3 = v118.get("Unselected")
imageLabel.Parent = instance
local textLabel = Instance.new("TextLabel")
textLabel.AnchorPoint = Vector2.new(0.5, 1)
textLabel.Position = UDim2.new(0.5, v86[186], 1, -6)
textLabel.Size = UDim2.new(1, -4, 0, 14)
textLabel.Visible = rail.ShowLabels
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.Text = arg4.Label
textLabel.TextColor3 = v118.get("Unselected")
textLabel.TextSize = 10
textLabel.FontFace = v116.Bold
textLabel.TextTruncate = Enum.TextTruncate.AtEnd
textLabel.TextXAlignment = Enum.TextXAlignment.Center
textLabel.Parent = instance

local obj = setmetatable({
_trove = arg2,
_menu = arg,
_selected = false,
Button = instance,
Clicked = arg2:Add(v115.new()),
_icon = imageLabel,
_label = textLabel,
}, index2)

arg2:Connect(instance.MouseButton1Click, function()
obj.Clicked:Fire()
end)

if not rail.ShowLabels then
arg:AttachTooltip(arg2, instance, function()
return arg4.Label
end)
end

arg3:BindStateful("Accent", function(imageColor3)
if obj._selected then
obj._icon.ImageColor3 = imageColor3
obj._label.TextColor3 = imageColor3
end
end)

arg3:BindStateful("Unselected", function(imageColor3)
if not obj._selected then
obj._icon.ImageColor3 = imageColor3
obj._label.TextColor3 = imageColor3
end
end)

return obj
end

index2.SetSelected = function(arg, selected)
if arg._selected == selected then
return
end
arg._selected = selected
local str7 = "Unselected"

if selected then
str7 = "Accent"
end

local v119 = v118.get(str7)
arg._menu:Tween(arg._icon, { ImageColor3 = v119 })
arg._menu:Tween(arg._label, { TextColor3 = v119 })
end

return index2
end

tbl17.ap = function()
local ap = tbl17.cache.ap

if not ap then
ap = { c = fn35() }
tbl17.cache.ap = ap
end

return ap.c
end
end
do -- aq
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.v()
local v117 = tbl17.am()
local v118 = tbl17.ap()
tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, parent, arg2, arg3, image)
local rail = v116.get().Rail
local frame = Instance.new("Frame")
frame.BackgroundTransparency = v86[63]
frame.Size = UDim2.new(0, rail.Width, 1, 0)
frame.BorderSizePixel = 0
arg3:Bind(frame, "BackgroundColor3", v86[168])
frame.Parent = parent
local instance = Instance.new(v86[128])
instance.BackgroundTransparency = 0
instance.ZIndex = -1
instance.Size = UDim2.fromScale(1, v86[63])
instance.BorderSizePixel = v86[186]
instance.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
instance.Parent = frame
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v115.bindSurfaceGradient(arg3, uiGradient, { v86[134], "GradientMid", "GradientDark" })
uiGradient.Parent = instance
local frame2 = Instance.new("Frame")
frame2.BackgroundColor3 = Color3.fromRGB(255, 255, v86[108])
frame2.Size = UDim2.new(1, v86[186], 0, rail.HeaderHeight)
frame2.BorderSizePixel = 0
frame2.Parent = frame
local instance2 = Instance.new(v86[46])
instance2.Rotation = 90
v115.bindSurfaceGradient(arg3, instance2, { "GradientTop", v86[187], "GradientDark" })
instance2.Parent = frame2
local imageLabel = Instance.new("ImageLabel")
imageLabel.AnchorPoint = Vector2.new(v86[101], 0.5)
imageLabel.Image = image
imageLabel.BackgroundTransparency = 1
imageLabel.Position = UDim2.fromScale(v86[101], v86[101])
imageLabel.Size = UDim2.fromOffset(rail.LogoSize.X, rail.LogoSize.Y)
imageLabel.BorderSizePixel = v86[186]
if image ~= nil and image == K.LithiumLogo then
imageLabel.ImageColor3 = Color3.new(1, 1, 1)
imageLabel.ScaleType = Enum.ScaleType.Fit
else
arg3:Bind(imageLabel, v86[156], "Accent")
end
imageLabel.Parent = frame2
local frame3 = Instance.new("Frame")
frame3.Position = UDim2.new(0, 0, v86[63], -v86[63])
frame3.Size = UDim2.new(v86[63], 0, 0, v86[63])
frame3.BorderSizePixel = 0
arg3:Bind(frame3, v86[5], "Accent")
frame3.Parent = frame2
local uiGradient2 = Instance.new("UIGradient")
local numberSequence = NumberSequence.new
local tbl18 = {}
local v119 = NumberSequenceKeypoint.new(0, 1)
local v120 = NumberSequenceKeypoint.new(v86[48], 0)
local v121 = NumberSequenceKeypoint.new(0.7, 0)
local new = NumberSequenceKeypoint.new
tbl18[1] = v119
tbl18[2] = v120
tbl18[3] = v121

do
local values = table.pack(new(1, 1))
table.move(values, 1, values.n, 4, tbl18)
end

uiGradient2.Transparency = numberSequence(tbl18)
uiGradient2.Parent = frame3
v115.addGlow(arg3, frame3, { Amount = 2, DampingFactor = 0.78 })
local instance3 = Instance.new(v86[64])
instance3.BackgroundTransparency = v86[63]
instance3.Position = UDim2.fromOffset(0, rail.TabsTop)
instance3.Size = UDim2.new(v86[63], v86[186], v86[63], -rail.TabsTop)
instance3.BorderSizePixel = 0
instance3.AutomaticCanvasSize = Enum.AutomaticSize.Y
instance3.CanvasSize = UDim2.fromOffset(0, 0)
instance3.ScrollingDirection = Enum.ScrollingDirection.Y
instance3.ScrollBarImageTransparency = 1
instance3.ScrollBarThickness = 0
instance3.ElasticBehavior = Enum.ElasticBehavior.Never
instance3.ClipsDescendants = true
arg3:Bind(instance3, v86[154], v86[139])
instance3.Parent = frame
local frame4 = Instance.new("Frame")
frame4.BackgroundTransparency = v86[63]
frame4.Size = UDim2.fromScale(1, 0)
frame4.AutomaticSize = Enum.AutomaticSize.Y
frame4.BorderSizePixel = 0
frame4.Parent = instance3
local instance4 = Instance.new(v86[4])
instance4.Padding = UDim.new(0, rail.TabGap)
instance4.HorizontalAlignment = Enum.HorizontalAlignment.Center
instance4.SortOrder = Enum.SortOrder.LayoutOrder
instance4.Parent = frame4
local frame5 = Instance.new("Frame")
frame5.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
frame5.BorderSizePixel = 0
frame5.Size = UDim2.fromOffset(rail.TabSize, rail.TabSize)
frame5.Position = UDim2.fromScale(v86[101], v86[186])
frame5.AnchorPoint = Vector2.new(v86[101], 0)
frame5.Visible = false
frame5.ZIndex = 0
frame5.Parent = instance3
local instance5 = Instance.new(v86[46])
instance5.Rotation = v86[45]
arg3:BindGradient(instance5, { "TabHighlight", "TabButtonSelected", v86[191] }, { 0, 0.5, 1 })
instance5.Parent = frame5
local instance6 = Instance.new(v86[98])
instance6.CornerRadius = UDim.new(0, 6)
instance6.Parent = frame5
v117.attachOverflowCues(arg2, arg3, instance3, frame, v86[197])

return setmetatable({
_trove = arg2,
_menu = arg,
_batch = arg3,
Frame = frame,
_scroll = instance3,
_holder = frame4,
_indicator = frame5,
}, index2)
end

index2.AddButton = function(arg, arg2, arg3)
return v118.new(arg._menu, arg._holder, arg2, arg._batch, arg3)
end

index2.MoveIndicator = function(arg, arg2)
local indicator = arg._indicator

if not (n26 >= 4814) then
local udim2 = UDim2.new(v86[101], 0, 0, arg2.AbsolutePosition.Y - arg._holder.AbsolutePosition.Y)
v117.scrollIntoView(arg._scroll, arg2, "Y")

if not indicator.Visible then
indicator.Position = udim2
indicator.Visible = true
return
end

arg._menu:Tween(indicator, { Position = udim2 })
return
end

-- (anti-tamper freeze trap removed)
end

return index2
end

tbl17.aq = function()
local aq = tbl17.cache.aq

if not aq then
aq = { c = fn35() }
tbl17.cache.aq = aq
end

return aq.c
end
end
do -- ar
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.af()
local v117 = tbl17.v()
local v118 = tbl17.an()
local v119 = tbl17.ao()
tbl17.aq()
tbl17.ap()
local v120 = tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2, arg3, arg4)
local v121 = arg3:Extend()
local v122 = v120.newBatch(v121)
local v123 = v117.get()
local outerInset = v123.Page.OuterInset
local n = v123.Rail.Width + outerInset
local v124 = arg2.Panel:AddButton(v121, { Label = arg4.Label, Icon = arg4.Icon or "rbxassetid://108815781932261" })
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.BackgroundTransparency = 1
canvasGroup.GroupTransparency = v86[186]
canvasGroup.Visible = false
canvasGroup.Position = UDim2.fromOffset(n, outerInset)
canvasGroup.Size = UDim2.new(1, -n - outerInset, 1, -outerInset * 2)
canvasGroup.BorderSizePixel = v86[186]
canvasGroup.Parent = arg2.MenuFrame

local obj = setmetatable({
_trove = v121,
_menu = arg,
_window = arg2,
_batch = v122,
Label = arg4.Label,
Description = arg4.Description or "",
_button = v124,
_page = canvasGroup,
_fadeState = { Tweening = false },
_grid = nil,
_pages = false,
_header = nil,
_subtabs = nil,
ActivePage = nil,
Opened = v121:Add(v115.new()),
_openedOnce = false,
_pendingOpen = false,
}, index2)

v121:Connect(v124.Clicked, function()
obj:Open()
end)

if arg2.ActiveTab == nil then
obj:Open()
end

return obj
end

index2.Open = function(activeTab)
local window = activeTab._window
local activeTab2 = window.ActiveTab
if activeTab2 == activeTab then
return
end
activeTab._menu:CloseOverlays(nil, v86[34])

if activeTab2 ~= nil then
activeTab2._button:SetSelected(false)
activeTab._menu:FadeCanvasGroup(activeTab2._page, v86[153], activeTab2._fadeState)

if activeTab2._pendingOpen then
activeTab2._pendingOpen = v86[153]
else
activeTab2.Opened:Fire(false)
end
end

window.Panel:MoveIndicator(activeTab._button.Button)
activeTab._button:SetSelected(true)
activeTab._menu:FadeCanvasGroup(activeTab._page, true, activeTab._fadeState)
window.ActiveTab = activeTab

if activeTab._menu.Visible then
activeTab._openedOnce = v86[34]
activeTab:_RealizeActive()
activeTab.Opened:Fire(true)
else
activeTab._pendingOpen = true
end
end

index2._FlushPendingOpen = function(arg)
if not arg._pendingOpen then
return
end
arg._pendingOpen = v86[153]
arg._openedOnce = true
arg:_RealizeActive()
arg.Opened:Fire(v86[34])
end

index2._RealizeActive = function(arg)
local grid = arg._grid
if grid ~= nil then
grid:Realize()
return
end
local activePage = arg.ActivePage

if activePage ~= nil then
activePage:_FlushPendingOpen()
activePage:_MaybeRealize()
end
end

index2.Grid = function(arg, arg2)
assert(not arg._pages, "Tab:Grid() cannot be used on a tab that has sub-tabs")
local grid = arg._grid
if grid ~= nil then
return grid
end

local function fn36()
arg:Open()
end

local v121 = v116.new(arg._menu, arg._page, arg._trove, arg._batch, arg2, { TabLabel = arg.Label, PageLabel = nil, OpenTab = fn36, Open = fn36 })
arg._grid = v121

if arg._openedOnce then
v121:Realize()
end

return v121
end

index2.AddTab = function(arg, arg2)
local v121 = arg
assert(arg._grid == nil, "Tab:AddTab() cannot be used on a tab that has a Grid")

if not arg._pages then
arg._pages = true
local width = v117.get().Rail.Width
arg._page.Size = UDim2.new(1, -width, v86[63], 0)
arg._page.Position = UDim2.fromOffset(width, 0)
local v122 = v119.create(arg._menu, arg._batch, arg._page, arg._trove, arg.Label, arg.Description)
arg._header = v122
arg._subtabs = v122.Subtabs

arg._trove:Connect(arg.Opened, function(arg3)
if arg3 then
arg._menu:SetActiveSearchBar(v122.SearchBar)
elseif true then
v122.SearchBar.Collapse()
arg._menu:SetActiveSearchBar(nil)
else
-- (anti-tamper freeze trap removed)
end
end)

if arg._window.ActiveTab == arg and arg._openedOnce then
arg._menu:SetActiveSearchBar(v122.SearchBar)
end
end

return v118.new(arg._menu, v121, function()
arg:Open()
end, arg._trove, arg2)
end

index2.OnFirstOpen = function(arg, arg2)
local function fn36()
local thread = coroutine.create(arg2)
arg._trove:Add(thread)
task.spawn(thread)
end

if arg._openedOnce then
fn36()
return
end
local connection = nil

connection = arg._trove:Connect(arg.Opened, function(arg3)
if arg3 ~= v86[34] then
return
end
connection:Disconnect()
fn36()
end)
end

index2.Destroy = function(arg)
arg._page:Destroy()
arg._trove:Destroy()
end

return index2
end

tbl17.ar = function()
local ar = tbl17.cache.ar

if not ar then
ar = { c = fn35() }
tbl17.cache.ar = ar
end

return ar.c
end
end
do -- as
local function fn35()
tbl17.g()
tbl17.k()
local v115 = tbl17.s()
local v116 = tbl17.t()
local v117 = tbl17.A()
local v118 = tbl17.w()
local userInputService = v116.UserInputService
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2, arg3)
local obj = setmetatable({
_trove = arg,
_layer = arg2,
_positionTrove = arg:Extend(),
_followTrove = arg:Extend(),
_frame = nil,
_label = nil,
_owner = nil,
_followConnection = nil,
}, index2)

arg:Connect(arg3, function(arg4)
if not arg4 then
obj:Hide(nil)
end
end)

arg:Connect(userInputService.InputBegan, function(arg4)
local userInputType = arg4.UserInputType
if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.MouseButton2 and userInputType ~= Enum.UserInputType.Touch then
return
end
obj:Hide(nil)
end)

return obj
end

local function fn36(arg)
local frame = arg._frame
local label = arg._label
if frame ~= nil and label ~= nil then
return frame, label
end
local v119 = v117.newBatch(arg._trove)
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = 0.05
frame2.Size = UDim2.new(0, 0, 0, 0)
frame2.AutomaticSize = Enum.AutomaticSize.XY
frame2.BorderSizePixel = 0
frame2.Visible = false
frame2.ZIndex = 1000
v119:Bind(frame2, "BackgroundColor3", v86[168])
frame2.Parent = arg._layer
arg._trove:Add(frame2)
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], 4)
uiCorner.Parent = frame2
local instance = Instance.new(v86[85])
v119:Bind(instance, v86[27], v86[120])
instance.Parent = frame2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 5)
uiPadding.PaddingBottom = UDim.new(0, 5)
uiPadding.PaddingLeft = UDim.new(v86[186], 8)
uiPadding.PaddingRight = UDim.new(0, 8)
uiPadding.Parent = frame2
local instance2 = Instance.new(v86[135])
instance2.BackgroundTransparency = 1
instance2.AutomaticSize = Enum.AutomaticSize.XY
instance2.Text = ""
instance2.FontFace = v115.Medium
instance2.TextSize = 14
instance2.TextWrapped = v86[153]
v119:Bind(instance2, "TextColor3", v86[174])
instance2.Parent = frame2
arg._frame = frame2
arg._label = instance2
return frame2, instance2
end

local function fn37(arg, arg2, arg3)
local v119 = v118.absoluteToLayerOffset(arg._layer, arg3)
arg2.Position = UDim2.fromOffset(v119.X + 14, v119.Y + v86[72])
v118.clampGuiToViewport(arg2)
end

local function fn38(arg, arg2)
local owner = arg._owner
arg._positionTrove:Clean()

arg._positionTrove:Add(task.defer(function()
if arg._owner == owner and arg2.Parent ~= nil and arg2.Visible then
v118.clampGuiToViewport(arg2)
end
end))
end

index2.Show = function(arg, owner, text)
local v119, v120 = fn36(arg)
arg._owner = owner
v120.Text = text
v119.Visible = true
fn37(arg, v119, v118.getPointerPosition())
fn38(arg, v119)

if arg._followConnection == nil then
local connection = userInputService.InputChanged:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.MouseMovement then
return
end
fn37(arg, v119, v118.getPointerPosition())
end)

arg._followConnection = connection
arg._followTrove:Add(connection)
end
end

index2.ShowAt = function(arg, owner, text, arg2)
local v119, v120 = fn36(arg)
arg._owner = owner
v120.Text = text
v119.Visible = true
fn37(arg, v119, arg2)
fn38(arg, v119)
end

index2.Hide = function(arg, arg2)
if arg2 ~= nil and arg._owner ~= arg2 then
return
end
arg._owner = nil
arg._positionTrove:Clean()
local frame = arg._frame

if frame ~= nil and frame.Visible then
frame.Visible = false
end

arg._followTrove:Clean()
arg._followConnection = nil
end

index2.Destroy = function(arg)
arg:Hide(nil)
end

return index2
end

tbl17.as = function()
local as = tbl17.cache.as

if not as then
local as2 = { c = fn35() }
tbl17.cache.as = as2
as = as2
end

return as.c
end
end
do -- at
local function fn35()
local tweenService = tbl17.t().TweenService
local index2 = {}
index2.__index = index2

index2.new = function()
return setmetatable({
_live = false,
Speed = v86[48],
DragSpeed = 0.05,
EasingStyle = Enum.EasingStyle.Quint,
EasingDirection = Enum.EasingDirection.Out,
}, index2)
end

index2.SetLive = function(arg, live)
arg._live = live
end

index2.Snap = function(arg, arg2, arg3)
for k, v115 in arg3, nil, nil do
arg2[k] = v115
end
end

index2.Play = function(arg, arg2, arg3, arg4)
if not arg._live then
arg:Snap(arg2, arg3)
return nil
end
local tween = tweenService:Create(arg2, arg4 or TweenInfo.new(arg.Speed, arg.EasingStyle, arg.EasingDirection, 0, false, 0), arg3)
tween:Play()
return tween
end

index2.DragInfo = function(arg)
return TweenInfo.new(arg.DragSpeed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0)
end

return index2
end

tbl17.at = function()
local at = tbl17.cache.at

if not at then
at = { c = fn35() }
tbl17.cache.at = at
end

return at.c
end
end
do -- au
local function fn35()local I,W= tbl17 .t().RunService,{};W.__index=W;W.new=function(l)return setmetatable({_onDisplay=l,_running=false,_frames=0,_smooth=60,_displayed=-1,_connection=nil,_loopToken=0},W);end;local function l(N)local P,a=N._loopToken,os.clock();task.delay(0.5,function()if N._loopToken~=P then return;end;local P=os.clock()-a;if P>0 then local a=N._frames/P;N._smooth=N._smooth+(a-N._smooth)*0.5;end;N._frames=0;P=math.floor(N._smooth+0.5);if P~=N._displayed then N._displayed=P;N._onDisplay(P);end;l(N);end);end;W.SetRunning=function(N,P)if N._running==P then return;end;N._running=P;N._loopToken=N._loopToken+1;if not P then local P_33=N._connection;if P_33~=nil then P_33:Disconnect();N._connection=nil;end;return;end;N._frames=0;N._connection=I.RenderStepped:Connect(function()N._frames=N._frames+1;end);l(N);end;W.Destroy=function(l)l:SetRunning(false);end;return W;end

tbl17.au = function()
local au = tbl17.cache.au

if not au then
local au2 = { c = fn35() }
tbl17.cache.au = au2
au = au2
end

return au.c
end
end
do -- av
local function fn35()
tbl17.k()
tbl17.r()
local v115 = tbl17.au()
local v116 = tbl17.u()
local v117 = tbl17.A()
local index2 = {}
index2.__index = index2

local function fn36(parent, layoutOrder, fontFace, arg)
local textLabel = Instance.new("TextLabel")
textLabel.LayoutOrder = layoutOrder
textLabel.FontFace = fontFace
textLabel.Text = "|"
textLabel.AnchorPoint = Vector2.new(0, 0.5)
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.fromScale(0, 0.5)
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.XY
textLabel.TextSize = 16
arg:Bind(textLabel, v86[167], "Unselected")
textLabel.Parent = parent
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(v86[186], 1)
uiPadding.Parent = textLabel
end

local function createTextLabel(parent, layoutOrder, text, fontFace, arg)
local textLabel = Instance.new("TextLabel")
textLabel.LayoutOrder = layoutOrder
textLabel.FontFace = fontFace
textLabel.Text = text
textLabel.AnchorPoint = Vector2.new(0, v86[101])
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.fromScale(0, 0.5)
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.XY
textLabel.TextSize = 16
arg:Bind(textLabel, "TextColor3", "TextColor")
textLabel.Parent = parent
local instance = Instance.new(v86[113])
instance.PaddingTop = UDim.new(0, 1)
instance.Parent = textLabel
return textLabel
end

local function fn37(parent, layoutOrder, image, arg)
local instance = Instance.new(v86[146])
instance.LayoutOrder = layoutOrder
instance.Image = image
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromOffset(20, 20)
instance.BorderSizePixel = 0
if image ~= nil and image == K.LithiumLogo then
instance.ImageColor3 = Color3.new(1, 1, 1)
instance.ScaleType = Enum.ScaleType.Fit
else
arg:Bind(instance, "ImageColor3", "Accent")
end
instance.Parent = parent
end

index2.new = function(arg, parent, arg2, arg3)
local v118 = arg2:Extend()
local v119 = v117.newBatch(v118)
local main = arg.Fonts.Main
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 0.04
frame.Position = UDim2.fromOffset(50, 50)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.XY
v119:Bind(frame, "BackgroundColor3", v86[168])
frame.Parent = parent
v118:Add(frame)
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
uiStroke.Thickness = 1
v119:Bind(uiStroke, "Color", v86[120])
uiStroke.Parent = frame
local instance = Instance.new(v86[113])
instance.PaddingTop = UDim.new(0, v86[122])
instance.PaddingBottom = UDim.new(v86[186], v86[122])
instance.PaddingRight = UDim.new(0, 11)
instance.PaddingLeft = UDim.new(0, 13)
instance.Parent = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(v86[186], 10)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.Parent = frame
local scale = v116.Scale

if v116.IsMobile() then
scale = 0.8
end

if scale ~= 1 then
local uiScale = Instance.new("UIScale")
uiScale.Scale = scale
uiScale.Parent = frame
end

fn37(frame, 1, arg3.Icon, v119)
local v120 = createTextLabel(frame, v86[56], arg3.Title, main, v119)
fn36(frame, 3, main, v119)
fn37(frame, 4, "rbxassetid://83187029320661", v119)
local v121 = createTextLabel(frame, 5, arg3.Username, main, v119)
fn36(frame, 6, main, v119)
fn37(frame, 7, "rbxassetid://113103422688495", v119)
local v122 = createTextLabel(frame, 8, "60 FPS", main, v119)
v122.AutomaticSize = Enum.AutomaticSize.Y
v122.Size = UDim2.fromOffset(v86[7], 0)
local stateData = arg:GetStateData()

if stateData ~= nil then
frame.Visible = stateData.ShowWatermark ~= false
end

arg:MakeDraggable(frame, v118, { PersistKey = "WatermarkPosition" })

local v123 = v115.new(function(arg4)
v122.Text = string.format("%s FPS", tostring(arg4))
end)

v118:Add(v123)
v123:SetRunning(frame.Visible)
return setmetatable({ _trove = v118, _menu = arg, _root = frame, _title = v120, _username = v121, _fps = v122, _clock = v123 }, index2)
end

index2.SetEnabled = function(arg, visible)
if arg._root.Visible == visible then
return
end
arg._root.Visible = visible
arg._clock:SetRunning(visible)
local stateData = arg._menu:GetStateData()

if stateData ~= nil then
stateData.ShowWatermark = visible
arg._menu:SaveState()
end
end

index2.IsEnabled = function(arg)
return arg._root.Visible
end

index2.SetTitle = function(arg, text)
arg._title.Text = text
end

index2.SetUsername = function(arg, text)
arg._username.Text = text
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.av = function()
local av = tbl17.cache.av

if not av then
local av2 = { c = fn35() }
tbl17.cache.av = av2
av = av2
end

return av.c
end
end
do -- aw
local function fn35()
local v115 = tbl17.u()
local v116 = tbl17.w()
local tbl18

tbl18 = {
effectiveMinSize = function(arg)
local minSize = v115.MinSize

if v115.IsMobile() then
local min = math.min
local offset = minSize.Y.Offset
local floor2 = math.floor
local n = arg.Y * v86[87]
return math.min(minSize.X.Offset, math.floor(arg.X * 0.65)), min(offset, floor2(n))
end

local min = math.min
local offset = minSize.Y.Offset
local floor2 = math.floor
local n = arg.Y * 0.8
return math.min(minSize.X.Offset, math.floor(arg.X * 0.85)), min(offset, floor2(n))
end,
resolveDefaultSize = function()
local v117 = v116.currentViewportSize()
local designSize = v115.DesignSize
local v118, v119 = tbl18.effectiveMinSize(v117)

if v115.IsMobile() then
local n = math.clamp(v117.X * v86[74], v118, designSize.X.Offset)
local n33 = math.clamp(v117.Y * v86[87], v119, designSize.Y.Offset)
local floor2 = math.floor
return UDim2.fromOffset(math.floor(n), floor2(n33))
end

local n = math.clamp(v117.X * 0.8, v118, designSize.X.Offset)
local n33 = math.clamp(v117.Y * 0.7, v119, designSize.Y.Offset)
local floor2 = math.floor
return UDim2.fromOffset(math.floor(n), floor2(n33))
end,
clampSizeToViewport = function(arg, arg2)
local v117 = v116.currentViewportSize()
local v118, v119 = tbl18.effectiveMinSize(v117)

if not (n25 < 3847) then
local n = 0.98

if v115.IsMobile() then
n = 0.75
end

local n33 = math.floor(v117.X * n)
local n34 = math.floor(v117.Y * n)
return math.clamp(arg, v118, math.max(v118, n33)), math.clamp(arg2, v119, math.max(v119, n34))
end
return nil

-- (anti-tamper freeze trap removed)
end,
menuBounds = function(arg)
local parent = arg.Parent

if parent ~= nil and parent:IsA("GuiBase2d") then
local absoluteSize = parent.AbsoluteSize
if absoluteSize.X > 0 and absoluteSize.Y > 0 then
return absoluteSize
end
end

return v116.currentViewportSize()
end,
clampPositionToParent = function(arg, arg2, arg3, arg4, arg5)
local v117 = tbl18.menuBounds(arg)
local n = math.max(0, math.floor(v117.X - arg4))
local n33 = math.max(0, math.floor(v117.Y - arg5))
return math.round(math.clamp(arg2, 0, n)), math.round(math.clamp(arg3, v86[186], n33))
end,
centeredInParent = function(arg, arg2, arg3)
local v117 = tbl18.menuBounds(arg)
return math.floor((v117.X - arg2) / v86[56]), math.floor((v117.Y - arg3) / 2)
end,
}

return tbl18
end

tbl17.aw = function()
local aw = tbl17.cache.aw

if not aw then
local aw2 = { c = fn35() }
tbl17.cache.aw = aw2
aw = aw2
end

return aw.c
end
end
do -- ax
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.v()
local v117 = tbl17.u()
local v118 = tbl17.t()
local v119 = tbl17.aq()
local v120 = tbl17.ar()
local v121 = tbl17.A()
local v122 = tbl17.w()
local v123 = tbl17.aw()
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2)
local stateData = arg:GetStateData()

if stateData ~= nil then
stateData.Position = { arg2.X.Offset, arg2.Y.Offset }
arg:SaveState()
end
end

local function fn37(arg)
local menu = arg._menu
local menuFrame = arg.MenuFrame
local trove = arg._trove
local batch = arg._batch
local textButton = Instance.new("TextButton")
textButton.AnchorPoint = Vector2.new(1, 1)
textButton.Position = UDim2.fromScale(1, 1)
textButton.Size = UDim2.fromOffset(18, 18)
textButton.BackgroundTransparency = v86[63]
textButton.BorderSizePixel = 0
textButton.Text = ""
textButton.AutoButtonColor = false
textButton.ZIndex = menuFrame.ZIndex + v86[54]
textButton.Parent = menuFrame
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, v86[63])
frame.Position = UDim2.new(1, -v86[26], 1, -4)
frame.Size = UDim2.fromOffset(8, 2)
frame.Rotation = -45
frame.BorderSizePixel = 0
frame.ZIndex = textButton.ZIndex
batch:Bind(frame, "BackgroundColor3", "Outline")
frame.Parent = textButton
local instance = Instance.new(v86[128])
instance.AnchorPoint = Vector2.new(1, v86[63])
instance.Position = UDim2.new(1, -2, 1, -7)
instance.Size = UDim2.fromOffset(5, 2)
instance.Rotation = -45
instance.BorderSizePixel = v86[186]
instance.ZIndex = textButton.ZIndex
batch:Bind(instance, "BackgroundColor3", v86[120])
instance.Parent = textButton
local v124 = nil
local flag19 = false
local v125 = trove:Extend()
local vector2 = nil

local function fn38(arg2)
v125:Clean()
vector2 = nil
local v126 = flag19
flag19 = false
v124 = nil

if arg2 and v126 then
local stateData = menu:GetStateData()

if stateData ~= nil then
stateData.Size = { arg.Size.X.Offset, arg.Size.Y.Offset }
menu:SaveState()
end
end
end

local function fn39(arg2)
if arg2.UserInputType ~= Enum.UserInputType.MouseButton1 and arg2.UserInputType ~= Enum.UserInputType.Touch then
return
end

if flag19 then
return
end
flag19 = true
v124 = arg2

v125:Connect(v118.UserInputService.InputChanged, function(arg3)
if not flag19 then
return
end

if not v122.matchesPointerDrag(arg3, v124, Enum.UserInputType.MouseMovement) then
return
end
vector2 = Vector2.new(arg3.Position.X, arg3.Position.Y)
end)

v125:Connect(v118.RunService.RenderStepped, function()
local v126 = vector2
if v126 == nil then
return
end
vector2 = nil
local n = v126 - menuFrame.AbsolutePosition
local v127, v128 = v123.clampSizeToViewport(math.floor(n.X + v86[101]), math.floor(n.Y + v86[101]))
local udim2 = UDim2.fromOffset(v127, v128)
if udim2 == arg.Size then
return
end
menuFrame.Size = udim2
arg.Size = udim2
end)

v125:Connect(arg2.Changed, function()
if arg2.UserInputState == Enum.UserInputState.End then
fn38(v86[34])
end
end)
end

trove:Connect(textButton.InputBegan, fn39)

if v117.IsMobile() then
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(1, 1)
frame2.Position = UDim2.fromScale(1, 1)
frame2.Size = UDim2.fromOffset(36, 36)
frame2.BackgroundTransparency = 1
frame2.BorderSizePixel = 0
frame2.Active = true
frame2.ZIndex = menuFrame.ZIndex + 5
frame2.Parent = menuFrame
trove:Connect(frame2.InputBegan, fn39)
end
end

index2.new = function(arg, parent, arg2, arg3)
local v124 = arg2:Extend()
local v125 = v121.newBatch(v124)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundTransparency = 0
frame.Position = UDim2.fromScale(v86[101], 0.5)
frame.Size = arg3.Size or v123.resolveDefaultSize()
frame.BorderSizePixel = v86[186]
frame.Active = true
frame.Visible = false
v125:Bind(frame, "BackgroundColor3", "Background")
frame.Parent = parent
local v126 = v116.get()
local instance = Instance.new(v86[92])
instance.BackgroundTransparency = 1
instance.Text = ""
instance.Size = UDim2.new(v86[63], 0, v86[186], 20)

if v126.IsCompact then
instance.Size = UDim2.fromOffset(v126.Rail.Width, v126.Rail.HeaderHeight)
end

instance.Modal = true
instance.ZIndex = 50
instance.AutoButtonColor = false
instance.Parent = frame

if v117.Scale ~= 1 then
local uiScale = Instance.new("UIScale")
uiScale.Scale = v117.Scale
uiScale.Parent = frame
end

local instance2 = Instance.new(v86[85])
instance2.Transparency = v86[84]
v125:Bind(instance2, v86[27], "Outline")
instance2.Parent = frame
v115.addGlow(v125, frame, { Amount = 5, DampingFactor = v86[84] })
local size = frame.Size
local stateData = arg:GetStateData()
local size2 = stateData and stateData.Size

if type(size2) == "table" and #size2 >= 2 then
local v127, v128 = v123.clampSizeToViewport(size2[1], size2[2])
size = UDim2.fromOffset(v127, v128)
end

local offset = size.X.Offset
local offset2 = size.Y.Offset
stateData = stateData and stateData.Position
local udim2

if type(stateData) == "table" and #stateData >= 2 then
local v127, v128 = v123.clampPositionToParent(frame, stateData[1], stateData[2], offset, offset2)
udim2 = UDim2.fromOffset(v127, v128)
else
local v127, v128 = v123.centeredInParent(frame, offset, offset2)
udim2 = UDim2.fromOffset(v127, v128)
end

frame.Size = size
frame.AnchorPoint = Vector2.new(0, 0)
frame.Position = udim2
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = frame
local instance3 = Instance.new(v86[128])
instance3.Position = UDim2.new(0, 0, 1, -8)
instance3.Size = UDim2.new(1, v86[186], 0, 8)
instance3.BorderSizePixel = 0
instance3.BackgroundColor3 = Color3.fromRGB(v86[108], 255, v86[108])
instance3.Parent = frame
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
v125:BindGradient(uiGradient, { "Background", "GradientDeep" })
uiGradient.Parent = instance3
local frame2 = Instance.new("Frame")
frame2.BackgroundTransparency = 1
frame2.Position = UDim2.new(0, 0, 0, 0)
frame2.Size = UDim2.new(1, 0, v86[186], 5)
frame2.BorderSizePixel = v86[186]
frame2.ZIndex = frame.ZIndex + 1
frame2.Parent = frame
local instance4 = Instance.new(v86[128])
instance4.BackgroundTransparency = 0.08
instance4.Position = UDim2.new(0, v86[186], 0, 0)
instance4.Size = UDim2.new(1, 0, v86[186], 1)
instance4.BorderSizePixel = 0
instance4.ZIndex = frame2.ZIndex
v125:Bind(instance4, "BackgroundColor3", "Accent")
instance4.Parent = frame2
local uiGradient2 = Instance.new("UIGradient")
local numberSequence = NumberSequence.new
local tbl18 = {}
local v127 = NumberSequenceKeypoint.new(0, 1)
local v128 = NumberSequenceKeypoint.new(0.06, 0.35)
local v129 = NumberSequenceKeypoint.new(v86[101], v86[186])
local v130 = NumberSequenceKeypoint.new(0.94, 0.35)
local new = NumberSequenceKeypoint.new
local v131 = v86[63]
local v132 = v86[63]
tbl18[1] = v127
tbl18[2] = v128
tbl18[3] = v129
tbl18[4] = v130

do
local values = table.pack(new(v131, v132))
table.move(values, 1, values.n, 5, tbl18)
end

uiGradient2.Transparency = numberSequence(tbl18)
uiGradient2.Parent = instance4
local uiStroke = Instance.new("UIStroke")
uiStroke.Transparency = 0.78
v125:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = instance4
v115.addGlow(v125, instance4, { Amount = 2, DampingFactor = 0.78 })
local v133 = v119.new(arg, frame, v124, v125, arg3.Icon)
local width = v116.get().Rail.Width
local frame3 = Instance.new("Frame")
frame3.BackgroundTransparency = 1
frame3.Position = UDim2.fromOffset(width, v86[186])
frame3.Size = UDim2.new(1, -width, 1, 0)
frame3.BorderSizePixel = 0
v125:Bind(frame3, "BackgroundColor3", "Background")
frame3.Parent = frame
local uiCorner2 = Instance.new("UICorner")
uiCorner2.CornerRadius = UDim.new(0, v86[12])
uiCorner2.Parent = frame3
local uiStroke2 = Instance.new("UIStroke")
uiStroke2.Parent = frame3
v125:Bind(uiStroke2, "Color", "Outline")

local obj = setmetatable({
_trove = v124,
_menu = arg,
_batch = v125,
Title = arg3.Title,
Icon = arg3.Icon,
Size = size,
Open = v86[153],
MenuFrame = frame,
Panel = v133,
PageHolder = frame3,
ActiveTab = nil,
_modalButton = instance,
_menuOpenPosition = udim2,
}, index2)

v124:Connect(arg:MakeDraggable(frame, v124, { OnDragEnd = function(arg4)
fn36(arg, arg4)
end }).DragContinue, function()
obj._menuOpenPosition = frame.Position
end)

local uiDragDetector = Instance.new("UIDragDetector")
uiDragDetector.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane
uiDragDetector.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
uiDragDetector.Parent = instance
local position = nil

v124:Connect(uiDragDetector.DragStart, function()
position = frame.Position
end)

v124:Connect(uiDragDetector.DragContinue, function()
local v134 = position
if v134 == nil then
return
end
local dragUDim2 = uiDragDetector.DragUDim2
frame.Position = UDim2.fromOffset(math.round(v134.X.Offset + dragUDim2.X.Offset), math.round(v134.Y.Offset + dragUDim2.Y.Offset))
v122.clampGuiToViewport(frame)
obj._menuOpenPosition = frame.Position
end)

v124:Connect(uiDragDetector.DragEnd, function()
position = nil
v122.clampGuiToViewport(frame)
obj._menuOpenPosition = frame.Position
fn36(arg, frame.Position)
end)

fn37(obj)
local v134 = v124:Extend()
local v135 = nil

v122.connectCurrentCameraViewport(v124, function(arg4)
if arg4 == nil then
v134:Clean()
v135 = nil
return
end

if arg4 == v135 then
return
end
v135 = arg4
v134:Clean()

v134:Add(task.defer(function()
local size3 = frame.Size
local v136, v137 = v123.clampSizeToViewport(size3.X.Offset, size3.Y.Offset)

if v136 ~= size3.X.Offset or v137 ~= size3.Y.Offset then
local udim22 = UDim2.fromOffset(v136, v137)
frame.Size = udim22
obj.Size = udim22
end

local position2 = frame.Position
local v138, v139 = v123.clampPositionToParent(frame, position2.X.Offset, position2.Y.Offset, v136, v137)

if v138 ~= position2.X.Offset or v139 ~= position2.Y.Offset then
local udim22 = UDim2.fromOffset(v138, v139)
frame.Position = udim22
obj._menuOpenPosition = udim22
end
end))
end)

v124:Connect(arg.VisibilityChanged, function(arg4)
if not arg4 then
return
end
local activeTab = obj.ActiveTab

if activeTab ~= nil then
activeTab:_FlushPendingOpen()
end
end)

return obj
end

index2.AddTab = function(arg, arg2)
return v120.new(arg._menu, arg, arg._trove, arg2)
end

index2.SetVisible = function(arg, open)
if arg.Open == open then
return false
end
arg.Open = open
arg._modalButton.Modal = open
arg.MenuFrame.Visible = open
return true
end

index2.SetTitle = function(arg, title)
arg.Title = title
end

index2.Destroy = function(arg)
arg.MenuFrame:Destroy()
arg._trove:Destroy()
end

return index2
end

tbl17.ax = function()
local ax = tbl17.cache.ax

if not ax then
ax = { c = fn35() }
tbl17.cache.ax = ax
end

return ax.c
end
end
do -- ay
local function fn35()local I={__mode="k"};local function W(N)if type(N)=="function"then return true;end;if type(N)=="table"then local P=getmetatable(N);if P and type( v102 (P,"__call"))=="function"then return true;end;end;return false;end;local function N(P,a)local e={};for c,c_34 in ipairs(a)do e[c_34]=c_34;end;return setmetatable(e,{__index=function(a,a_35)error(string.format("%s is not in %s!",a_35,P),2);end,__newindex=function()error(string.format("Creating new members in %s is not allowed!",P),2);end});end;local P:any;P={Kind=N("Promise.Error.Kind",{"ExecutionError","AlreadyCancelled","NotResolvedInTime","TimedOut"})};P.__index=P;P.new=function(a,e)a=a or{};return setmetatable({error=tostring(a.error)or"[This error has no error text.]",trace=a.trace,context=a.context,kind=a.kind,parent=e,createdTick=os.clock(),createdTrace=debug.traceback()},P);end;P.is=function(a)if type(a)=="table"then local e=getmetatable(a);if type(e)=="table"then return  v102 (a,"error")~=nil and type( v102 (e,"extend"))=="function";end;end;return false;end;P.isKind=function(a,e)assert(e~=nil,"Argument #2 to Promise.Error.isKind must not be nil");return P.is(a)and a.kind==e;end;P.extend=function(a,e)e=e or{};e.kind=e.kind or a.kind;return P.new(e,a);end;P.getErrorChain=function(a)local e={a};while e[#e].parent do table.insert(e,e[#e].parent);end;return e;end;P.__tostring=function(a)local e={string.format("-- Promise.Error(%s) --",a.kind or"?")};for c,c_36 in ipairs(a:getErrorChain())do table.insert(e,table.concat({c_36.trace or c_36.error,c_36.context},"\10"));end;return table.concat(e,"\10");end;local function a(...)return select("#",...),{...};end;local function e(c,...)return c,select("#",...),{...};end;local function c(E)assert(E~=nil,"traceback is nil");return function(p)if type(p)=="table"then return p;end;return P.new({error=p,kind=P.Kind.ExecutionError,trace=debug.traceback(tostring(p),2),context="Promise created at:\10\10"..E});end;end;local function E(p,T,...)return e(xpcall(T,c(p),...));end;local function e_37(c,p,T,t)return function(...)local x,S,J=E(c,p,...);if x then T(unpack(J,1,S));else t(J[1]);end;end;end;local function c_38(p)return next(p)==nil;end;local p:any={Error=P,Status=N("Promise.Status",{"Started","Resolved","Rejected","Cancelled"}),_getTime=os.clock,_timeEvent=game:GetService("RunService").Heartbeat,_unhandledRejectionCallbacks={},prototype={}};p.__index=p.prototype;p._new=function(N,T,t)if t~=nil and not p.is(t)then error("Argument #2 to Promise.new must be a promise or nil",2);end;local x={_thread=nil,_source=N,_status=p.Status.Started,_values=nil,_valuesLength=-1,_unhandledRejection=true,_queuedResolve={},_queuedReject={},_queuedFinally={},_cancellationHook=nil,_parent=t,_consumers=setmetatable({},I)};if t and t._status==p.Status.Started then t._consumers[x]=true;end;setmetatable(x,p);local function I(...)x:_resolve(...);end;local function N_39(...)x:_reject(...);end;local function t_40(S)if S then if x._status==p.Status.Cancelled then S();else x._cancellationHook=S;end;end;return x._status==p.Status.Cancelled;end;x._thread=coroutine.create(function()local S,_J,J_41=E(x._source,T,I,N_39,t_40);if not S then N_39(J_41[1]);end;end);task.spawn(x._thread);return x;end;p.new=function(I)return p._new(debug.traceback(nil,2),I);end;p.__tostring=function(I)return string.format("Promise(%s)",I._status);end;p.defer=function(I)local N=debug.traceback(nil,2);return(p._new(N,function(T,t,x)local S;S=p._timeEvent:Connect(function()S:Disconnect();local S,_J_42,J_43=E(N,I,T,t,x);if not S then t(J_43[1]);end;end);end));end;p.async=p.defer;p.resolve=function(...)local I,N=a(...);return p._new(debug.traceback(nil,2),function(E)E(unpack(N,1,I));end);end;p.reject=function(...)local I,N=a(...);return p._new(debug.traceback(nil,2),function(E,E_44)E_44(unpack(N,1,I));end);end;p._try=function(I,N,...)local E,T=a(...);return p._new(I,function(I)I(N(unpack(T,1,E)));end);end;p.try=function(I,...)return p._try(debug.traceback(nil,2),I,...);end;p._all=function(I,N,E)if type(N)~="table"then error(string.format("Please pass a list of promises to %s","Promise.all"),3);end;for T,t in pairs(N)do if not p.is(t)then error(string.format("Non-promise value passed into %s at index %s","Promise.all",tostring(T)),3);end;end;if#N==0 or E==0 then return p.resolve({});end;return p._new(I,function(I,T,t)local x,S,J,B,X={},{},0,0,false;local function H()for k,k_45 in ipairs(S)do k_45:cancel();end;end;local function k(D,...)if X then return;end;J+=1;if E==nil then x[D]=...;else x[J]=...;end;if J>=(E or#N)then X=true;I(x);H();end;end;t(H);for I,t in ipairs(N)do S[I]=t:andThen(function(...)k(I,...);end,function(...)B+=1;if E==nil or#N-B<E then H();X=true;T(...);end;end);end;if X then H();end;end);end;p.all=function(I)return p._all(debug.traceback(nil,2),I);end;p.fold=function(I,N,E)assert(type(I)=="table","Bad argument #1 to Promise.fold: must be a table");assert(W(N),"Bad argument #2 to Promise.fold: must be a function");local T=p.resolve(E);return p.each(I,function(I,E)T=T:andThen(function(t)return N(t,I,E);end);end):andThen(function()return T;end);end;p.some=function(I,N)assert(type(N)=="number","Bad argument #2 to Promise.some: must be a number");return p._all(debug.traceback(nil,2),I,N);end;p.any=function(I)return p._all(debug.traceback(nil,2),I,1):andThen(function(I)return I[1];end);end;p.allSettled=function(I)if type(I)~="table"then error(string.format("Please pass a list of promises to %s","Promise.allSettled"),2);end;for N,E in pairs(I)do if not p.is(E)then error(string.format("Non-promise value passed into %s at index %s","Promise.allSettled",tostring(N)),2);end;end;if#I==0 then return p.resolve({});end;return p._new(debug.traceback(nil,2),function(N,E,E_46)local T,t,x={},{},0;local function S(J,...)x+=1;T[J]=...;if x>=#I then N(T);end;end;E_46(function()for N,N_47 in ipairs(t)do N_47:cancel();end;end);for N,E in ipairs(I)do t[N]=E:finally(function(...)S(N,...);end);end;end);end;p.race=function(I)assert(type(I)=="table",string.format("Please pass a list of promises to %s","Promise.race"));for N,E in pairs(I)do assert(p.is(E),string.format("Non-promise value passed into %s at index %s","Promise.race",tostring(N)));end;return p._new(debug.traceback(nil,2),function(N,E,T)local t,x={},false;local function S()for J,J_48 in ipairs(t)do J_48:cancel();end;end;local function J(B)return function(...)S();x=true;return B(...);end;end;if T((J(E)))then return;end;for T,B in ipairs(I)do t[T]=B:andThen(J(N),(J(E)));end;if x then S();end;end);end;p.each=function(I,N)assert(type(I)=="table",string.format("Please pass a list of promises to %s","Promise.each"));assert(W(N),string.format("Please pass a handler function to %s!","Promise.each"));return p._new(debug.traceback(nil,2),function(E,T,t)local x,S,J={},{},false;local function B()for X,X_49 in ipairs(S)do X_49:cancel();end;end;t(function()J=true;B();end);t={};for X,H in ipairs(I)do if p.is(H)then if H:getStatus()==p.Status.Cancelled then B();return T(P.new({error="Promise is cancelled",kind=P.Kind.AlreadyCancelled,context=string.format("The Promise that was part of the array at index %d passed into Promise.each was already cancelled when Promise.each began.\10\10That Promise was created at:\10\10%s",X,H._source)}));elseif H:getStatus()==p.Status.Rejected then B();return T(select(2,H:await()));end;local I=H:andThen(function(...)return...;end);table.insert(S,I);t[X]=I;else t[X]=H;end;end;for I,X in ipairs(t)do if p.is(X)then local t_50;t_50,X=X:await();if not t_50 then B();return T(X);end;end;if J then return;end;local t_51=p.resolve(N(X,I));table.insert(S,t_51);local N,S_52=t_51:await();if not N then B();return T(S_52);end;x[I]=S_52;end;E(x);return nil end);end;p.is=function(I)if type(I)~="table"then return false;end;local N=getmetatable(I);if N==p then return true;elseif N==nil then return W(I.andThen);elseif type(N)=="table"and type( v102 (N,"__index"))=="table"and(W( v102 ( v102 (N,"__index"),"andThen")))then return true;end;return false;end;p.promisify=function(l)return function(...)return p._try(debug.traceback(nil,2),l,...);end;end;do local l,I_53;p.delay=function(N)assert(type(N)=="number","Bad argument #1 to Promise.delay, must be a number.");if not(N>=0.016666666666666666)or N==math.huge then N=0.016666666666666666;end;return p._new(debug.traceback(nil,2),function(E,T,t)T=p._getTime();local x=T+N;local N={resolve=E,startTime=T,endTime=x};if I_53==nil then l=N;I_53=p._timeEvent:Connect(function()local S=p._getTime();while l~=nil and l.endTime<S do local S_54=l;local J=S_54;l=S_54.next;if l==nil then I_53:Disconnect();I_53=nil;else l.previous=nil;end;J.resolve(p._getTime()-J.startTime);end;end);elseif l.endTime<x then T=l;E=T.next;while E~=nil and E.endTime<x do E,T=E.next,E;end;T.next=N;N.previous=T;if E~=nil then N.next=E;E.previous=N;end;else N.next=l;l.previous=N;l=N;end;t(function()local E=N.next;if l==N then if E==nil then I_53:Disconnect();I_53=nil;else E.previous=nil;end;l=E;else local l=N.previous;l.next=E;if E~=nil then E.previous=l;end;end;end);end);end;end;p.prototype.timeout=function(l,I,N)local E=debug.traceback(nil,2);return p.race({p.delay(I):andThen(function()return p.reject(N==nil and(P.new({kind=P.Kind.TimedOut,error="Timed out",context=string.format("Timeout of %d seconds exceeded.\10:timeout() called at:\10\10%s",I,E)}))or N);end),l});end;p.prototype.getStatus=function(l)return l._status;end;p.prototype._andThen=function(l,I,N,E)l._unhandledRejection=false;if l._status==p.Status.Cancelled then local T=p.new(function()end);T:cancel();return T;end;return p._new(I,function(T,t,x)local S=T;if N then S=e_37(I,N,T,t);end;local N=t;if E then N=e_37(I,E,T,t);end;if l._status==p.Status.Started then table.insert(l._queuedResolve,S);table.insert(l._queuedReject,N);x(function()if l._status==p.Status.Started then table.remove(l._queuedResolve,table.find(l._queuedResolve,S));table.remove(l._queuedReject,table.find(l._queuedReject,N));end;end);elseif l._status==p.Status.Resolved then S(unpack(l._values,1,l._valuesLength));elseif l._status==p.Status.Rejected then N(unpack(l._values,1,l._valuesLength));end;end,l);end;p.prototype.andThen=function(l,I,N)assert(I==nil or(W(I)),string.format("Please pass a handler function to %s!","Promise:andThen"));assert(N==nil or(W(N)),string.format("Please pass a handler function to %s!","Promise:andThen"));return l:_andThen(debug.traceback(nil,2),I,N);end;p.prototype.catch=function(l,I)assert(I==nil or(W(I)),string.format("Please pass a handler function to %s!","Promise:catch"));return l:_andThen(debug.traceback(nil,2),nil,I);end;p.prototype.tap=function(l,I)assert(W(I),string.format("Please pass a handler function to %s!","Promise:tap"));return l:_andThen(debug.traceback(nil,2),function(...)local l=I(...);if p.is(l)then local I,N=a(...);return l:andThen(function()return unpack(N,1,I);end);end;return...;end);end;p.prototype.andThenCall=function(l,I,...)assert(W(I),string.format("Please pass a handler function to %s!","Promise:andThenCall"));local N,e=a(...);return l:_andThen(debug.traceback(nil,2),function()return I(unpack(e,1,N));end);end;p.prototype.andThenReturn=function(l,...)local I,N=a(...);return l:_andThen(debug.traceback(nil,2),function()return unpack(N,1,I);end);end;p.prototype.cancel=function(l)if l._status~=p.Status.Started then return;end;l._status=p.Status.Cancelled;if l._cancellationHook then l._cancellationHook();end;coroutine.close(l._thread);if l._parent then l._parent:_consumerCancelled(l);end;for I in pairs(l._consumers)do I:cancel();end;l:_finalize();end;p.prototype._consumerCancelled=function(l,I)if l._status~=p.Status.Started then return;end;l._consumers[I]=nil;if next(l._consumers)==nil then l:cancel();end;end;p.prototype._finally=function(l,I,N)l._unhandledRejection=false;return(p._new(I,function(I,e,E)local T;E(function()l:_consumerCancelled(l);if T then T:cancel();end;end);E=if N then function(...)local t=N(...);if p.is(t)then T=t;t:finally(function(N)if N~=p.Status.Rejected then I(l);end;end):catch(function(...)e(...);end);else I(l);end;end else I;if l._status==p.Status.Started then table.insert(l._queuedFinally,E);else E(l._status);end;end));end;p.prototype.finally=function(l,I)assert(I==nil or(W(I)),string.format("Please pass a handler function to %s!","Promise:finally"));return l:_finally(debug.traceback(nil,2),I);end;p.prototype.finallyCall=function(l,I,...)assert(W(I),string.format("Please pass a handler function to %s!","Promise:finallyCall"));local N,e=a(...);return l:_finally(debug.traceback(nil,2),function()return I(unpack(e,1,N));end);end;p.prototype.finallyReturn=function(l,...)local I,N=a(...);return l:_finally(debug.traceback(nil,2),function()return unpack(N,1,I);end);end;p.prototype.awaitStatus=function(l)l._unhandledRejection=false;if l._status==p.Status.Started then local I=coroutine.running();l:finally(function()task.spawn(I);end):catch(function()end);coroutine.yield();end;if l._status==p.Status.Resolved then return l._status,unpack(l._values,1,l._valuesLength);elseif l._status==p.Status.Rejected then return l._status,unpack(l._values,1,l._valuesLength);end;return l._status;end;local function l(I,...)return I==p.Status.Resolved,...;end;p.prototype.await=function(I)return l(I:awaitStatus());end;local function l_55(I,...)if I~=p.Status.Resolved then error(...==nil and"Expected Promise rejected with no value."or(...),3);end;return...;end;p.prototype.expect=function(I)return l_55(I:awaitStatus());end;p.prototype.awaitValue=p.prototype.expect;p.prototype._unwrap=function(l)if l._status==p.Status.Started then error("Promise has not resolved or rejected.",2);end;return l._status==p.Status.Resolved,unpack(l._values,1,l._valuesLength);end;p.prototype._resolve=function(l,...)if l._status~=p.Status.Started then if p.is(...)then(...):_consumerCancelled(l);end;return;end;if p.is(...)then if select("#",...)>1 then warn((string.format("When returning a Promise from andThen, extra arguments are discarded! See:\10\10%s",l._source)));end;local I=...;local N=I:andThen(function(...)l:_resolve(...);end,function(...)local e=I._values[1];e=if I._error then(P.new({error=I._error,kind=P.Kind.ExecutionError,context="No stack trace available as this Promise originated from an older version of the Promise library (< v2)"}))else e;if P.isKind(e,P.Kind.ExecutionError)then return l:_reject(e:extend({error="This Promise was chained to a Promise that errored.",trace="",context=string.format("The Promise at:\10\10%s\10...Rejected because it was chained to the following Promise, which encountered an error:\10",l._source)}));end;l:_reject(...);return nil end);if N._status==p.Status.Cancelled then l:cancel();elseif N._status==p.Status.Started then l._parent=N;N._consumers[l]=true;end;return;end;l._status=p.Status.Resolved;l._valuesLength,l._values=a(...);for I,I_56 in ipairs(l._queuedResolve)do coroutine.wrap(I_56)(...);end;l:_finalize();end;p.prototype._reject=function(l,...)if l._status~=p.Status.Started then return;end;l._status=p.Status.Rejected;l._valuesLength,l._values=a(...);if not c_38(l._queuedReject)then for I,I_57 in ipairs(l._queuedReject)do coroutine.wrap(I_57)(...);end;else local I=tostring(...);coroutine.wrap(function()p._timeEvent:Wait();if not l._unhandledRejection then return;end;local N=string.format("Unhandled Promise rejection:\10\10%s\10\10%s",I,l._source);for I,I_58 in ipairs(p._unhandledRejectionCallbacks)do task.spawn(I_58,l,unpack(l._values,1,l._valuesLength));end;if p.TEST then return;end;warn(N);end)();end;l:_finalize();end;p.prototype._finalize=function(l)for I,I_59 in ipairs(l._queuedFinally)do coroutine.wrap(I_59)(l._status);end;l._queuedFinally=nil;l._queuedReject=nil;l._queuedResolve=nil;if not p.TEST then l._parent=nil;l._consumers=nil;end;task.defer(coroutine.close,l._thread);end;p.prototype.now=function(l,I)local N=debug.traceback(nil,2);if l._status==p.Status.Resolved then return l:_andThen(N,function(...)return...;end);else return p.reject(I==nil and(P.new({kind=P.Kind.NotResolvedInTime,error="This Promise was not resolved in time for :now()",context=":now() was called at:\10\10"..N}))or I);end;end;p.retry=function(l,I,...)assert(W(l),"Parameter #1 to Promise.retry must be a function");assert(type(I)=="number","Parameter #2 to Promise.retry must be a number");local N,P={...},select("#",...);return p.resolve(l(...)):catch(function(...)if I>0 then return p.retry(l,I-1,unpack(N,1,P));else return p.reject(...);end;end);end;p.retryWithDelay=function(l,I,N,...)assert(W(l),"Parameter #1 to Promise.retry must be a function");assert(type(I)=="number","Parameter #2 (times) to Promise.retry must be a number");assert(type(N)=="number","Parameter #3 (seconds) to Promise.retry must be a number");local W,P={...},select("#",...);return p.resolve(l(...)):catch(function(...)if I>0 then p.delay(N):await();return p.retryWithDelay(l,I-1,N,unpack(W,1,P));else return p.reject(...);end;end);end;p.fromEvent=function(l,I)I=I or function()return true;end;return p._new(debug.traceback(nil,2),function(W,N,N_60)local P;local a=false;local function e()P:Disconnect();P=nil;end;P=l:Connect(function(...)local l=I(...);if l==true then W(...);if P then e();else a=true;end;elseif type(l)~="boolean"then error("Promise.fromEvent predicate should always return a boolean");end;end);if a and P then e();return;end;N_60(e);end);end;p.onUnhandledRejection=function(l)table.insert(p._unhandledRejectionCallbacks,l);return function()local I=table.find(p._unhandledRejectionCallbacks,l);if I then table.remove(p._unhandledRejectionCallbacks,I);end;end;end;return p;end

tbl17.ay = function()
local ay = tbl17.cache.ay

if not ay then
local ay2 = { c = fn35() }
tbl17.cache.ay = ay2
ay = ay2
end

return ay.c
end
end
do -- az
local function fn35()
local v115 = tbl17.b()
local v116 = tbl17.ay()
local v117 = tbl17.a()
local v118 = tbl17.e()
local v119 = cloneref(game:GetService(v86[182]))

local tbl18 = {
Arial = Enum.Font.Arial,
Roboto = Enum.Font.Roboto,
Ubuntu = Enum.Font.Ubuntu,
Inconsolata = Enum.Font.Code,
}

local tbl19 = {
Minecraftia = {
Url = "https://github.com/kiciahook-org/v3-assets/raw/refs/heads/main/Minecraftia-Regular.ttf",
FileName = "Minecraftia-Regular.ttf",
Weight = Enum.FontWeight.Regular,
Style = Enum.FontStyle.Normal,
},
[v86[43]] = {
Url = "https://github.com/kiciahook-org/v3-assets/raw/refs/heads/main/Proggy-Clean.ttf",
FileName = "Proggy-Clean.ttf",
Weight = Enum.FontWeight.Regular,
Style = Enum.FontStyle.Normal,
},
[v86[125]] = {
Url = "https://github.com/kiciahook-org/v3-assets/raw/refs/heads/main/Proggy-Tiny.ttf",
FileName = "Proggy-Tiny.ttf",
Weight = Enum.FontWeight.Regular,
Style = Enum.FontStyle.Normal,
},
}

local font = Font.fromEnum(Enum.Font.SourceSans)

local index2 = {
Order = { "Minecraftia", "Proggy Clean", v86[125], "Arial", v86[24], "Ubuntu", "Inconsolata" },
}

index2.__index = index2

local function fn36(arg)
return arg == Enum.FontStyle.Italic and "italic" or "normal"
end

local function fn37(arg, arg2)
return v116.new(function(arg3)
local str7 = string.format("%s/%s", "kiciarebuild/fonts", tostring(arg2.FileName))

if not isfile(str7) then
local v120, v121 = v107(function()
return game:HttpGet(arg2.Url)
end)

if not v120 or type(v121) ~= "string" then
local v122 = tostring
arg3(v117.err("Fonts", "fetch", string.format("HttpGet failed for %s: %s", tostring(arg2.Url), v122(v121))))
return
end

local v122, v123 = v107(writefile, str7, v121)

if not v122 then
local v124 = tostring
arg3(v117.err("Fonts", "write", string.format("writefile failed for %s: %s", tostring(str7), v124(v123))))
return
end
end

local v120, v121 = v107(getcustomasset, str7)
local flag19 = not v120

if not flag19 then
local v122 = v86[165]
flag19 = type(v121) ~= v122
end

if flag19 then
local v122 = tostring
arg3(v117.err("Fonts", "asset", string.format("getcustomasset failed for %s: %s", tostring(str7), v122(v121))))
return
end

local tbl20 = {
name = arg,
faces = { { name = "Regular", weight = arg2.Weight.Value, style = fn36(arg2.Style), assetId = v121 } },
}

local str8 = string.format("%s/%s.json", "kiciarebuild/fonts", tostring(arg))
local v122, v123 = v107(writefile, str8, v119:JSONEncode(tbl20))

if not v122 then
local v124 = tostring
arg3(v117.err("Fonts", v86[166], string.format("writefile failed for %s: %s", tostring(str8), v124(v123))))
return
end

local v124, v125 = v107(getcustomasset, str8)

if not v124 or type(v125) ~= "string" then
local v126 = tostring
arg3(v117.err(v86[104], v86[151], string.format("getcustomasset failed for %s: %s", tostring(str8), v126(v125))))
return
end

arg3(v117.ok(Font.new(v125, arg2.Weight, arg2.Style)))
end)
end

index2._New = function()
return setmetatable({ _initialized = false, _fontByName = {} }, index2)
end

index2.Initialize = function(arg)
if arg._initialized then
return v117.VoidOk
end
arg._initialized = true

for k, v120 in tbl18, nil, nil do
arg._fontByName[k] = Font.fromEnum(v120)
end

v118("kiciarebuild/fonts")
local tbl20 = {}
local flag19 = true

for k, v120 in tbl19, nil, nil do
table.insert(tbl20, fn37(k, v120):andThen(function(arg2)
if arg2.Ok then
arg._fontByName[k] = arg2.Value
else
arg._fontByName[k] = font
flag19 = false
v115.get():Report(arg2.Error)
end
end))
end

v116.all(tbl20):await()
return flag19 and v117.VoidOk or v117.err("Fonts", "Initialize", "Failed to load all fonts")
end

index2.Get = function(arg, arg2)
return arg._fontByName[arg2] or font
end

return index2._New()
end

tbl17.az = function()
local az = tbl17.cache.az

if not az then
az = { c = fn35() }
tbl17.cache.az = az
end

return az.c
end
end
do -- aA
local function fn35()
local v115 = tbl17.k()
local tweenService = tbl17.t().TweenService
local index2 = {}
index2.__index = index2
local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfo2 = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfo3 = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function fn36(arg)
return math.ceil(arg * 1.25) + 10
end

local tbl18 = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }

local function fn37(arg)
return (arg:gsub("[&<>]", tbl18))
end

local function fn38(arg, arg2, arg3)
if type(arg) == "string" then
return arg
end
local v116 = table.create(#arg)

for k, v117 in arg, nil, nil do
local v118 = (v117.Accent and arg3 or v117.Color or arg2):ToHex()
local v119 = fn37(v117.Text)
v116[k] = string.format("<font color=\"#%s\">%s</font>", tostring(v118), tostring(v119))
end

return table.concat(v116, "")
end

local function fn39(arg, arg2)
return UDim2.new(arg, 0, 0.5, arg2)
end

index2.new = function(arg, arg2, arg3, arg4, arg5)
local v116 = v115.new()
local v117 = v116:Extend()
local alignX = arg.AlignX
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Size = UDim2.new(v86[63], v86[186], 0, fn36(arg3.Size))
frame.LayoutOrder = arg.Order
v116:Add(frame)
local instance = Instance.new(v86[128])
instance.BackgroundColor3 = arg3.Background
instance.BackgroundTransparency = 1
instance.BorderSizePixel = 0
instance.AnchorPoint = Vector2.new(alignX, 0.5)
instance.Position = fn39(alignX, -v86[9])
instance.Size = UDim2.fromOffset(v86[186], 0)
instance.AutomaticSize = Enum.AutomaticSize.XY
instance.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[26])
uiCorner.Parent = instance
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = arg3.Accent
uiStroke.Transparency = 1
uiStroke.Parent = instance
local instance2 = Instance.new(v86[113])
instance2.PaddingTop = UDim.new(0, 5)
instance2.PaddingBottom = UDim.new(v86[186], 5)
instance2.PaddingLeft = UDim.new(v86[186], 10)
instance2.PaddingRight = UDim.new(v86[186], v86[133])
instance2.Parent = instance
local textLabel = Instance.new("TextLabel")
textLabel.BackgroundTransparency = 1
textLabel.BorderSizePixel = 0
textLabel.Size = UDim2.fromOffset(0, 0)
textLabel.AutomaticSize = Enum.AutomaticSize.XY
textLabel.FontFace = arg3.Font
textLabel.RichText = true
textLabel.Text = fn38(arg2, arg3.TextColor, arg3.Accent)
textLabel.TextColor3 = arg3.TextColor
textLabel.TextSize = arg3.Size
textLabel.TextTransparency = v86[63]
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Center
textLabel.Parent = instance
frame.Parent = arg.Parent

local tbl19 = {
_trove = v116,
_motionTrove = v117,
_ghost = frame,
_bar = instance,
_stroke = uiStroke,
_label = textLabel,
_alignX = alignX,
_dismissing = false,
_destroyed = false,
_onDestroyed = arg5,
}

setmetatable(tbl19, index2)
tbl19:_AnimateIn()

if arg4 > 0 then
v116:Add(task.delay(arg4, function()
tbl19:Dismiss()
end))
end

return tbl19
end

index2._AnimateIn = function(arg)
local trove = arg._trove
local motionTrove = arg._motionTrove
local bar = arg._bar
trove:Add(tweenService:Create(bar, tweenInfo, { BackgroundTransparency = 0.4 })):Play()
trove:Add(tweenService:Create(arg._stroke, tweenInfo, { Transparency = 0.4 })):Play()
trove:Add(tweenService:Create(arg._label, tweenInfo, { TextTransparency = v86[186] })):Play()
local v116 = motionTrove:Add(tweenService:Create(bar, tweenInfo, { Position = fn39(arg._alignX, 4) }))

motionTrove:Connect(v116.Completed, function()
if arg._dismissing then
return
end
motionTrove:Add(tweenService:Create(bar, tweenInfo2, { Position = fn39(arg._alignX, v86[186]) })):Play()
end)

v116:Play()
end

index2.SetLayout = function(arg, arg2)
if arg._destroyed then
return
end
arg._motionTrove:Clean()
arg._alignX = arg2.AlignX
arg._ghost.LayoutOrder = arg2.Order
arg._bar.AnchorPoint = Vector2.new(arg2.AlignX, v86[101])

if arg._dismissing then
arg:_AnimateOut()
else
arg._bar.Position = fn39(arg2.AlignX, 0)
end
end

index2._AnimateOut = function(arg)
local v116 = arg._motionTrove:Add(tweenService:Create(arg._bar, tweenInfo3, { Position = fn39(arg._alignX, -v86[9]), BackgroundTransparency = v86[63] }))

arg._motionTrove:Connect(v116.Completed, function()
arg:Destroy()
end)

v116:Play()
end

index2.Dismiss = function(arg)
if arg._dismissing then
return
end
arg._dismissing = true
arg._trove:Add(tweenService:Create(arg._stroke, tweenInfo3, { Transparency = 1 })):Play()
-- (fix) decompiler dropped the receiver: v116 was never assigned, so this crashed on Dismiss
arg._trove:Add(tweenService:Create(arg._label, tweenInfo3, { TextTransparency = v86[63] })):Play()
arg:_AnimateOut()
end

index2.Destroy = function(arg)
if arg._destroyed then
return
end
arg._destroyed = true
arg._trove:Destroy()
arg._onDestroyed()
end

return index2
end

tbl17.aA = function()
local aa = tbl17.cache.aA

if not aa then
local aa2 = { c = fn35() }
tbl17.cache.aA = aa2
aa = aa2
end

return aa.c
end
end
do -- aB
local function fn35()
tbl17.r()
local v115 = tbl17.aA()
local v116 = tbl17.t()
local v117 = tbl17.k()
local v118 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36()
local currentCamera = workspace.CurrentCamera
if currentCamera == nil then
return 16, 16, 16, 16
end
local insetArea = v116.GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
local viewportSize = currentCamera.ViewportSize
local n = v86[13] + math.max(0, insetArea.Min.X)
local n33 = v86[13] + math.max(0, insetArea.Min.Y)
local n34 = 16 + math.max(0, viewportSize.X - insetArea.Max.X)
return n33, v86[13] + math.max(v86[186], viewportSize.Y - insetArea.Max.Y), n, n34
end

local tbl18 = {
TopLeft = { AlignX = 0, Valign = Enum.VerticalAlignment.Top },
TopRight = { AlignX = 1, Valign = Enum.VerticalAlignment.Top },
BottomLeft = { AlignX = 0, Valign = Enum.VerticalAlignment.Bottom },
BottomRight = { AlignX = 1, Valign = Enum.VerticalAlignment.Bottom },
Center = { AlignX = v86[101], Valign = Enum.VerticalAlignment.Top },
Crosshair = { AlignX = 0.5, Valign = Enum.VerticalAlignment.Center, Crosshair = true },
}

index2.SideSpecs = { "TopLeft", "TopRight", "BottomLeft", v86[52], "Center", "Crosshair" }

local tbl19 = {
success = Color3.fromRGB(72, 199, v86[15]),
warning = Color3.fromRGB(255, 183, v86[109]),
error = Color3.fromRGB(v86[79], v86[58], 82),
}

local v119 = nil

index2.use = function(arg, arg2, arg3, arg4, displayOrder)
if v119 ~= nil then
return v119
end
local v120 = v117.new()
local v121 = v120:Add(Instance.new("ScreenGui"))
v121.IgnoreGuiInset = true
v121.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
v121.DisplayOrder = displayOrder
v121.Parent = gethui()
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Size = UDim2.fromScale(v86[63], 1)
frame.Parent = v121
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(v86[186], v86[13])
uiPadding.PaddingBottom = UDim.new(0, 16)
uiPadding.PaddingLeft = UDim.new(0, 16)
uiPadding.PaddingRight = UDim.new(0, 16)
uiPadding.Parent = frame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, v86[54])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame

local tbl20 = {
_trove = v120,
_config = arg,
_pathByKey = {
Enabled = v118.appendPath(arg2, "Enabled"),
Side = v118.appendPath(arg2, "Side"),
Size = v118.appendPath(arg2, "Size"),
Font = v118.appendPath(arg2, v86[59]),
Offset = v118.appendPath(arg2, "Offset"),
ThemeAccent = v118.appendPath(arg3, "Accent"),
ThemeBackground = v118.appendPath(arg3, "Background"),
ThemeText = v118.appendPath(arg3, "TextColor"),
TextColor = v118.appendPath(arg3, "TextColor"),
},
_resolveFont = arg4,
_container = frame,
_margin = uiPadding,
_list = uiListLayout,
_stack = {},
_counter = v86[186],
_destroyed = false,
}

setmetatable(tbl20, index2)

v120:Connect(arg:GetPropertyChangedSignal(tbl20._pathByKey.Side), function()
tbl20:_ApplyLayout()
end)

v120:Connect(arg:GetPropertyChangedSignal(tbl20._pathByKey.Offset), function()
tbl20:_ApplyLayout()
end)

v120:Connect(arg:GetPropertyChangedSignal(tbl20._pathByKey.Enabled), function()
if not tbl20:_ApplyLayout() then
tbl20:Clear()
end
end)

v118.connectCurrentCameraViewport(v120, function()
tbl20:_ApplyLayout()
end)

v119 = tbl20
return tbl20
end

index2.get = function()
assert(v119, "Notifications is not ready yet")
return v119
end

index2.template = function(arg, arg2)
local tbl20 = {}
local n = 1

while v86[34] do
local pos, v120, v121 = arg:find("%%(%w+)%%", n)

if not (pos == nil or v120 == nil or v121 == nil) then
if n < pos then
table.insert(tbl20, { Text = arg:sub(n, pos - 1) })
end

local v122 = arg2[v121]

if v122 ~= nil then
table.insert(tbl20, { Text = v122, Accent = v86[34] })
else
table.insert(tbl20, { Text = arg:sub(pos, v120) })
end

n = v120 + 1
continue
end

break
end

if n <= #arg then
table.insert(tbl20, { Text = arg:sub(n) })
end

return tbl20
end

index2._Get = function(arg, arg2)
local _p = arg._pathByKey[arg2]
if _p == nil then return nil end
return arg._config:Get(_p, true)
end

index2._SideSpec = function(arg)
return tbl18[arg:_Get(v86[50])] or tbl18.TopRight
end

index2._ResolveTheme = function(arg, arg2)
local color = arg2.Color
local intent = arg2.Intent

if color == nil and intent ~= nil then
color = tbl19[intent]
end

return {
Accent = color or arg:_Get("ThemeAccent"),
Background = arg:_Get("ThemeBackground"),
TextColor = arg:_Get(v86[57]),
Font = arg._resolveFont(arg:_Get("Font")),
Size = arg:_Get(v86[29]),
}
end

index2._ApplyLayout = function(arg)
local v120 = arg:_SideSpec()
local n, n33, v121, v122 = fn36()

if v120.Crosshair then
n33 = 16
n = 16
end

arg._margin.PaddingTop = UDim.new(0, n)
arg._margin.PaddingBottom = UDim.new(0, n33)
arg._margin.PaddingLeft = UDim.new(0, v121)
arg._margin.PaddingRight = UDim.new(v86[186], v122)
local visible = arg:_Get(v86[44]) == true
arg._container.Visible = visible

if v120.Crosshair then
local Offset = arg:_Get("Offset") or 0

if Offset >= 0 then
arg._list.VerticalAlignment = Enum.VerticalAlignment.Top
arg._container.Position = UDim2.new(0, v86[186], 0.5, Offset)
arg._container.Size = UDim2.new(1, 0, 0.5, -Offset)
else
arg._list.VerticalAlignment = Enum.VerticalAlignment.Bottom
arg._container.Position = UDim2.fromScale(v86[186], 0)
arg._container.Size = UDim2.new(v86[63], 0, 0.5, Offset)
end
else
arg._list.VerticalAlignment = v120.Valign
arg._container.Position = UDim2.fromScale(0, 0)
arg._container.Size = UDim2.fromScale(1, 1)
end

for k, v123 in arg._stack, nil, nil do
v123:SetLayout({
Parent = arg._container,
Order = arg._list.VerticalAlignment == Enum.VerticalAlignment.Bottom and k or -k,
AlignX = v120.AlignX,
})
end

return visible
end

index2.Notify = function(arg, arg2, arg3)
if arg._destroyed or not arg:_Get("Enabled") then
return
end
arg3 = arg3 or {}
local v120 = arg:_SideSpec()
arg._counter = arg._counter + 1

local tbl20 = {
Parent = arg._container,
Order = arg._list.VerticalAlignment == Enum.VerticalAlignment.Bottom and arg._counter or -arg._counter,
AlignX = v120.AlignX,
}

local lifetime = arg3.Lifetime or 6
local new = nil

local function fn37()
local v121 = table.find(arg._stack, new)

if v121 ~= nil then
table.remove(arg._stack, v121)
end
end

new = v115.new
new = new(tbl20, arg2, arg:_ResolveTheme(arg3), lifetime, fn37)
table.insert(arg._stack, new)

while #arg._stack > v86[160] do
arg._stack[v86[63]]:Destroy()
end
end

index2.Clear = function(arg)
if arg._destroyed then
return
end

for _, v120 in table.clone(arg._stack) do
v120:Dismiss()
end
end

index2.Destroy = function(arg)
if arg._destroyed then
return
end
arg._destroyed = true

for _, v120 in table.clone(arg._stack) do
v120:Destroy()
end

table.clear(arg._stack)
arg._trove:Destroy()

if v119 == arg then
v119 = nil
end
end

return index2
end

tbl17.aB = function()
local ab = tbl17.cache.aB

if not ab then
ab = { c = fn35() }
tbl17.cache.aB = ab
end

return ab.c
end
end
do -- aC
local function fn35()
tbl17.ab()
tbl17.r()
local v115 = tbl17.az()
tbl17.af()
local v116 = tbl17.aB()
tbl17.an()
local v117 = tbl17.u()
tbl17.ar()
local v118 = tbl17.A()
tbl17.k()
local v119 = tbl17.w()

local tbl18 = {
{ Key = v86[139], Label = "Accent" },
{ Key = "Background", Label = "Background" },
{ Key = "ElementBackground", Label = "Element Background" },
{ Key = "Outline", Label = "Outline" },
{ Key = "TabButtonSelected", Label = "Selected Tab" },
{ Key = "TextColor", Label = "Text" },
{ Key = v86[96], Label = v86[136] },
{ Key = "ToggleCircleUnselected", Label = "Toggle Circle" },
{ Key = "ToggleBackgroundUnselected", Label = "Toggle Background" },
}

local function fn36(arg, arg2, arg3)
local v120 = arg3:AddSection({ Title = "Menu", Side = "left" })
local stateData = arg:GetStateData()

if not v117.IsMobile() then
local v121 = v120:AddKeybind({
Label = v86[106],
Modes = { v86[194], v86[3] },
InKeybindList = true,
ListLabel = "Menu",
RegistrationKey = "settings/menu/keybind",
})

v121:SetFeatureEnabled(true)
v121:SetShowInList(stateData == nil or stateData.MenuKeybindInList ~= false, true)
v121:Set({ Key = arg.Keybind, Mode = v121.Value.Mode }, true)

v121:Connect(v121.ShowInListChanged, function(menuKeybindInList)
if stateData ~= nil then
stateData.MenuKeybindInList = menuKeybindInList
arg:SaveState()
end
end)

v121:OnChanged(function(arg4)
local keybind = arg4.Key
if typeof(keybind) ~= "EnumItem" then
return
end
arg.Keybind = keybind

if stateData ~= nil then
local v122 = v119.serializeKey(keybind)

if v122 ~= nil then
stateData.Keybind = v122
end

arg:SaveState()
end
end)
end

if not v117.IsMobile() then
v120:AddToggle({
Label = "Show Keybinds",
Default = arg2.IsKeybindListEnabled(),
OnChanged = arg2.SetKeybindListEnabled,
})
end

v120:AddToggle({ Label = v86[129], Default = arg2.IsWatermarkEnabled(), OnChanged = arg2.SetWatermarkEnabled })

if v117.WantsMobileButtons() then
v120:AddToggle({
Label = "Hide Floating Menu Button",
Default = stateData ~= nil and stateData.HideMobileMenuButton == true,
OnChanged = arg2.SetMenuPillHidden,
})

v120:AddButton({ Label = "Edit On-screen Keybinds", OnClick = arg2.EnterMobileButtonDragMode })
end
end

local function fn37(arg, arg2)
if arg.Ok then
return false
end
local str7 = tostring(arg.Error.Detail)
v116.get():Notify({ { Text = arg2 .. " failed: " }, { Text = str7 } })
return true
end

local function fn38(arg, arg2, arg3)
local persistence = arg:GetPersistence()
local stateData = arg:GetStateData()
local v120 = arg3:AddSection({ Title = "Whole-Menu Profiles", Side = v86[42] })
local v121 = arg3:AddSection({ Title = "Transfer", Side = "right" })
local v122 = arg3:AddSection({ Title = "Automation", Side = "right" })

local function fn39()
if persistence ~= nil then
return persistence:AllConfigs()
end
return {}
end

local v123 = fn39()
local v124 = v120:AddTextBox({ Label = "Config Name" })
local v125 = v120:AddButton({ Label = "Create Config" })
local v126 = v120:AddList({ Label = "Configs", Options = v123, Height = 140, Search = true })

local function fn40()
v126:SetOptions(fn39())
end

v125:Connect(v125.Clicked, function()
local str7 = v124.Value:gsub("%s+", "")
if str7 == "" then
return
end

if fn37(persistence:CreateDefault(str7), "Creating config") then
return
end
fn40()
v126:Set(str7)
end)

local v127 = v120:AddButton({ Label = "Refresh List" })

v120:AddButton({
Label = "Load Selected Config",
Confirm = true,
OnClick = function()
local value = v126.Value

if type(value) == "string" then
fn37(persistence:LoadFromFile(value), "Loading config")
end
end,
})

v120:AddButton({
Label = "Save to Selected Config",
Confirm = v86[34],
OnClick = function()
local value = v126.Value

if type(value) == "string" and value ~= "" then
fn37(persistence:SaveToFile(value), "Saving config")
end
end,
})

local v128 = v120:AddButton({ Label = "Delete Selected Config", Confirm = true })

v121:AddButton({
Label = "Export to Clipboard",
OnClick = function()
local v129 = persistence:ExportToJson()

if v129.Ok then
setclipboard(v129.Value)
v116.get():Notify("Copied your current config to the clipboard")
else
fn37(v129, "Exporting config")
end
end,
})

local v129 = v121:AddTextBox({ Label = "Import (paste config)", FocusLostOnly = true })

v121:AddButton({
Label = "Import Config",
Confirm = true,
OnClick = function()
local value = v129.Value

if value ~= "" then
fn37(persistence:LoadFromJson(value), "Importing config")
end
end,
})

local v130 = v122:AddToggle({ Label = "Auto Save" })
local v131 = v122:AddDropdown({ Label = "Profile to Auto Save", Options = v123, GetOptions = fn39, CloseOnSelect = true })
local v132 = v122:AddToggle({ Label = "Auto Load" })
local v133 = v122:AddDropdown({ Label = "Profile to Auto Load", Options = v123, GetOptions = fn39, CloseOnSelect = true })

v128:Connect(v128.Clicked, function()
local value = v126.Value
if type(value) ~= "string" then
return
end

if fn37(persistence:DeleteFile(value), "Deleting config") then
return
end

if stateData ~= nil then
if stateData.AutoSaveConfigName == value then
stateData.AutoSaveConfigName = nil
v131:Set(nil, true)
end

if stateData.AutoLoadConfigName == value then
stateData.AutoLoadConfigName = nil
v133:Set(nil, true)
end

arg:SaveState()
end

fn40()
end)

local function fn41()
if stateData == nil then
return
end
v130:Set(stateData.AutoSave, true)
v131:Set(stateData.AutoSaveConfigName, true)
v132:Set(stateData.AutoLoad, true)
v133:Set(stateData.AutoLoadConfigName, true)
local autoSaveConfigName = stateData.AutoSaveConfigName or stateData.AutoLoadConfigName

if autoSaveConfigName ~= nil then
v126:Set(autoSaveConfigName, true)
end
end

v127:Connect(v127.Clicked, function()
fn40()
fn41()
end)

fn41()

local function fn42()
if stateData == nil then
return
end
stateData.AutoSave = v130.Value
stateData.AutoLoad = v132.Value
local value = v131.Value
stateData.AutoSaveConfigName = type(value) == "string" and value ~= "" and value or nil
local value2 = v133.Value
stateData.AutoLoadConfigName = type(value2) == "string" and value2 ~= "" and value2 or nil
arg:SaveState()
end

v130:OnChanged(fn42)
v131:OnChanged(fn42)
v132:OnChanged(fn42)
v133:OnChanged(fn42)
local flag19 = v86[153]
local v134 = arg2:Extend()

arg2:Connect(persistence.Reloaded, function()
flag19 = false
v134:Clean()
end)

arg2:Connect(persistence.Changed, function()
if flag19 then
return
end
flag19 = v86[34]
v134:Clean()

v134:Add(task.defer(function()
flag19 = false
if stateData == nil or not stateData.AutoSave then
return
end
local autoSaveConfigName = stateData.AutoSaveConfigName

if autoSaveConfigName ~= nil then
fn37(persistence:SaveToFile(autoSaveConfigName), "Auto-saving config")
end
end))
end)
end

local function fn39(arg, arg2, arg3, arg4, arg5)
local v120 = arg4:AddTab({ Label = "Theme" })
local v121 = v120:Grid({ Columns = 1 })
local v122 = v121:AddSection({ Title = "Theme Colors", Side = "full" })
local config = arg:GetConfig()

local function fn40(arg6, arg7)
if arg6 == "Accent" then
arg2.SetAccent(arg7)
else
v118.refresh(arg6, arg7)
end
end

for _, v123 in tbl18, nil, nil do
local v124 = v118.get(v123.Key)
local v125

if config ~= nil then
local v126 = config:Get(v119.appendPath(arg5, v123.Key))

if typeof(v126) ~= "Color3" then
v125 = v124
else
v125 = v126
end
else
v125 = v124
end

fn40(v123.Key, v125)

local v126 = v122:AddColor({
Label = v123.Label,
Default = { Rgb = v125, Alpha = 1 },
OnChanged = function(arg6)
if config ~= nil then
local rgb = arg6.Rgb
config:Set(v119.appendPath(arg5, v123.Key), rgb)
else
fn40(v123.Key, arg6.Rgb)
end
end,
})

if config ~= nil then
arg3:Connect(config:Changed(v119.appendPath(arg5, v123.Key)), function(arg6)
if typeof(arg6) ~= "Color3" then
return
end
fn40(v123.Key, arg6)
v126:Set({ Rgb = arg6, Alpha = 1 }, true)
end)
end
end

return { Page = v120, Grid = v121 }
end

local function fn40(arg, arg2, arg3)
arg:AddToggle({ Label = "Re-run After Teleport", Config = arg3 })
local stateData = arg2:GetStateData()

arg:AddToggle({
Label = v86[142],
Default = stateData ~= nil and stateData.SilentLoad == true,
OnChanged = function(silentLoad)
if stateData ~= nil then
stateData.SilentLoad = silentLoad
arg2:SaveState()
end
end,
})
end

local function fn41(arg, arg2)
arg:AddToggle({ Label = "Enable Notifications", Config = v119.appendPath(arg2, "Enabled") })
arg:AddDropdown({ Label = v86[189], Options = v116.SideSpecs, Config = v119.appendPath(arg2, v86[50]) })

arg:AddSlider({
Label = "Crosshair Offset",
Tooltip = "Distance from screen center for the Crosshair side. Negative is above, positive below.",
Min = -500,
Max = 500,
Default = 0,
Suffix = "px",
Config = v119.appendPath(arg2, "Offset"),
})

arg:AddSlider({ Label = "Text Size", Min = v86[133], Max = 28, Config = v119.appendPath(arg2, "Size") })
arg:AddDropdown({ Label = "Font", Options = v115.Order, Config = v119.appendPath(arg2, v86[59]) })
end

return function(arg, arg2, arg3, arg4, arg5, arg6, arg7)
local v120 = arg2:AddTab({ Label = "General", Icon = "rbxassetid://106205298246017" })
local v121 = v120:Grid({ Columns = 2 })
fn36(arg, arg4, v121)
local v122 = arg2:AddTab({ Label = "Config Profiles" })
local v123 = v122:Grid({ Columns = 2 })
fn38(arg, arg3, v123)
local v124 = fn39(arg, arg4, arg3, arg2, arg5)
fn40(v121:AddSection({ Title = "Startup", Side = "left" }), arg, arg7)
fn41(v121:AddSection({ Title = "Notifications", Side = "right" }), arg6)
v121:AddSection({ Title = v86[199], Side = "right" }):AddButton({ Label = "Unload KiciaHook", Confirm = true, OnClick = arg4.Unload })
return { General = { Page = v120, Grid = v121 }, ConfigProfiles = { Page = v122, Grid = v123 }, Theme = v124 }
end
end

tbl17.aC = function()
local ac = tbl17.cache.aC

if not ac then
local ac2 = { c = fn35() }
tbl17.cache.aC = ac2
ac = ac2
end

return ac.c
end
end
do -- aD
local function fn35()
tbl17.r()
local v115 = tbl17.ag()
local v116 = tbl17.ac()
local v117 = tbl17.s()
local v118 = tbl17.ae()
local v119 = tbl17.ah()
local v120 = tbl17.ai()
local v121 = tbl17.aj()
local v122 = tbl17.ak()
local v123 = tbl17.u()
local v124 = tbl17.x()
local v125 = tbl17.al()
local v126 = tbl17.t()
local v127 = tbl17.g()
tbl17.ar()
local v128 = tbl17.A()
local v129 = tbl17.as()
local v130 = tbl17.k()
local v131 = tbl17.at()
local v132 = tbl17.w()
local v133 = tbl17.av()
local v134 = tbl17.ax()
local v135 = tbl17.aC()
local userInputService = v126.UserInputService
local runService = v126.RunService
local index2 = {}
index2.__index = index2
local semiBold = v117.SemiBold

local function fn36(arg)
local chrome = arg._chrome
assert(chrome ~= nil, "menu chrome accessed during construction")
return chrome
end

local function createScreenGui(displayOrder, enabled)
local screenGui = Instance.new("ScreenGui")
screenGui.Enabled = enabled
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = displayOrder
screenGui.OnTopOfCoreBlur = true
return screenGui
end

local function fn37(arg)
local chrome = arg._chrome
if chrome == nil then
return
end
local menuFrame = chrome.Window.MenuFrame
local v136 = v132.onScreenKeyboardTop()

if v136 == nil then
local keyboardBaseY = arg._keyboardBaseY

if keyboardBaseY ~= nil then
arg._keyboardBaseY = nil

if not arg.Dragging then
arg:Tween(menuFrame, { Position = UDim2.fromOffset(menuFrame.Position.X.Offset, keyboardBaseY) })
end
end

return
end

if arg.Dragging then
return
end
local focusedTextBox = userInputService:GetFocusedTextBox()
if focusedTextBox == nil or not focusedTextBox:IsDescendantOf(menuFrame) then
return
end
local n = v132.absoluteToLayerOffset(arg._gui, focusedTextBox.AbsolutePosition).Y + focusedTextBox.AbsoluteSize.Y + 8 - v136
if n <= v86[186] then
return
end
local offset = menuFrame.Position.Y.Offset

if arg._keyboardBaseY == nil then
arg._keyboardBaseY = offset
end

local n33 = math.max(0, math.floor(offset - n + 0.5))

if n33 ~= offset then
arg:Tween(menuFrame, { Position = UDim2.fromOffset(menuFrame.Position.X.Offset, n33) })
end
end

index2.new = function(arg)
local v136 = v130.new()
local directory = arg.Directory
v132.ensureStorageDirectories(directory)
local state = arg.State
local stateData = arg.StateData

if state == nil or stateData == nil then
state = v118.new(directory)
stateData = state:Load()
end

local v137 = createScreenGui(v86[45], v86[34])
local v138 = createScreenGui(v86[91], true)
local v139 = createScreenGui(110, false)
local v140 = v136:Add(v127.new())
local v141 = v122.new(v136, v139, v140)
local Default = semiBold

if arg.ResolveFont ~= nil then
Default = arg.ResolveFont("Default")
end

local obj = setmetatable({
_trove = v136,
Title = arg.Title or "khook.lua",
Icon = arg.Icon or "rbxassetid://118838006164746",
Directory = directory,
ConfigVersion = arg.ConfigVersion or v86[63],
Fonts = { Main = Default },
Visible = false,
Dragging = false,
Keybind = Enum.KeyCode.RightShift,
AccentChanged = v136:Add(v127.new()),
FontChanged = v136:Add(v127.new()),
VisibilityChanged = v140,
_gui = v138,
_hud = v137,
_overlay = v139,
_tweener = v131.new(),
_overlays = v141,
_cursor = v136:Add(v115.new(v136)),
_chrome = nil,
_dialog = nil,
_config = arg.Config,
_colorAnimation = arg.ColorAnimation,
_persistence = arg.Persistence,
_state = state,
_stateData = stateData,
_themePath = arg.ThemePath or { "Theme" },
_notificationPath = arg.NotificationPath or { "Notifications" },
_autoExecuteEnabledPath = arg.AutoExecuteEnabledPath or { "AutoExecuteScript", "Enabled" },
_onUnload = arg.OnUnload,
_watermarkUsername = v126.Players.LocalPlayer and v126.Players.LocalPlayer.Name or "Username",
_updateCallbackById = {},
_nextUpdateId = 0,
_updateCount = 0,
_renderConnection = nil,
_tooltip = nil,
_keybindCapture = nil,
_keybindList = nil,
_mobileButtons = nil,
_menuPill = nil,
_keyboardBaseY = nil,
}, index2)

local v142 = v132.deserializeKey(stateData and stateData.Keybind)

if typeof(v142) == "EnumItem" then
obj.Keybind = v142
end

local v143 = getthreadidentity()
setthreadidentity(8)

for _, v144 in { v137, v138, v139 }, nil, nil do
v136:Add(v144)
v144.Parent = v126.CoreGui
end

setthreadidentity(v143)
local tbl18 = { Title = obj.Title, Icon = obj.Icon, Username = obj._watermarkUsername }

obj._chrome = {
Window = v134.new(obj:View(), v138, v136, tbl18),
Watermark = v133.new(obj:View(), v137, v136, tbl18),
SearchPalette = v125.new(obj:View(), v136),
}

if not v123.IsMobile() then
obj._keybindList = v120.new(obj:View(), v137, v136)
end

if v123.WantsMobileButtons() then
local menuToggle = obj:RegisterMobileButton("menu_toggle", "Menu", "Toggle", function(arg2)
obj:SetVisible(arg2)
end)

obj._menuPill = menuToggle

if menuToggle ~= nil then
if stateData ~= nil and stateData.HideMobileMenuButton then
menuToggle:SetInvisible(v86[34])
end

v136:Connect(v140, function(arg2)
menuToggle:SetActive(arg2)
end)
end
end

v136:Connect(v140, function(enabled)
obj._cursor:Set(enabled)
obj._overlay.Enabled = enabled
end)

v136:Connect(userInputService.InputBegan, function(arg2, arg3)
if arg3 then
return
end

if obj:ShouldBlockKeybindCapture(arg2) then
return
end
local userInputType = arg2.UserInputType

if arg2.UserInputType == Enum.UserInputType.Keyboard then
userInputType = arg2.KeyCode
end

if userInputType == obj.Keybind then
obj:SetVisible(not obj.Visible)
end
end)

if v123.IsMobile() then
local function fn38()
fn37(obj)
end

v132.connectOnScreenKeyboard(v136, fn38)
v136:Connect(userInputService.TextBoxFocused, fn38)
end

return obj
end

index2.View = function(arg)
return arg
end

index2.AddTab = function(arg, arg2)
return fn36(arg).Window:AddTab(arg2)
end

index2.Dialog = function(arg, arg2, arg3)
local dialog = arg._dialog

if dialog ~= nil then
dialog:Close()
end

if not arg.Visible then
arg:SetVisible(true, true)
end

local v136 = nil
local trove = arg._trove

local v137 = v116.new(arg:View(), fn36(arg).Window.MenuFrame, trove, arg2, function()
if arg._dialog == v136 then
arg._dialog = nil
end
end)

v136 = v137
arg._dialog = v137

if arg3 ~= nil then
local v138, v139 = v107(arg3, v137)

if not v138 then
v137:Destroy()
error(v139, 2)
end
end

v137:_Open()
return v137
end

index2.AddSettingsTab = function(arg)
local v136 = arg:AddTab({
Label = "Settings",
Icon = "rbxassetid://106205298246017",
Description = "Menu preferences, config management, and theme customization.",
})

local trove = arg._trove

return v136, (v135(arg:View(), v136, trove, {
SetAccent = function(arg2)
arg:SetAccent(arg2)
end,
SetWatermarkEnabled = function(arg2)
arg:SetWatermarkEnabled(arg2)
end,
IsWatermarkEnabled = function()
return arg:IsWatermarkEnabled()
end,
SetKeybindListEnabled = function(arg2)
arg:SetKeybindListEnabled(arg2)
end,
IsKeybindListEnabled = function()
return arg:IsKeybindListEnabled()
end,
SetMenuPillHidden = function(arg2)
arg:SetMenuPillHidden(arg2)
end,
EnterMobileButtonDragMode = function()
arg:EnterMobileButtonDragMode(function()
arg:SetVisible(v86[34])
end)
end,
Unload = function()
arg:Unload()
end,
}, arg._themePath, arg._notificationPath, arg._autoExecuteEnabledPath))
end

index2.SetTitle = function(arg, title)
arg.Title = title
local v136 = fn36(arg)
v136.Window:SetTitle(title)
v136.Watermark:SetTitle(title)
return arg
end

index2.SetWatermarkUsername = function(arg, watermarkUsername)
arg._watermarkUsername = watermarkUsername
fn36(arg).Watermark:SetUsername(watermarkUsername)
return arg
end

index2.SetWatermarkEnabled = function(arg, arg2)
fn36(arg).Watermark:SetEnabled(arg2)
end

index2.IsWatermarkEnabled = function(arg)
return fn36(arg).Watermark:IsEnabled()
end

index2.SetKeybindListEnabled = function(arg, arg2)
local keybindList = arg._keybindList

if keybindList ~= nil then
keybindList:SetEnabled(arg2)
end
end

index2.IsKeybindListEnabled = function(arg)
local keybindList = arg._keybindList
return keybindList ~= nil and keybindList:IsEnabled()
end

index2.AddKeybindHudEntry = function(arg)
local keybindList = arg._keybindList
if keybindList == nil then
return nil
end
return keybindList:AddEntry()
end

local function fn38(arg)
local mobileButtons = arg._mobileButtons
if mobileButtons ~= nil then
return mobileButtons
end
local hud = arg._hud
local trove = arg._trove
local v136 = v121.new(arg:View(), hud, trove)
arg._mobileButtons = v136
return v136
end

index2.RegisterMobileButton = function(arg, arg2, arg3, arg4, arg5)
if not v123.WantsMobileButtons() then
return nil
end
return fn38(arg):Register(arg2, arg3, arg4, arg5)
end

index2.RegisterSearchSection = function(arg, arg2, arg3, arg4)
fn36(arg).SearchPalette:Register(arg2, arg3, arg4)
end

index2.InvalidateSearch = function(arg)
fn36(arg).SearchPalette:Invalidate()
end

index2.SearchQuery = function(arg, arg2)
return fn36(arg).SearchPalette:Search(arg2)
end

index2.ShowSearchResults = function(arg, arg2)
fn36(arg).SearchPalette:ShowAt(arg2)
end

index2.HideSearchResults = function(arg)
fn36(arg).SearchPalette:Hide()
end

index2.SetActiveSearchBar = function(arg, arg2)
fn36(arg).SearchPalette:SetActiveBar(arg2)
end

index2.EnterMobileButtonDragMode = function(arg, arg2)
local mobileButtons = arg._mobileButtons
if mobileButtons == nil then
return
end
arg:SetVisible(false)
mobileButtons:EnterDragMode(arg2)
end

index2.SetMenuPillHidden = function(arg, hideMobileMenuButton)
local menuPill = arg._menuPill

if menuPill ~= nil then
menuPill:SetInvisible(hideMobileMenuButton)
end

local stateData = arg._stateData

if stateData ~= nil then
stateData.HideMobileMenuButton = hideMobileMenuButton
arg:SaveState()
end
end

index2.SetVisible = function(arg, visible, arg2)
local v136 = v86[116]
assert(type(visible) == v136, "Menu.SetVisible(state) -> expected boolean")
local window = fn36(arg).Window
local flag19 = arg.Visible ~= visible

if arg2 then
window:SetVisible(visible)
arg._tweener:SetLive(v86[34])
arg.Visible = visible
arg:_SyncConfigActive(visible)

if flag19 then
arg.VisibilityChanged:Fire(visible)
end

return
end

arg._tweener:SetLive(true)
if not window:SetVisible(visible) then
return
end
arg.Visible = visible
arg:_SyncConfigActive(visible)
arg.VisibilityChanged:Fire(visible)
end

index2._SyncConfigActive = function(arg, arg2)
local config = arg._config
if config == nil then
return
end
local setActive = config.SetActive

if setActive ~= nil then
setActive(config, arg2)
end
end

index2.SetAccent = function(arg, arg2)
v128.refresh(v86[139], arg2)
arg.AccentChanged:Fire(arg2)
end

index2.GetConfig = function(arg)
return arg._config
end

index2.GetColorAnimation = function(arg)
return arg._colorAnimation
end

index2.GetPersistence = function(arg)
return arg._persistence
end

index2.GetStateData = function(arg)
return arg._stateData
end

index2.SaveState = function(arg)
local state = arg._state
local stateData = arg._stateData

if state ~= nil and stateData ~= nil then
state:Save(stateData)
end
end

index2.GetOverlayLayer = function(arg)
return arg._overlay
end

local function fn39(arg)
local keybindCapture = arg._keybindCapture
if keybindCapture ~= nil then
return keybindCapture
end
local v136 = v119.new(arg._trove)
arg._keybindCapture = v136
if not (n26 > 4823) then
return v136
end
return nil

-- (anti-tamper freeze trap removed)
end

index2.CaptureKey = function(arg, arg2)
return fn39(arg):Begin(arg2)
end

index2.ShouldBlockKeybindCapture = function(arg, arg2)
local keybindCapture = arg._keybindCapture
return keybindCapture ~= nil and keybindCapture:ShouldBlockMenuToggle(arg2)
end

local function fn40(arg)
local tooltip = arg._tooltip
if tooltip ~= nil then
return tooltip
end
local v136 = v129.new(arg._trove, arg._overlay, arg.VisibilityChanged)
arg._tooltip = v136

arg._overlays:SetBeforeOpen(function()
v136:Hide(nil)
end)

return v136
end

index2.AttachTooltip = function(arg, arg2, arg3, arg4)
local v136 = fn40(arg)

arg2:Connect(arg3.MouseEnter, function()
local v137 = arg4()

if v137 ~= nil and v137 ~= "" then
v136:Show(arg3, v137)
end
end)

arg2:Connect(arg3.MouseLeave, function()
v136:Hide(arg3)
end)

if v123.HasTouch() then
local v137 = arg2:Extend()

arg2:Connect(arg3.InputBegan, function(arg5)
if arg5.UserInputType ~= Enum.UserInputType.Touch then
return
end
local position = arg5.Position
v137:Clean()

v137:Add(task.delay(0.45, function()
if not arg.Visible or arg5.UserInputState == Enum.UserInputState.End or arg5.UserInputState == Enum.UserInputState.Cancel then
return
end
local n = arg5.Position.X - position.X
local n33 = arg5.Position.Y - position.Y
if n * n + n33 * n33 > 100 then
return
end
local v138 = arg4()

if v138 ~= nil and v138 ~= "" then
v136:ShowAt(arg3, v138, Vector2.new(arg5.Position.X, arg5.Position.Y))
v124.suppressActivation(arg5)
end
end))
end)
end
end

index2.OnPreRender = function(arg, arg2)
local nextUpdateId = arg._nextUpdateId
arg._nextUpdateId = arg._nextUpdateId + 1
arg._updateCallbackById[nextUpdateId] = arg2
arg._updateCount = arg._updateCount + 1

if arg._renderConnection == nil then
arg._renderConnection = runService.RenderStepped:Connect(function(deltaTime)
if not arg.Visible then
return
end

for _, v136 in arg._updateCallbackById, nil, nil do
v136(deltaTime)
end
end)
end

return function()
if arg._updateCallbackById[nextUpdateId] == nil then
return
end
arg._updateCallbackById[nextUpdateId] = nil
arg._updateCount = arg._updateCount - 1

if arg._updateCount <= v86[186] and arg._renderConnection ~= nil then
arg._renderConnection:Disconnect()
arg._renderConnection = nil
end
end
end

index2.Tween = function(arg, arg2, arg3, arg4)
return arg._tweener:Play(arg2, arg3, arg4)
end

index2.DragTweenInfo = function(arg)
return arg._tweener:DragInfo()
end

local tbl18 = {}
setmetatable(tbl18, { __mode = "k" })

local function fn41(arg, arg2, arg3)
local transparency = tbl18[arg2]

if transparency == nil then
transparency = arg2.Transparency
tbl18[arg2] = transparency
end

local v136 = arg._tweener:Play(arg2, { Transparency = arg3 and transparency or 1 })
if v136 == nil then
arg2.Transparency = transparency
return nil
end
arg2.Transparency = arg3 and 1 or transparency

v136.Completed:Once(function()
if arg2.Parent == nil then
return
end

if not arg3 then
arg2.Transparency = transparency
end
end)

return v136
end

index2.FadeCanvasGroup = function(arg, arg2, visible, arg3)
local tbl19 = arg3 or { Tweening = false }
tbl19._fadeToken = (tbl19._fadeToken or v86[186]) + 1
local fadeToken = tbl19._fadeToken

for _, v136 in arg2:GetChildren() do
if v136:IsA("UIStroke") then
fn41(arg, v136, visible)
end
end

if visible then
arg2.Visible = v86[34]
end

local groupTransparency = v86[63]

if visible then
groupTransparency = 0
end

local v136 = arg._tweener:Play(arg2, { GroupTransparency = groupTransparency })

if v136 == nil then
arg2.GroupTransparency = groupTransparency
arg2.Visible = visible
tbl19.Tweening = v86[153]
return
end

tbl19.Tweening = true

v136.Completed:Once(function()
if tbl19._fadeToken ~= fadeToken then
return
end
tbl19.Tweening = v86[153]
arg2.Visible = visible
end)
end

index2.RegisterOverlay = function(arg, arg2, arg3)
return arg._overlays:Register(arg2, arg3)
end

index2.UnregisterOverlay = function(arg, arg2)
arg._overlays:Unregister(arg2)
end

index2.ToggleOverlay = function(arg, arg2)
arg._overlays:Toggle(arg2)
end

index2.SetOverlayOpen = function(arg, arg2, arg3)
arg._overlays:SetOpen(arg2, arg3)
end

index2.CloseOverlays = function(arg, arg2, arg3)
arg._overlays:CloseAll(arg2, arg3)
end

index2.CloseOverlayDescendants = function(arg, arg2)
arg._overlays:CloseDescendants(arg2)
end

index2.MakeDraggable = function(arg, parent, arg2, arg3)
local persistKey = arg3 and arg3.PersistKey

local function fn42()
local stateData = arg._stateData
if stateData == nil or persistKey == nil then
return
end
local position = parent.Position
local watermarkPosition = { position.X.Offset, position.Y.Offset }

if persistKey == "WatermarkPosition" then
stateData.WatermarkPosition = watermarkPosition
else
stateData.KeybindsListPosition = watermarkPosition
end

arg:SaveState()
end

if persistKey ~= nil then
local stateData = arg._stateData

if stateData ~= nil then
local keybindsListPosition = stateData.KeybindsListPosition

if persistKey == "WatermarkPosition" then
if true then
keybindsListPosition = stateData.WatermarkPosition
else
-- (anti-tamper freeze trap removed)
end
end

if keybindsListPosition ~= nil and #keybindsListPosition >= 2 then
parent.Position = UDim2.fromOffset(math.round(keybindsListPosition[v86[63]]), math.round(keybindsListPosition[2]))
end
end

local function fn43()
if parent.Parent ~= nil and v132.clampGuiToViewport(parent) then
fn42()
end
end

arg2:Add(task.defer(fn43))
arg2:Add(task.defer(fn43))
end

local uiDragDetector = Instance.new("UIDragDetector")
uiDragDetector.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane
uiDragDetector.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
uiDragDetector.Enabled = arg.Visible
uiDragDetector.Parent = parent

arg2:Connect(arg.VisibilityChanged, function(enabled)
uiDragDetector.Enabled = enabled
end)

local position = nil

arg2:Connect(uiDragDetector.DragStart, function()
position = parent.Position
arg.Dragging = v86[34]
local chrome = arg._chrome

if chrome ~= nil and parent == chrome.Window.MenuFrame then
arg._keyboardBaseY = nil
end

arg._overlays:CloseAll(nil, true)
end)

arg2:Connect(uiDragDetector.DragContinue, function()
local v136 = position
if v136 == nil then
return
end
local dragUDim2 = uiDragDetector.DragUDim2
parent.Position = v132.snapPosition(UDim2.new(v136.X.Scale, v136.X.Offset + dragUDim2.X.Offset, v136.Y.Scale, v136.Y.Offset + dragUDim2.Y.Offset))
v132.clampGuiToViewport(parent)
end)

arg2:Connect(uiDragDetector.DragEnd, function()
position = nil
arg.Dragging = false
v132.clampGuiToViewport(parent)
fn42()
local onDragEnd = arg3 and arg3.OnDragEnd

if onDragEnd ~= nil then
onDragEnd(parent.Position)
end
end)

local v136 = arg2:Extend()

v132.connectCurrentCameraViewport(arg2, function(arg4)
v136:Clean()
if arg4 == nil or parent.Parent == nil then
return
end

v136:Add(task.defer(function()
if parent.Parent ~= nil then
v132.clampGuiToViewport(parent)
end
end))
end)

return uiDragDetector
end

index2.Unload = function(arg)
local onUnload = arg._onUnload

if onUnload ~= nil then
onUnload()
end
end

index2.Destroy = function(arg)
arg:SaveState()
arg._cursor:Set(false)

if arg._renderConnection ~= nil then
arg._renderConnection:Disconnect()
arg._renderConnection = nil
end

arg._trove:Destroy()
end

return index2
end

tbl17.aD = function()
local ad = tbl17.cache.aD

if not ad then
local ad2 = { c = fn35() }
tbl17.cache.aD = ad2
ad = ad2
end

return ad.c
end
end
do -- aE
local function fn35()
tbl17.C()
local v115 = tbl17.N()
tbl17.M()
tbl17.ab()
tbl17.r()
tbl17.ac()
tbl17.Q()
tbl17.H()
local v116 = tbl17.ae()
tbl17.af()
tbl17.R()
tbl17.T()
tbl17.U()
tbl17.V()
local v117 = tbl17.aD()
tbl17.X()
local v118 = tbl17.aB()
tbl17.Y()
tbl17.an()
local v119 = tbl17.u()
tbl17.J()
tbl17.B()
tbl17.Z()
tbl17.K()
tbl17.ar()
tbl17._()
tbl17.S()
tbl17.aa()

return {
Menu = v117,
Notifications = v118,
GeneralState = v116,
ColorBinding = v115,
ForceMobileLayout = v119.ForceMobileLayout,
}
end

tbl17.aE = function()
local ae = tbl17.cache.aE

if not ae then
ae = { c = fn35() }
tbl17.cache.aE = ae
end

return ae.c
end
end

-- expose the module registry to the caller
return tbl17
]=]
-- ============================================================================
--  GUI-Bibliothek + Engine (KiciaLib v1.0)  -  hier nichts aendern
-- ============================================================================
local Library = (function()
--[[
    KiciaLib.lua  -  LinoriaLib-style GUI library on the Kicia menu
    =================================================================
    Version 1.0

    Requires: KiciaUI.lua (the extracted Kicia GUI library) in the same
    executor workspace folder.

    Quick start
    -----------
        local Library = loadstring(readfile('KiciaLib.lua'))()

        local Window = Library:CreateWindow({
            Title = 'My Script',
            Icon  = 'rbxassetid://127234874352422',
        })

        local Main = Window:AddTab('Main')
        local Left = Main:AddLeftGroupbox('Combat')

        Left:AddToggle{
            Text     = 'Enabled',
            Default  = false,
            Callback = function(on) print('toggled', on) end,
        }
        Left:AddSlider{
            Text = 'FOV', Min = 30, Max = 120,
            Rounding = 0, Default = 80,
            Callback = function(v) print('fov', v) end,
        }
        Left:AddButton{
            Text     = 'Do the thing',
            Callback = function() print('clicked') end,
        }

    Full reference: KiciaLib-Doku.txt
]]

-- ── one shared instance per session, like LinoriaLib's getgenv() export ──
local existing = getgenv().KiciaLib
if type(existing) == 'table' and existing.Version and existing.Menu then
    return existing
end

-- ── load the extracted Kicia GUI library ────────────────────────────
local UI
do
    local ok, res = pcall(function()
        return loadstring(__KICIA_UI_SRC, '@KiciaUI.lua')()
    end)

    if not ok or type(res) ~= 'table' then
        error('[KiciaLib] could not load KiciaUI.lua.\n'
            .. 'Put KiciaUI.lua in the same workspace folder as KiciaLib.lua.\n'
            .. 'cause: ' .. tostring(res), 2)
    end

    UI = res
end

-- ── error sink ─────────────────────────────────────────────────────
-- Kicia's error reporter reads a sink that the original bootstrap
-- installs at sigmakicia line 66448 - outside the extraction window.
-- Without it, Menu.new dies on `assert(v115)` at KiciaUI line 845.
do
    local ok = pcall(function()
        UI.b().use({ Report = function(_, e)
            local detail = type(e) == 'table' and (e.Detail or e.Operation) or e
            warn('[KiciaLib] ' .. tostring(detail))
        end })
    end)
    if not ok then
        warn('[KiciaLib] could not install the error sink')
    end
end

-- ── menu entry point ───────────────────────────────────────────────
-- Module aE starts at sigmakicia line 18783. Copies of KiciaUI.lua
-- extracted before that line stop at module aD and don't have it, so
-- rebuild it: same warm-up calls, same result.
local MenuModule
do
    if type(UI.aE) == 'function' then
        local ok, res = pcall(UI.aE)
        if ok and type(res) == 'table' then
            MenuModule = res.Menu
        end
    end

    if not MenuModule then
        local warmup = {
            'C', 'N', 'M', 'ab', 'r', 'ac', 'Q', 'H', 'ae', 'af',
            'R', 'T', 'U', 'V', 'aD', 'X', 'aB', 'Y', 'an', 'u',
            'J', 'B', 'Z', 'K', 'ar', '_', 'S', 'aa',
        }
        local failed = {}
        for _, name in ipairs(warmup) do
            local ok, err = pcall(UI[name])
            if not ok then
                failed[#failed + 1] = name .. ': ' .. tostring(err)
            end
        end
        if #failed > 0 then
            warn('[KiciaLib] warm-up problems - ' .. table.concat(failed, ' | '))
        end

        local ok, res = pcall(UI.aD)
        if ok then
            MenuModule = res
        end
    end

    if type(MenuModule) ~= 'table' or type(MenuModule.new) ~= 'function' then
        error('[KiciaLib] KiciaUI.lua did not provide a menu module', 2)
    end
end

-- ── small helpers ──────────────────────────────────────────────────

-- Linoria "Rounding = n" is decimal places; Kicia "Step" is the
-- increment it snaps to. Rounding 2 -> Step 0.01, Rounding 0 -> Step 1.
local function stepFor(r)
    if r == nil or r == 0 then
        return 1
    end
    return 10 ^ (-r)
end

-- shallow copy so a caller can reuse one options table
local function copy(t)
    local o = {}
    for k, v in pairs(t) do
        o[k] = v
    end
    return o
end

-- Linoria calls it Text / Callback, Kicia calls it Label / OnChanged.
-- Both spellings work; this produces the Kicia shape.
local function toKicia(t)
    local o = copy(t or {})
    if o.Text ~= nil and o.Label == nil then o.Label = o.Text end
    if o.Callback ~= nil and o.OnChanged == nil then o.OnChanged = o.Callback end
    if o.Rounding ~= nil and o.Step == nil then o.Step = stepFor(o.Rounding) end
    return o
end

-- Wrap a raw Kicia control so scripts see Linoria's surface:
--   .State      current value
--   :Get()      current value
--   :Set(v)     write a value
--   :OnChanged(fn)  subscribe (chained, never replaces)
--   .Raw        the underlying Kicia control (needed by AddDependencyBox)
local function wrap(ctrl, kind, opts)
    opts = opts or {}

    local obj = { Type = kind, Raw = ctrl }
    local decode = opts.decode
    local encode = opts.encode

    local function read()
        local v = ctrl.Value
        return decode and decode(v) or v
    end

    obj.State = read()

    function obj:Get()
        obj.State = read()
        return obj.State
    end

    function obj:Set(value, silent)
        if encode then value = encode(value) end
        ctrl:Set(value, silent)
        obj.State = read()
        if not silent and opts.Callback then
            opts.Callback(obj.State)
        end
        return obj
    end

    function obj:OnChanged(fn)
        ctrl:OnChanged(fn)
        return obj
    end

    ctrl:OnChanged(function(raw)
        obj.State = decode and decode(raw) or raw
        if opts.Callback then
            opts.Callback(obj.State)
        end
    end)

    return obj
end

-- ── the library ────────────────────────────────────────────────────
local Library = {}
Library.Version = '1.0'

local activeMenu = nil
local tabGrids = {}

-- exactly one Grid per tab (Kicia asserts on a second one), created the
-- first time a groupbox is asked for
local function gridFor(tab)
    local g = tabGrids[tab]
    if not g then
        g = tab:Grid{ Columns = 2 }
        tabGrids[tab] = g
    end
    return g
end

local function makeGroup(section)
    local Group = {}
    Group._section = section

    -- ── Toggle ─────────────────────────────────────────────────────
    -- Text, Default, Callback, Tooltip
    function Group:AddToggle(props)
        local o = toKicia(props)
        o.Default = o.Default == true
        local ctrl = section:AddToggle(o)
        return wrap(ctrl, 'Toggle', { Callback = o.Callback })
    end

    -- ── Slider ─────────────────────────────────────────────────────
    -- Text, Min, Max, Default, Rounding (decimals), Suffix, Callback
    function Group:AddSlider(props)
        local o = toKicia(props)
        o.Min = o.Min or 0
        o.Max = o.Max or 100
        o.Default = o.Default or o.Min
        local ctrl = section:AddSlider(o)
        return wrap(ctrl, 'Slider', { Callback = o.Callback })
    end

    -- ── Dropdown ───────────────────────────────────────────────────
    -- Text, Options (array of strings), Default (must be in Options),
    -- Tooltip, Callback
    function Group:AddDropdown(props)
        local o = toKicia(props)
        o.Options = o.Options or {}
        if o.Default == nil then
            o.Default = o.Options[1]
        end
        local ctrl = section:AddDropdown(o)
        return wrap(ctrl, 'Dropdown', { Callback = o.Callback })
    end

    -- ── ColorPicker ────────────────────────────────────────────────
    -- Text, Default (Color3), Callback(Color3)
    -- Kicia stores { Rgb = Color3, Alpha = number }; this hands your
    -- callback a plain Color3, the way LinoriaLib does.
    function Group:AddColorPicker(props)
        local o = toKicia(props)
        local default = o.Default
        if type(default) ~= 'table' then
            o.Default = { Rgb = default or Color3.new(1, 1, 1) }
        end
        o.Callback = nil
        local ctrl = section:AddColor(o)

        return wrap(ctrl, 'ColorPicker', {
            Callback = props and props.Callback,
            decode   = function(v) return type(v) == 'table' and v.Rgb or v end,
            encode   = function(v)
                if type(v) == 'table' then return v end
                return { Rgb = v }
            end,
        })
    end

    -- ── Button ─────────────────────────────────────────────────────
    -- Text, Callback, Variant = 'default' | 'primary' | 'ghost'
    function Group:AddButton(props)
        local o = toKicia(props)
        o.OnClick = o.OnClick or o.Callback or function() end
        o.Callback = nil
        o.OnChanged = nil
        return section:AddButton(o)
    end

    -- ── TextBox (Linoria calls it AddInput) ────────────────────────
    -- Text, Placeholder, Default, Callback
    function Group:AddInput(props)
        local o = toKicia(props)
        local ctrl = section:AddTextBox(o)
        return wrap(ctrl, 'TextBox', { Callback = o.Callback })
    end

    -- ── Keybind ────────────────────────────────────────────────────
    -- Text, Default (Enum.KeyCode), Callback
    function Group:AddKeybind(props)
        local o = toKicia(props)
        local ok, ctrl = pcall(section.AddKeybind, section, o)
        if not ok then
            warn('[KiciaLib] AddKeybind failed: ' .. tostring(ctrl))
            return nil
        end
        return wrap(ctrl, 'Keybind', { Callback = o.Callback })
    end

    -- ── Label ──────────────────────────────────────────────────────
    -- Group:AddLabel('some text')  or  { Text = '...' }
    function Group:AddLabel(props)
        local text = props
        if type(props) == 'table' then
            text = props.Text or props.Label or ''
        end
        return section:AddLabel{ Label = tostring(text) }
    end

    -- ── Divider ────────────────────────────────────────────────────
    function Group:AddDivider()
        return section:AddDivider()
    end

    -- ── Dependency box ─────────────────────────────────────────────
    -- Everything inside only shows while the toggle is on.
    --   local box = group:AddDependencyBox(toggleObject)
    --   box:AddSlider{ ... }
    function Group:AddDependencyBox(toggle)
        local source = type(toggle) == 'table' and (toggle.Raw or toggle) or toggle
        local ok, ctrl = pcall(section.AddGroup, section, { Source = source })
        if not ok then
            error('[KiciaLib] AddDependencyBox failed: ' .. tostring(ctrl), 2)
        end
        return makeGroup(ctrl)
    end

    -- ── escape hatch ───────────────────────────────────────────────
    -- Every other widget Kicia ships, unmodified:
    --   group:AddRaw('AddMultiDropdown', { Label = '...', Options = {...} })
    -- Also: AddRangeSlider, AddList, AddMultiList, AddMultiDropdown,
    --       AddIconStrip, AddViewport, AddOrderedList, AddGear,
    --       AddMultiSection, AddSkinChanger
    function Group:AddRaw(name, props)
        local fn = section[name]
        if type(fn) ~= 'function' then
            error('[KiciaLib] section has no method ' .. tostring(name), 2)
        end
        local ok, ctrl = pcall(fn, section, toKicia(props))
        if not ok then
            error('[KiciaLib] ' .. name .. ' failed: ' .. tostring(ctrl), 2)
        end
        return ctrl
    end

    return Group
end

local function makeTab(tab)
    local Tab = {}

    function Tab:AddLeftGroupbox(title)
        return makeGroup(gridFor(tab):AddSection{ Title = title, Side = 'left' })
    end

    function Tab:AddRightGroupbox(title)
        return makeGroup(gridFor(tab):AddSection{ Title = title, Side = 'right' })
    end

    function Tab:AddFullGroupbox(title)
        return makeGroup(gridFor(tab):AddSection{ Title = title, Side = 'full' })
    end

    Tab._raw = tab
    return Tab
end

-- ── CreateWindow ───────────────────────────────────────────────────
-- opts: Title, Icon, Description, Directory, MenuKey (KeyCode),
--       Accent (Color3), OnUnload (function)
function Library:CreateWindow(opts)
    opts = opts or {}

    local menu = MenuModule.new{
        Title     = opts.Title or 'KiciaLib',
        Icon      = opts.Icon,
        Directory = opts.Directory,
        OnUnload  = opts.OnUnload,
    }

    if opts.Accent and menu.SetAccent then
        pcall(function() menu:SetAccent(opts.Accent) end)
    end

    if opts.MenuKey then
        menu.Keybind = opts.MenuKey
    end

    activeMenu = menu
    Library.Menu = menu

    local Window = {}
    Window._raw = menu
    Window.Menu = menu

    function Window:AddTab(name, extra)
        extra = type(extra) == 'table' and extra or {}
        return makeTab(menu:AddTab{
            Label       = extra.Label or name,
            Icon        = extra.Icon,
            Description = extra.Description,
        })
    end

    function Window:SetVisible(state, force)
        menu:SetVisible(state, force)
        return Window
    end

    function Window:SetAccent(color)
        menu:SetAccent(color)
        return Window
    end

    -- Unload fires your OnUnload callback, Destroy then saves state and
    -- tears the trove down. Both are needed for a clean shutdown.
    function Window:Unload()
        pcall(function() menu:Unload() end)
        pcall(function() menu:Destroy() end)
        Library.Menu = nil
        if getgenv().KiciaLib == Library then
            getgenv().KiciaLib = nil
        end
        activeMenu = nil
    end

    Window.Keybind = menu.Keybind

    -- first run: show it, exactly like LinoriaLib does
    pcall(function() menu:SetVisible(true, true) end)

    return Window
end

function Library:Unload()
    if activeMenu then
        pcall(function() activeMenu:Unload() end)
        pcall(function() activeMenu:Destroy() end)
        activeMenu = nil
    end
    Library.Menu = nil
    if getgenv().KiciaLib == Library then
        getgenv().KiciaLib = nil
    end
end

getgenv().KiciaLib = Library
return Library
end)()

-- ============================================================================
--  Ende der Bibliothek. Dieser Chunk gibt Library zurueck.
--  Dein Code gehoert in dein eigenes Skript, direkt unter der loadstring-Zeile.
-- ============================================================================

return Library
