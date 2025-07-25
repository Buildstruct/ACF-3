local Classes        = ACF.Classes
local BaseplateTypes = Classes.BaseplateTypes
local Entries        = Classes.GetOrCreateEntries(BaseplateTypes)

function BaseplateTypes.Register(ID, Base)
	return Classes.AddObject(ID, Base, Entries)
end

Classes.AddSimpleFunctions(BaseplateTypes, Entries)