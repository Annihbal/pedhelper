local VORPcore = exports.vorp_core:GetCore()

RegisterServerEvent("pedhelper:checkJob")
AddEventHandler("pedhelper:checkJob", function(requiredJob, npcName)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    
    if Character.job == requiredJob then
        TriggerClientEvent("pedhelper:activatePed", source, npcName)
    else
        TriggerClientEvent("vorp:TipRight", source, Config.Messages.noJob, 4000)
    end
end)

RegisterServerEvent("pedhelper:pedDied")
AddEventHandler("pedhelper:pedDied", function(npcName)
    TriggerClientEvent("pedhelper:respawnPed", -1, npcName)
end)