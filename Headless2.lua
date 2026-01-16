local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Headless2Module = {}
Headless2Module.Enabled = false

local vu6 = "134082579"
local vu7 = "134082627"

local function ApplyHeadless2()
    local v16 = LocalPlayer.Character
    if v16 then
        local v17 = v16:FindFirstChild("Head")
        if v17 then
            -- Eliminar Decals y SpecialMesh existentes
            local v18, v19, v20 = pairs(v17:GetChildren())
            while true do
                local v21
                v20, v21 = v18(v19, v20)
                if v20 == nil then
                    break
                end
                if v21:IsA("Decal") or v21:IsA("SpecialMesh") then
                    v21:Destroy()
                end
            end
            
            -- Hacer la cabeza completamente transparente (sin mesh)
            v17.Transparency = 1
            
            -- Eliminar accesorios de la cabeza (hair, hat, face)
            local v23, v24, v25 = pairs(v16:GetChildren())
            while true do
                local v26
                v25, v26 = v23(v24, v25)
                if v25 == nil then
                    break
                end
                if v26:IsA("Accessory") then
                    local v27 = v26:FindFirstChild("Handle")
                    if v27 then
                        local v28 = v27:FindFirstChildOfClass("Attachment")
                        if v28 and (v28.Name:lower():find("hair") or (v28.Name:lower():find("hat") or v28.Name:lower():find("face"))) then
                            v26:Destroy()
                        end
                    end
                end
            end
        end
    end
end

function Headless2Module:Start()
    self.Enabled = true
    
    if LocalPlayer.Character then
        ApplyHeadless2()
    else
        LocalPlayer.CharacterAdded:Wait()
        ApplyHeadless2()
    end
end

function Headless2Module:Stop()
    self.Enabled = false
    
    -- Restaurar la cabeza a visible
    if LocalPlayer.Character then
        local head = LocalPlayer.Character:FindFirstChild("Head")
        if head then
            head.Transparency = 0
        end
    end
end

function Headless2Module:IsEnabled()
    return self.Enabled
end

return Headless2Module
