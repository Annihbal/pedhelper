
local VORPcore = exports.vorp_core:GetCore()
local activePrompts = {}
local activePeds = {}
local currentGroupPed = nil
local promptGroup = GetRandomIntInRange(0, 0xffffff)


local function CreatePrompt(text)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.PromptKey)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, true)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
    return prompt
end

local function CreateBlipForPed(ped)
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 280)  
    SetBlipScale(blip, 0.75) 
    SetBlipColour(blip, 1)  
    SetBlipAsShortRange(blip, true) 
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Assistant")
    EndTextCommandSetBlipName(blip)
    return blip
end

local function CreateStaticPed(npcData)
    local pedModel = GetHashKey(npcData.pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(100)
    end
    
    local ped = CreatePed(pedModel, npcData.position.x, npcData.position.y, npcData.position.z, npcData.position.w, true, true, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    
    local pedId = NetworkGetNetworkIdFromEntity(ped)
    AddEventHandler('entityDeath', function(data)
        if DoesEntityExist(ped) and data.victim == ped then
            TriggerServerEvent("pedhelper:pedDied", npcData.name)
            RemoveEventHandler('entityDeath')
        end
    end)
    
    return ped
end

local function SetupGroupPed(ped, npcData)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    

    SetPedRelationshipGroupHash(ped, GetHashKey("SECURITY_GUARD"))
    SetPedAccuracy(ped, 80)
    SetPedCombatAttributes(ped, 46, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatMovement(ped, 2)
    
 
    if npcData.weapon then
        GiveWeaponToPed_2(ped, GetHashKey(npcData.weapon), 50, true, true, 1, false, 0.5, 1.0, 0, false, 0, false)
    end
    

    local group = GetPlayerGroup(PlayerId())
    SetPedAsGroupMember(ped, group)
    SetGroupSeparationRange(group, 999999.0)
    SetPedAsGroupLeader(PlayerId(), group)
    

    local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, npcData.blipSprite, ped)
    SetBlipScale(blip, 0.8)
    

    npcData.blip = blip

    VORPcore.NotifyRightTip(Config.Messages.pedJoined, 4000)
end

Citizen.CreateThread(function()
    for _, npcData in ipairs(Config.Npc) do
        local ped = CreateStaticPed(npcData)
        local prompt = CreatePrompt(npcData.textPrompt)

        table.insert(activePeds, {
            ped = ped,
            prompt = prompt,
            npcData = npcData
        })
    end
end)


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        for _, data in ipairs(activePeds) do
            local distance = #(coords - vector3(data.npcData.promptPosition.x, data.npcData.promptPosition.y, data.npcData.promptPosition.z))
            
            if distance <= Config.PromptDistance then
                local group = PromptGetGroupIdForTargetEntity(data.ped)
                PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', data.npcData.textPrompt))
                
                if PromptHasHoldModeCompleted(data.prompt) then
                    Citizen.Wait(500)  
                    if data.npcData.jobLock then
                        TriggerServerEvent("pedhelper:checkJob", data.npcData.jobLock, data.npcData.name)
                    else
                        SetupGroupPed(data.ped, data.npcData)
                        currentGroupPed = data.ped
                        
                        data.blip = CreateBlipForPed(data.ped)
                    end
                end
            end
        end
    end
end)

local isReturning = false  

local function ReturnPedToOrigin()
    if currentGroupPed and DoesEntityExist(currentGroupPed) and not isReturning then
        isReturning = true  
        for _, data in ipairs(activePeds) do
            if data.ped == currentGroupPed then
                if data.npcData.blip then
                    RemoveBlip(data.npcData.blip)
                    data.npcData.blip = nil
                end

                ClearPedTasks(currentGroupPed)
                TaskGoToCoordAnyMeans(currentGroupPed, data.npcData.position.x, data.npcData.position.y, data.npcData.position.z, 1.0, 0, 0, 786603, 0)
                
                Citizen.CreateThread(function()
                    while true do
                        Citizen.Wait(500)
                        local pedCoords = GetEntityCoords(currentGroupPed)
                        local dist = #(pedCoords - vector3(data.npcData.position.x, data.npcData.position.y, data.npcData.position.z))

                        if dist < 1.0 then
                            RemovePedFromGroup(currentGroupPed)

                            Citizen.Wait(100)
                            SetEntityHeading(currentGroupPed, data.npcData.position.w)  
                            SetEntityInvincible(currentGroupPed, true)
                            FreezeEntityPosition(currentGroupPed, true)
                            SetBlockingOfNonTemporaryEvents(currentGroupPed, true)

                            currentGroupPed = nil
                            isReturning = false 

                            VORPcore.NotifyRightTip(Config.Messages.pedReturned, 4000)
                            break
                        end
                    end
                end)
                break
            end
        end
    end
end


RegisterCommand('goback', ReturnPedToOrigin)


RegisterNetEvent("pedhelper:activatePed")
AddEventHandler("pedhelper:activatePed", function(npcName)
    for _, data in ipairs(activePeds) do
        if data.npcData.name == npcName then
            SetupGroupPed(data.ped, data.npcData)
            currentGroupPed = data.ped
            isReturning = false  
            break
        end
    end
end)


RegisterNetEvent("pedhelper:respawnPed")
AddEventHandler("pedhelper:respawnPed", function(npcName)
    for i, data in ipairs(activePeds) do
        if data.npcData.name == npcName then
            if DoesEntityExist(data.ped) then
                DeleteEntity(data.ped)
            end
            
            Citizen.Wait(Config.RespawnTime * 1000)
            
            local newPed = CreateStaticPed(data.npcData)
            activePeds[i].ped = newPed
            break
        end
    end
end)

