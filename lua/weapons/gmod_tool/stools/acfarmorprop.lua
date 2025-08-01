local ACF = ACF
local Contraption	= ACF.Contraption
local IsValid = IsValid

TOOL.Category	 = (ACF.CustomToolCategory and ACF.CustomToolCategory:GetBool()) and "ACF" or "Construction"
TOOL.Name		 = "#tool.acfarmorprop.name"
TOOL.Command	 = nil
TOOL.ConfigName	 = ""
TOOL.Information = {
	{ name = "left" },
	{ name = "right" },
	{ name = "reload" }
}

TOOL.ClientConVar["thickness"] = 1
TOOL.ClientConVar["ductility"] = 0

local MinimumArmor = ACF.MinimumArmor
local MaximumArmor = ACF.MaxThickness

-- Calculates mass, armor, and health given prop area and desired ductility and thickness.
local function CalcArmor(Area, Ductility, Thickness)
	local mass = Area * (1 + Ductility) ^ 0.5 * Thickness * 0.00078
	local armor = ACF.CalcArmor(Area, Ductility, mass)
	local health = (Area / ACF.Threshold) * (1 + Ductility)

	return mass, armor, health
end

local function UpdateValues(Entity, Data, PhysObj, Area, Ductility)
	local Thickness, Mass

	if Data.Thickness then
		Thickness = math.Clamp(Data.Thickness, MinimumArmor, MaximumArmor)
		Mass      = CalcArmor(Area, Ductility * 0.01, Thickness)

		duplicator.ClearEntityModifier(Entity, "mass")
	else
		local EntMods = Entity.EntityMods
		local MassMod = EntMods and EntMods.mass

		Mass = MassMod and MassMod.Mass or PhysObj:GetMass()
	end

	Entity.ACF.Thickness = Thickness
	Entity.ACF.Ductility = Ductility * 0.01

	if Mass ~= Entity.ACF.Mass then
		Contraption.SetMass(Entity, Mass)
	end
end

local function UpdateArmor(_, Entity, Data, BecauseOfDupe)
	if CLIENT then return end
	if not Data then return end
	if not ACF.Check(Entity, BecauseOfDupe) then return end

	if Entity.ACF_PreventArmoring then return end -- Disable armoring ACF entities (they should handle it themselves)

	local PhysObj   = Entity.ACF.PhysObj
	local Area      = Entity.ACF.Area
	local Ductility = math.Clamp(Data.Ductility or 0, ACF.MinDuctility, ACF.MaxDuctility)

	UpdateValues(Entity, Data, PhysObj, Area, Ductility)

	duplicator.ClearEntityModifier(Entity, "ACF_Armor")
	duplicator.StoreEntityModifier(Entity, "ACF_Armor", { Thickness = Data.Thickness, Ductility = Ductility })
end

hook.Add("ACF_OnUpdateServerData", "ACF_ArmorTool_MaxThickness", function(_, Key, Value)
	if Key ~= "MaxThickness" then return end

	MaximumArmor = math.floor(ACF.CheckNumber(Value, ACF.MaxThickness))
end)

function TOOL:CheckForReload()
	local isFirstTimePredicted = IsFirstTimePredicted()
	if not isFirstTimePredicted then return end

	local Player = self:GetOwner()
	if Player:KeyPressed(IN_RELOAD) then
		local Trace = Player:GetEyeTrace()

		local ran = self:GetContraptionReadout(Trace)
		if ran then
			-- Get tool entity
			local Weapon = self.Weapon
			Weapon:DoShootEffect( Trace.HitPos, Trace.HitNormal, Trace.Entity, Trace.PhysicsBone, isFirstTimePredicted )
		end
	end
end

