local CopiedData = {}
local Disabled = {}
local Selected

net.Receive("ACF_SendCopyData", function(_, Player)
	local Class = net.ReadString()
	local List = util.JSONToTable(net.ReadString())

	if IsValid(Player) then return end -- Trust nobody, not even net messages

	table.SortByMember(List, "Key", true)

	CopiedData[Class] = List
	Selected = Class

	if not Disabled[Class] then
		Disabled[Class] = {}
	end

	RunConsoleCommand("acf_reload_copy_menu") -- Yeah.
end)

local function GetIcon(Class, Key)
	local Data = Disabled[Class]

	return Data[Key] and "icon16/delete.png" or "icon16/accept.png"
end

local function PopulateTree(Tree, Data)
	local Height = 0.5

	Tree:Clear()

	for _, Info in ipairs(Data) do
		local Icon  = GetIcon(Selected, Info.Key)
		local Node  = Tree:AddNode(Info.Key, Icon)
		local Value = Info.Value
		local Type  = type(Value)
		local Size  = 3

		local TypeNode = Node:AddNode(language.GetPhrase("tool.acfcopy.type") .. " " .. Type, "icon16/cog.png")
		TypeNode.RootNode = Node

		if Type ~= "table" then
			local Base = Node:AddNode(language.GetPhrase("tool.acfcopy.value") .. " " .. tostring(Value), "icon16/information.png")
			Base.RootNode = Node
		else
			local Base = Node:AddNode("#tool.acfcopy.value", "icon16/information.png")
			Base.RootNode = Node

			for K, V in pairs(Value) do
				local Extra = Base:AddNode(tostring(K) .. " = " .. tostring(V), "icon16/bullet_black.png")
				Extra.RootNode = Node

				Size = Size + 1
			end

			Base:ExpandTo(true)

			-- We don't want this node to be collapsible
			function Base:SetExpanded()
			end
		end

		Node:ExpandTo(true)

		-- We don't want this node to be collapsible
		function Node:SetExpanded()
		end

		Height = Height + Size
	end

	Tree:SetHeight(Tree:GetLineHeight() * Height)
end

local function UpdateComboBox(ComboBox)
	ComboBox:Clear()

	for Class, Data in pairs(CopiedData) do
		ComboBox:AddChoice(Class, Data, Class == Selected)
	end
end

--- Generates the menu used in the Copy tool.
--- @param Panel panel The base panel to build the menu off of.
function ACF.CreateCopyMenu(Panel)
	local Menu = ACF.InitMenuBase(Panel, "CopyMenu", "acf_reload_copy_menu")
	ACF.SetToolMode("acfcopy", "Main", "CopyPaste")

	if not Selected then
		return Menu:AddLabel("#tool.acfcopy.unselected")
	end

	local ClassList = Menu:AddComboBox()
	local TreeList = Menu:AddPanel("DTree")

	function ClassList:OnSelect(_, Class, Data)
		Selected = Class

		ACF.SetClientData("CopyClass", Class)

		PopulateTree(TreeList, Data)
	end

	function TreeList:OnNodeSelected(Node)
		if Node.RootNode then
			return self:SetSelectedItem(Node.RootNode)
		end

		local Key = Node:GetText()
		local Data = Disabled[Selected]

		-- A ternary won't work here
		if Data[Key] then
			Data[Key] = nil
		else
			Data[Key] = true
		end

		net.Start("ACF_SendDisabledData")
			net.WriteString(Selected)
			net.WriteString(Key)
			net.WriteBool(Data[Key] or false)
		net.SendToServer()

		Node:SetIcon(GetIcon(Selected, Key))
	end

	UpdateComboBox(ClassList)
end