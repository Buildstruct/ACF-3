local ACF        = ACF
local Components = ACF.Classes.Components

Components.Register("AL", {
	Name   = "Autoloader",
	Entity = "acf_autoloader"
})

Components.RegisterItem("AL-IMP", "AL", {
	Name        = "Autoloader",
	Description = "An automatic ammunition loading system.",
	Model       = "models/acf/autoloader_tractorbeam.mdl",
	CreateMenu = function(_, Menu)
		local MassLabel = Menu:AddLabel("")
		local AutoloaderSize = Vector(0, 0, 0)

		local function UpdateAutoloaderStats()
			-- Mass is proportional to volume of the shell
			local R, H = AutoloaderSize.y, AutoloaderSize.x
			local Volume = math.pi * R * R * H

			MassLabel:SetText(string.format("Mass : %s", ACF.GetProperMass(Volume * 250)))
		end

		local CaliberSlider = Menu:AddSlider("Size", ACF.MinAutoloaderCaliber, ACF.MaxAutoloaderCaliber, 2)
		CaliberSlider:SetClientData("AutoloaderCaliber", "OnValueChanged")
		CaliberSlider:DefineSetter(function(Panel, _, _, Value)
			local Size = math.Round(Value)

			Panel:SetValue(Size)

			AutoloaderSize.y = Size / 7.2349619865417 / ACF.InchToMm
			AutoloaderSize.z = Size / 7.2349619865417 / ACF.InchToMm

			UpdateAutoloaderStats()

			return Size
		end)

		local LengthSlider = Menu:AddSlider("Length", ACF.MinAutoloaderLength, ACF.MaxAutoloaderLength, 2)
		LengthSlider:SetClientData("AutoloaderLength", "OnValueChanged")
		LengthSlider:DefineSetter(function(Panel, _, _, Value)
			local Length = math.Round(Value)

			Panel:SetValue(Length)

			AutoloaderSize.x = (Length / 43.233333587646 * 10) / ACF.InchToMm

			UpdateAutoloaderStats()

			return Length
		end)
	end
})