if CLIENT then
	local ArmorProp_Area = CreateClientConVar("acfarmorprop_area", 0, false, true) -- we don't want this one to save
	local ArmorProp_Ductility = CreateClientConVar("acfarmorprop_ductility", 0, false, true, "", ACF.MinDuctility, ACF.MaxDuctility)
	local ArmorProp_Thickness = CreateClientConVar("acfarmorprop_thickness", 1, false, true, "", MinimumArmor, ACF.MaximumArmor)

	local Sphere = CreateClientConVar("acfarmorprop_sphere_search", 0, false, true, "", 0, 1)
	local Radius = CreateClientConVar("acfarmorprop_sphere_radius", 0, false, true, "", 0, 10000)

	TOOL.BuildCPanel = ACF.CreateArmorPropertiesMenu

	function TOOL:DrawHUD()
		local Trace = self:GetOwner():GetEyeTrace()
		local Ent = Trace.Entity

		if not IsValid(Ent) then return false end
		if Ent:IsPlayer() or Ent:IsNPC() then return false end
		if Ent.GetArmor then return end

		local Weapon = self.Weapon
		local Mass = math.Round(Weapon:GetNWFloat("WeightMass"), 2)
		local Armor = math.Round(Weapon:GetNWFloat("MaxArmour"), 2)
		local Health = math.Round(Weapon:GetNWFloat("MaxHP"), 2)

		local Area = ArmorProp_Area:GetFloat()
		local Ductility = math.Clamp(ArmorProp_Ductility:GetFloat(), ACF.MinDuctility, ACF.MaxDuctility)
		local Thickness = math.Clamp(ArmorProp_Thickness:GetFloat(), MinimumArmor, MaximumArmor)

		local NewMass, NewArmor, NewHealth = CalcArmor(Area, Ductility * 0.01, Thickness)
		local BubbleText = language.GetPhrase("tool.acfarmorprop.bubble_text")
		Mass = math.Clamp(Mass, ACF.MinimumMass, ACF.MaximumMass)
		NewMass = math.Clamp(NewMass, ACF.MinimumMass, ACF.MaximumMass)
		local Text = BubbleText:format(Mass, Armor, Health, math.Round(NewMass, 2), math.Round(NewArmor, 2), math.Round(NewHealth, 2))

		AddWorldTip(nil, Text, nil, Ent:GetPos())
	end

	local TextGray = Color(224, 224, 255)
	local BGGray = Color(200, 200, 200)
	local Blue = Color(50, 200, 200)
	local Red = Color(200, 50, 50)
	local Green = Color(50, 200, 50)
	local Black = Color(0, 0, 0)
	local drawText = draw.SimpleTextOutlined

	surface.CreateFont("ACF_ToolTitle", {
		font = "Arial",
		size = 32
	})

	surface.CreateFont("ACF_ToolSub", {
		font = "Arial",
		size = 25
	})

	surface.CreateFont("ACF_ToolLabel", {
		font = "Arial",
		size = 32,
		weight = 620,
	})

	function TOOL:DrawToolScreen()
		local Trace = self:GetOwner():GetEyeTrace()
		local Ent   = Trace.Entity
		local Weapon = self.Weapon
		local Health = math.Round(Weapon:GetNWFloat("HP", 0))
		local MaxHealth = math.Round(Weapon:GetNWFloat("MaxHP", 0))

		if Ent.GetArmor then -- Is procedural armor
			local Material = Ent.ArmorType
			local Mass     = math.Round(Weapon:GetNWFloat("WeightMass", 0), 1)
			local Angle    = math.Round(ACF.GetHitAngle(Trace, (Trace.HitPos - Trace.StartPos):GetNormalized()), 1)
			local Armor    = math.Round(Ent:GetArmor(Trace))
			local Size     = Ent:GetSize()
			local Nominal  = math.Round(math.min(Size[1], Size[2], Size[3]) * ACF.InchToMm, 1)
			local MaxArmor = Ent:GetSize():Length() * ACF.InchToMm

			cam.Start2D()
				render.Clear(0, 0, 0, 0)
				surface.SetDrawColor(Black)
				surface.DrawRect(0, 0, 256, 256)
				surface.SetDrawColor(BGGray)
				surface.DrawRect(0, 34, 256, 2)

				drawText("#tool.acfarmorprop.procedural.data", "ACF_ToolTitle", 128, 20, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0, BGGray)
				drawText(language.GetPhrase("tool.acfarmorprop.procedural.material"):format(Material), "ACF_ToolSub", 128, 48, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0, BGGray)
				drawText(language.GetPhrase("tool.acfarmorprop.procedural.weight"):format(Mass), "ACF_ToolSub", 128, 70, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0, BGGray)
				drawText(language.GetPhrase("tool.acfarmorprop.procedural.nominal_armor"):format(Nominal), "ACF_ToolSub", 128, 92, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0, BGGray)

				draw.RoundedBox(6, 10, 110, 236, 32, BGGray)
				draw.RoundedBox(6, 10, 110, Angle / 90 * 236, 32, Green)
				drawText(language.GetPhrase("tool.acfarmorprop.procedural.hit_angle"):format(Angle), "ACF_ToolLabel", 15, 110, Black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 0, BGGray)

				draw.RoundedBox(6, 10, 160, 236, 32, BGGray)
				draw.RoundedBox(6, 10, 160, Armor / MaxArmor * 236, 32, Blue)
				drawText(language.GetPhrase("tool.acfarmorprop.procedural.armor"):format(Armor), "ACF_ToolLabel", 15, 160, Black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 0, BGGray)

				draw.RoundedBox(6, 10, 210, 236, 32, BGGray)
				draw.RoundedBox(6, 10, 210, Health / MaxHealth * 236, 32, Red)
				drawText(language.GetPhrase("tool.acfarmorprop.procedural.health"):format(Health), "ACF_ToolLabel", 15, 210, Black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 0, Black)
			cam.End2D()
		else
			local Armour = math.Round(Weapon:GetNWFloat("Armour", 0), 2)
			local MaxArmour = math.Round(Weapon:GetNWFloat("MaxArmour", 0), 2)
			local HealthTxt = Health .. "/" .. MaxHealth
			local ArmourTxt = Armour .. "/" .. MaxArmour

			cam.Start2D()
				render.Clear(0, 0, 0, 0)

				surface.SetDrawColor(Black)
				surface.DrawRect(0, 0, 256, 256)
				surface.SetFont("torchfont")

				-- header
				draw.SimpleTextOutlined("#tool.acfarmorprop.armor_stats", "torchfont", 128, 30, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black)

				-- armor bar
				draw.RoundedBox(6, 10, 83, 236, 64, BGGray)
				if Armour ~= 0 and MaxArmour ~= 0 then
					draw.RoundedBox(6, 15, 88, Armour / MaxArmour * 226, 54, Blue)
				end

				draw.SimpleTextOutlined("#acf.menu.armor", "torchfont", 128, 100, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black)
				draw.SimpleTextOutlined(ArmourTxt, "torchfont", 128, 130, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black)

				-- health bar
				draw.RoundedBox(6, 10, 183, 236, 64, BGGray)
				if Health ~= 0 and MaxHealth ~= 0 then
					draw.RoundedBox(6, 15, 188, Health / MaxHealth * 226, 54, Red)
				end

				draw.SimpleTextOutlined("#acf.menu.health", "torchfont", 128, 200, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black)
				draw.SimpleTextOutlined(HealthTxt, "torchfont", 128, 230, TextGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, color_black)
			cam.End2D()
		end
	end

	-- Clamp thickness if the change in ductility puts mass out of range
	cvars.AddChangeCallback("acfarmorprop_ductility", function(_, _, value)
		local area = ArmorProp_Area:GetFloat()

		-- don't bother recalculating if we don't have a valid ent
		if area == 0 then return end

		local ductility = math.Clamp((tonumber(value) or 0) / 100, ACF.MinDuctility / 100, ACF.MaxDuctility / 100)
		local thickness = math.Clamp(ArmorProp_Thickness:GetFloat(), MinimumArmor, MaximumArmor)
		local mass = CalcArmor(area, ductility, thickness)

		if mass > ACF.MaximumMass or mass < ACF.MinimumMass then
			mass = math.Clamp(mass, ACF.MinimumMass, ACF.MaximumMass)

			thickness = ACF.CalcArmor(area, ductility, mass)
			ArmorProp_Thickness:SetFloat(math.Clamp(thickness, MinimumArmor, MaximumArmor))
		end
	end)

	-- Clamp ductility and thickness if the change in thickness puts mass out of range
	cvars.AddChangeCallback("acfarmorprop_thickness", function(_, _, value)
		local area = ArmorProp_Area:GetFloat()

		-- don't bother recalculating if we don't have a valid ent
		if area == 0 then return end

		local thickness = math.Clamp(tonumber(value) or MinimumArmor, MinimumArmor, MaximumArmor)
		local ductility = math.Clamp(ArmorProp_Ductility:GetFloat() * 0.01, ACF.MinDuctility / 100, ACF.MaxDuctility / 100)
		local mass = CalcArmor(area, ductility, thickness)

		if mass > ACF.MaximumMass or mass < ACF.MinimumMass then
			mass = math.Clamp(mass, ACF.MinimumMass, ACF.MaximumMass)

			ductility = -(39 * area * thickness - mass * 50000) / (39 * area * thickness)
			ArmorProp_Ductility:SetFloat(math.Clamp(ductility * 100, ACF.MinDuctility, ACF.MaxDuctility))

			thickness = ACF.CalcArmor(area, ductility, mass)
			ArmorProp_Thickness:SetFloat(math.Clamp(thickness, MinimumArmor, MaximumArmor))
		end
	end)

	local GreenSphere = Color(0, 200, 0, 50)
	local GreenFrame = Color(0, 200, 0, 100)

	hook.Add("PostDrawOpaqueRenderables", "Armor Tool Search Sphere", function(bDrawingDepth, _, isDraw3DSkybox)
		if bDrawingDepth or isDraw3DSkybox then return end
		local Player = LocalPlayer()
		local Weapon = Player:GetActiveWeapon()
		if not IsValid( Weapon ) then return end
		if Weapon:GetClass() ~= "gmod_tool" then return end

		local Tool = Player:GetTool()
		if not Tool then return end -- Player has no toolgun
		if Tool ~= Player:GetTool("acfarmorprop") then return end -- Current tool is not the armor tool
		if not Sphere:GetBool() then return end

		local Value = Radius:GetFloat()

		if Value <= 0 then return end

		local Pos = Player:GetEyeTrace().HitPos

		render.SetColorMaterial()
		render.DrawSphere(Pos, Value, 20, 20, GreenSphere)
		render.DrawWireframeSphere(Pos, Value, 20, 20, GreenFrame, true)
	end)

	function TOOL:Think()
		self:CheckForReload()
	end
