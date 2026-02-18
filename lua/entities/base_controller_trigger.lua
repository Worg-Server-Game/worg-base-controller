AddCSLuaFile()

ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName		= "base controller trigger"
ENT.RenderGroup     = RENDERGROUP_TRANSLUCENT

ENT.Spawnable 		= false

ENT.Mins            = -Vector(5, 5, 5)
ENT.Maxs            = Vector(5, 5, 5)
ENT.color           = Color(0,0,0,0)

ENT.EntitiesTouching = {}

if SERVER then
    util.AddNetworkString("UpdatePlayerData")
    util.AddNetworkString("SendControllerData")
    util.AddNetworkString("IGotIntialized")

    net.Receive( "IGotIntialized", function(_, ply)
        local entity = net.ReadEntity()

        net.Start("SendControllerData")
        net.WriteEntity(entity)
        net.WriteVector(entity.Mins)
        net.WriteVector(entity.Maxs)
        net.WriteColor(entity.color)
        net.WriteBool(entity.DisableACF)
        net.Send(ply)
    end)
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

if CLIENT then
    net.Receive( "UpdatePlayerData", function()
        local entity = net.ReadEntity()
        local data = net.ReadTable()

        entity.worgBaseController = data
    end)

    net.Receive( "SendControllerData", function()
        local entity = net.ReadEntity()

        entity.Mins = net.ReadVector()
        entity.Maxs = net.ReadVector()
        entity.color = net.ReadColor()

        entity.DisableACF = net.ReadBool()
    end)
end

function ENT:Initialize()
    self:DrawShadow(false)

    if CLIENT then
        net.Start("IGotIntialized")
        net.WriteEntity(self)
        net.SendToServer()
    end

    if SERVER then
        self:SetModel( "models/props_junk/TrashBin01a.mdl" )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_NONE )
        self:SetSolid( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
        self:SetTrigger( true )

        self:SetPos( (self.FirstPoint + self.SecondPoint) / 2 )

        self.Mins = self.FirstPoint - self:GetPos()
        self.Maxs = self.SecondPoint - self:GetPos()
        self:SetCollisionBounds( self.Mins, self.Maxs )
        self:UseTriggerBounds( true, 0 )
    end
end

function ENT:EnableLimits(entity)
    local data

    if entity.worgBaseController then
        data = entity.worgBaseController
    else
        entity.worgBaseController = {}

        data = entity.worgBaseController
    end

    data.DisableNoclip = self.DisableNoclip
    data.DisableACF    = self.DisableACF

    if entity:IsPlayer() then
        net.Start("UpdatePlayerData")
        net.WriteEntity(entity)
        net.WriteTable(data)
        net.Send(entity)
        if data.DisableNoclip and entity:GetNWBool("kylenocliped") then
            entity:ConCommand( "noclip" )
            if self.RemoveNoclipSpeed then
                entity:SetVelocity(-entity:GetVelocity()) -- this shit adds velocity if ran on player entities :skull:
            end
        end
    end

    entity.worgBaseController = data
end

function ENT:DisableLimits(entity)
    local data

    if entity.worgBaseController then
        data = entity.worgBaseController
    else
        entity.worgBaseController = {}

        data = entity.worgBaseController
    end

    data.DisableNoclip = false
    data.DisableACF    = false
end


function ENT:StartTouch(entity)
    if not IsValid(entity) then return end

    self:EnableLimits(entity)

    table.insert(self.EntitiesTouching, entity)
end

function ENT:Touch(entity)
    if not IsValid(entity) then return end

    if not table.HasValue(self.EntitiesTouching, entity) then
        self:EnableLimits(entity)
        table.insert(self.EntitiesTouching, entity)
    end
end

function ENT:EndTouch(entity)
    if not IsValid(entity) then return end

    self:DisableLimits(entity)

    table.RemoveByValue(self.EntitiesTouching, entity)
end

function ENT:OnRemove()
    for _, entity in pairs(self.EntitiesTouching) do
        self:DisableLimits(entity)
    end
end

if not CLIENT then return end

function ENT:DrawTranslucent()
    --self:DrawModel()
    self:SetRenderBounds( self.Mins, self.Maxs )
    render.DrawWireframeBox( self:GetPos(), self:GetAngles(), self.Mins, self.Maxs, self.color, true )

    local ply = LocalPlayer()
    local weaponName = ply:GetActiveWeapon():GetClass()
    local isHoldingACF = string.StartWith(weaponName, "weapon_acf") or string.StartWith(weaponName, "acf")

    if ply:GetNWBool("_Kyle_Buildmode") then return end
    if (isHoldingACF or ply:InVehicle()) and self.DisableACF then
        render.SetColorMaterial()
        render.DrawBox( self:GetPos(), self:GetAngles(), self.Mins, self.Maxs, ColorAlpha( self.color, 50 ) )
    end
end