AddCSLuaFile()

local STATE_NONE = 0
local STATE_FIRSTPOINT = 1

TOOL.Category = "Construction"
TOOL.Name = "Base Controller"
TOOL.Command = nil
TOOL.ConfigName = "" --Setting this means that you do not have to create external configuration files to define the layout of the tool config-hud 

TOOL.ClientConVar[ "allow_noclip" ] = "1"
TOOL.ClientConVar[ "keep_noclip_velocity" ] = "1"
TOOL.ClientConVar[ "allow_acf" ] = "1"
TOOL.ClientConVar[ "color_r" ] = "0"
TOOL.ClientConVar[ "color_g" ] = "0"
TOOL.ClientConVar[ "color_b" ] = "0"
TOOL.ClientConVar[ "color_a" ] = "0"


TOOL.canShoot = true
TOOL.State = STATE_NONE
TOOL.FirstPoint = nil
TOOL.SecondPoint = nil

if CLIENT then
	language.Add("Tool.base_controller.name", "Base Controller")
	language.Add("Tool.base_controller.desc", "Base Controller Tool yippie")
	language.Add("Tool.base_controller.0", "Place zone starting point")
	language.Add("Tool.base_controller.1", "Place zone end point")
	language.Add("Tool.base_controller.right", "Update settings of zone")
	language.Add("Tool.base_controller.reload", "Delete zone")
end

if SERVER then
	BaseControllerPlayerSettings = {}

	util.AddNetworkString("BaseControllerSendSettings")
	net.Receive("BaseControllerSendSettings", function()
		local plyId = net.ReadEntity():EntIndex()

		if not BaseControllerPlayerSettings[plyId] then
			BaseControllerPlayerSettings[plyId] = {}
		end

		local settings = BaseControllerPlayerSettings[plyId]

		settings.color 			   = net.ReadColor()
		settings.DisableNoclip     = net.ReadBool()
		settings.RemoveNoclipSpeed = net.ReadBool()
		settings.DisableACF        = net.ReadBool()
	end)
end

function TOOL:Think()
	if CLIENT then
		net.Start("BaseControllerSendSettings")
		net.WriteEntity(LocalPlayer())
		net.WriteColor( Color(GetConVar( "base_controller_color_r" ):GetInt(), GetConVar( "base_controller_color_g" ):GetInt(), GetConVar( "base_controller_color_b" ):GetInt()) )
		net.WriteBool( not GetConVar( "base_controller_allow_noclip" ):GetBool() )
		net.WriteBool( not GetConVar( "base_controller_keep_noclip_velocity" ):GetBool() )
		net.WriteBool( not GetConVar( "base_controller_allow_acf" ):GetBool() )
		net.SendToServer()
	end
end


function TOOL:LeftClick( trace )
	if not self.canShoot then
		return false
	end

	self.canShoot = false
	timer.Simple(0.01, function()
		self.canShoot = true
	end)


	if self.State == STATE_NONE then
		self.FirstPoint = trace.HitPos + trace.HitNormal * 5
		self.State = STATE_FIRSTPOINT
	elseif self.State == STATE_FIRSTPOINT then
		self.SecondPoint = trace.HitPos + trace.HitNormal * 5

		local size = self.SecondPoint - self.FirstPoint
		local canPlace = true

		if math.abs(size.x) > 2000 or math.abs(size.y) > 2000 or math.abs(size.z) > 2000 then
			if CLIENT then
				notification.AddLegacy( "Too large", NOTIFY_ERROR, 2 )
			end
			canPlace = false
		end

		if math.abs(size.x) < 10 or math.abs(size.y) < 10 or math.abs(size.z) < 10 then
			if CLIENT then
				notification.AddLegacy( "Too small", NOTIFY_ERROR, 2 )
			end
			canPlace = false
		end

		for _, entity in ipairs(ents.FindInBox( self.FirstPoint, self.SecondPoint )) do
			if not IsValid(entity) then continue end

			if entity:IsPlayer() and entity != self:GetOwner() then
				notification.AddLegacy( "Player in area", NOTIFY_ERROR, 2 )
				canPlace = false
				break
			end
			if entity:GetClass() == "base_controller_trigger" and entity:GetOwner() != self:GetOwner() then
				notification.AddLegacy( "Other controller in area", NOTIFY_ERROR, 2 )
				canPlace = false
				break
			end
		end

		if SERVER and canPlace then
			local newController = ents.Create( "base_controller_trigger" )

			undo.Create("Base Controller")
			undo.AddEntity(newController)
			undo.SetPlayer(self:GetOwner())
			undo.Finish()

			local settings = BaseControllerPlayerSettings[self:GetOwner():EntIndex()]

			newController:SetPos( (self.FirstPoint + self.SecondPoint) / 2 )
			newController:SetOwner( self:GetOwner() )
			newController.FirstPoint 		= self.FirstPoint
			newController.SecondPoint 		= self.SecondPoint
			newController.color 			= settings.color
			newController.DisableNoclip     = settings.DisableNoclip
			newController.RemoveNoclipSpeed = settings.RemoveNoclipSpeed
			newController.DisableACF        = settings.DisableACF
			newController:Spawn()
		end

		if CLIENT and not canPlace then
			surface.PlaySound( "Buttons.snd10" )
		end

		self.State = STATE_NONE
	end

	return true
end

function TOOL:RightClick( trace )

end

function TOOL:Holster()
	self.State = STATE_NONE
	self.FirstPoint = nil
	self.SecondPoint = nil
end

function TOOL.BuildCPanel( panel )
	panel:AddControl("Header", { Text = "Base Controller", Description = "Lets you control what can happen at your base." })

	panel:AddControl("CheckBox", {
	    Label = "Allow ACF Damage",
	    Command = "base_controller_allow_acf"
	})
	panel:AddControl("CheckBox", {
	    Label = "Allow Noclipping",
	    Command = "base_controller_allow_noclip"
	})
	panel:AddControl("CheckBox", {
	    Label = "Keep velocity when disabling noclip",
	    Command = "base_controller_keep_noclip_velocity"
	})
	panel:AddControl("Color", {
	    Label = "Base Controller Color",
	    Red = "base_controller_color_r",
	    Blue = "base_controller_color_b",
	    Green = "base_controller_color_g",
	    Alpha = "base_controller_color_a",
	    ShowHSV = 1,
	    ShowRGB = 1,
	    Multiplier = 255 --You can change this to make the rgba values go up to any value
	})
end

function TOOL:DrawHUD()
	for _, controller in ipairs(ents.FindByClass("base_controller_trigger")) do
		local drawColor = Color(255, 0, 0)
		if controller:GetOwner() == LocalPlayer() then drawColor = Color(0,255,0) end
		local screenPos = controller:GetPos():ToScreen()

		draw.DrawText( controller:GetOwner():GetName(), "DermaDefault", screenPos.x, screenPos.y, drawColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	if self.State == STATE_FIRSTPOINT then
		local first = self.FirstPoint
		local second = self:GetOwner():GetEyeTrace().HitPos + self:GetOwner():GetEyeTrace().HitNormal * 5
		local center = (first + second) / 2
		local mins = first - center
		local maxs = second - center
		local color = Color(GetConVar( "base_controller_color_r" ):GetInt(), GetConVar( "base_controller_color_g" ):GetInt(), GetConVar( "base_controller_color_b" ):GetInt())

		cam.Start3D()
		render.DrawWireframeBox( center, Angle(), mins, maxs, color, true )
		cam.End3D()
	end
end