else -- Serverside-only stuff
	function TOOL:Think()
		local Player = self:GetOwner()
		local Ent = Player:GetEyeTrace().Entity

		self:CheckForReload()

		if Ent == self.AimEntity then return end

		local Weapon = self.Weapon

		if ACF.Check(Ent) then
			Player:ConCommand("acfarmorprop_area " .. Ent.ACF.Area)
			Player:ConCommand("acfarmorprop_thickness " .. self:GetClientNumber("thickness")) -- Force sliders to update themselves

			Weapon:SetNWFloat("WeightMass", Ent.ACF.Mass)
			Weapon:SetNWFloat("HP", Ent.ACF.Health)
			Weapon:SetNWFloat("Armour", Ent.ACF.Armour)
			Weapon:SetNWFloat("MaxHP", Ent.ACF.MaxHealth)
			Weapon:SetNWFloat("MaxArmour", Ent.ACF.MaxArmour)
		else
			Player:ConCommand("acfarmorprop_area 0")

			Weapon:SetNWFloat("WeightMass", 0)
			Weapon:SetNWFloat("HP", 0)
			Weapon:SetNWFloat("Armour", 0)
			Weapon:SetNWFloat("MaxHP", 0)
			Weapon:SetNWFloat("MaxArmour", 0)
		end

		self.AimEntity = Ent
	end

	duplicator.RegisterEntityModifier("ACF_Armor", function(_, Entity, Data)
		if Entity.IsPrimitive then return end
		UpdateArmor(_, Entity, Data, true)
	end)

	-- Specifically handling Primitives separately so that we can ensure that their stats are not impacted by a race condition
	hook.Add("Primitive_PostRebuildPhysics", "ACF", function(Entity, Properties)
		local EntMods   = Entity.EntityMods
		local ArmorMod  = EntMods and EntMods.ACF_Armor

		UpdateArmor(_, Entity, ArmorMod)

		local EntACF    = Entity.ACF
		if EntACF then
			Properties.mass = EntACF.Mass -- Don't let the primitive reset its own mass, use ACF mass instead
		end
	end)

	duplicator.RegisterEntityModifier("acfsettings", function(_, Entity, Data)
		if CLIENT then return end
		if not ACF.Check(Entity, true) then return end

		local EntMods   = Entity.EntityMods
		local MassMod   = EntMods and EntMods.mass
		local PhysObj   = Entity.ACF.PhysObj
		local Area      = Entity.ACF.Area
		local Mass      = MassMod and MassMod.Mass or PhysObj:GetMass()
		local Ductility = math.Clamp(Data.Ductility or 0, ACF.MinDuctility, ACF.MaxDuctility) * 0.01
		local Thickness = ACF.CalcArmor(Area, Ductility, Mass)

		duplicator.ClearEntityModifier(Entity, "mass")
		duplicator.ClearEntityModifier(Entity, "acfsettings")

		UpdateArmor(_, Entity, { Thickness = Thickness, Ductility = Ductility * 100 })
	end)
end

-- Apply settings to prop
function TOOL:LeftClick(Trace)
	local Ent = Trace.Entity

	if not IsValid(Ent) then return false end
	if Ent:IsPlayer() or Ent:IsNPC() then return false end
	if CLIENT then return true end
	if not ACF.Check(Ent) then return false end

	local Ductility = math.Clamp(self:GetClientNumber("ductility"), ACF.MinDuctility, ACF.MaxDuctility)
	local Thickness = math.Clamp(self:GetClientNumber("thickness"), MinimumArmor, MaximumArmor)

	duplicator.ClearEntityModifier(Ent, "mass")

	UpdateArmor(_, Ent, { Thickness = Thickness, Ductility = Ductility })

	-- this invalidates the entity and forces a refresh of networked armor values
	self.AimEntity = nil

	return true
end

-- Suck settings from prop
function TOOL:RightClick(Trace)
	local Ent = Trace.Entity

	if not IsValid(Ent) then return false end
	if Ent:IsPlayer() or Ent:IsNPC() then return false end
	if CLIENT then return true end
	if not ACF.Check(Ent) then return false end

	local Player = self:GetOwner()

	Player:ConCommand("acfarmorprop_thickness " .. Ent.ACF.MaxArmour)
	Player:ConCommand("acfarmorprop_ductility " .. Ent.ACF.Ductility * 100)

	return true
end

do -- Armor readout
	local Contraption = ACF.Contraption
	local Messages    = ACF.Utilities.Messages

	local Text1 = "--- Contraption Readout (Owner: %s) ---"
	local Text2 = "Mass: %s kg total | %s kg physical (%s%%) | %s kg parented"
	local Text3 = "Mobility: %s hp/ton @ %s hp | %s liters of fuel"
	local Text4 = "Entities: %s (%s physical, %s parented, %s other entities) | %s constraints"

	-- Emulates the stuff done by ACF.CalcMassRatio except with a given set of entities
	local function ProcessList(Entities)
		local Constraints = {}

		local Owners = {}
		local Lookup = {}
		local Count  = 0

		local Power     = 0
		local Fuel      = 0
		local PhysNum   = 0
		local ParNum    = 0
		local ConNum    = 0
		local OtherNum  = 0
		local Total     = 0
		local PhysTotal = 0

		for _, Ent in ipairs(Entities) do
			if not ACF.Check(Ent) then
				if not Ent:IsWeapon() then -- We don't want to count weapon entities
					OtherNum = OtherNum + 1
				end
			elseif not (Ent:IsPlayer() or Ent:IsNPC()) then -- These will pass the ACF check, but we don't want them either
				local Owner   = Ent:CPPIGetOwner() or game.GetWorld()
				local PhysObj = Ent.ACF.PhysObj
				local Class   = Ent:GetClass()
				local Mass    = PhysObj:GetMass()
				local IsPhys  = false

				if (IsValid(Owner) or Owner:IsWorld()) and not Lookup[Owner] then
					local Name = Owner:GetName()

					Count = Count + 1

					Owners[Count] = Name ~= "" and Name or "World"
					Lookup[Owner] = true
				end

				if Class == "acf_engine" then
					Power = Power + Ent.PeakPower * ACF.KwToHp
				elseif Class == "acf_fueltank" then
					Fuel = Fuel + Ent.Capacity
				end

				-- If it has any valid constraint then it's a physical entity
				if Ent.Constraints and next(Ent.Constraints) then
					for _, Con in pairs(Ent.Constraints) do
						if IsValid(Con) and Con.Type ~= "NoCollide" then -- Nocollides don't count
							IsPhys = true

							if not Constraints[Con] then
								Constraints[Con] = true
								ConNum = ConNum + 1
							end
						end
					end
				end

				-- If it has no valid constraints but also no valid parent, then it's a physical entity
				if not (IsPhys or IsValid(Ent:GetParent())) then
					IsPhys = true
				end

				if IsPhys then
					PhysTotal = PhysTotal + Mass
					PhysNum = PhysNum + 1
				else
					ParNum = ParNum + 1
				end

				Total = Total + Mass
			end
		end

		local Name = next(Owners) and table.concat(Owners, ", ") or "None"

		return Power, Fuel, PhysNum, ParNum, ConNum, Name, OtherNum, Total, PhysTotal
	end

	local Modes = {
		Default = {
			CanCheck = function(_, Trace)
				local Ent = Trace.Entity

				if not IsValid(Ent) then return false end
				if Ent:IsPlayer() or Ent:IsNPC() then return false end

				return true
			end,
			GetResult = function(_, Trace)
				local Ent = Trace.Entity
				local Power, Fuel, PhysNum, ParNum, ConNum, Name, OtherNum = Contraption.CalcMassRatio(Ent, true)

				return Power, Fuel, PhysNum, ParNum, ConNum, Name, OtherNum, Ent.acftotal, Ent.acfphystotal
			end
		},
		Sphere = {
			CanCheck = function(Tool)
				return Tool:GetClientNumber("sphere_radius") > 0
			end,
			GetResult = function(Tool, Trace)
				local Ents = ents.FindInSphere(Trace.HitPos, Tool:GetClientNumber("sphere_radius"))

				return ProcessList(Ents)
			end
		}
	}

	local function GetReadoutMode(Tool)
		if tobool(Tool:GetClientInfo("sphere_search")) then return Modes.Sphere end

		return Modes.Default
	end

	-- Total up mass of constrained ents
	function TOOL:GetContraptionReadout(Trace)
		local Mode = GetReadoutMode(self)

		if not Mode.CanCheck(self, Trace) then return false end
		if CLIENT then return true end

		local Power, Fuel, PhysNum, ParNum, ConNum, Name, OtherNum, Total, PhysTotal = Mode.GetResult(self, Trace)
		local HorsePower = math.Round(Power / math.max(Total * 0.001, 0.001), 1)
		local PhysRatio = math.Round(100 * PhysTotal / math.max(Total, 0.001))
		local ParentTotal = Total - PhysTotal
		local Player = self:GetOwner()

		Messages.SendChat(Player, nil, Text1:format(Name))
		Messages.SendChat(Player, nil, Text2:format(math.Round(Total, 2), math.Round(PhysTotal, 2), PhysRatio, math.Round(ParentTotal, 2)))
		Messages.SendChat(Player, nil, Text3:format(HorsePower, math.Round(Power), math.Round(Fuel)))
		Messages.SendChat(Player, nil, Text4:format(PhysNum + ParNum + OtherNum, PhysNum, ParNum, OtherNum, ConNum))

		return true
	end
end