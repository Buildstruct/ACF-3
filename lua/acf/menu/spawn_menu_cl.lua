local hook = hook
local ACF  = ACF

ACF.MenuOptions = ACF.MenuOptions or {}
ACF.MenuLookup  = ACF.MenuLookup or {}
ACF.MenuCount   = ACF.MenuCount or 0

local Options = ACF.MenuOptions
local Lookup  = ACF.MenuLookup

do -- Menu population functions
	local function DefaultAction(Menu)
		Menu:AddTitle("#acf.menu.default_action_title")
		Menu:AddLabel("#acf.menu.default_action_desc")
	end

	function ACF.AddMenuOption(Index, Name, Icon, Enabled)
		if not Index then return end
		if not Name then return end
		if not isfunction(Enabled) then Enabled = nil end

		if not Lookup[Name] then
			local Count = ACF.MenuCount + 1

			Options[Count] = {
				Icon = "icon16/" .. (Icon or "plugin") .. ".png",
				IsEnabled = Enabled,
				Index = Index,
				Name = Name,
				Lookup = {},
				List = {},
				Count = 0,
			}

			Lookup[Name] = Options[Count]

			ACF.MenuCount = Count
		else
			local Option = Lookup[Name]

			Option.Icon = "icon16/" .. (Icon or "plugin") .. ".png"
			Option.IsEnabled = Enabled
			Option.Index = Index
		end
	end

	function ACF.GetMenuItem(Option, Name)
		return Lookup[Option].Lookup[Name]
	end

	function ACF.AddMenuItem(Index, Option, Name, Icon, Action, Enabled)
		if not Index then return end
		if not Option then return end
		if not Name then return end
		if not Lookup[Option] then return end
		if not isfunction(Enabled) then Enabled = nil end

		local Items = Lookup[Option]
		local Item = Items.Lookup[Name]

		if not Item then
			Items.Count = Items.Count + 1

			Items.List[Items.Count] = {
				Icon = "icon16/" .. (Icon or "plugin") .. ".png",
				Action = Action or DefaultAction,
				IsEnabled = Enabled,
				Option = Option,
				Index = Index,
				Name = Name,
			}

			Items.Lookup[Name] = Items.List[Items.Count]
		else
			Item.Icon = "icon16/" .. (Icon or "plugin") .. ".png"
			Item.Action = Action or DefaultAction
			Item.IsEnabled = Enabled
			Item.Option = Option
			Item.Index = Index
			Item.Name = Name
		end
	end

	ACF.AddMenuOption(1, "#acf.menu.about", "information")
	ACF.AddMenuOption(101, "#acf.menu.settings", "wrench")
	ACF.AddMenuOption(102, "#acf.menu.permissions", "gun")
	ACF.AddMenuOption(201, "#acf.menu.entities", "brick")
	ACF.AddMenuOption(9999, "#acf.menu.fun", "bricks")
	ACF.AddMenuOption(100000, "#acf.menu.scanner", "magnifier")
end


do -- ACF Menu context panel
	local function GetSortedList(List)
		local Result = {}

		for K, V in ipairs(List) do
			Result[K] = V
		end

		table.SortByMember(Result, "Index", true)

		return Result
	end

	local function AllowOption(Option)
		if Option.IsEnabled and not Option:IsEnabled() then return false end

		local Allow = hook.Run("ACF_OnEnableMenuOption", Option.Name)

		return Allow
	end

	local function AllowItem(Item)
		if Item.IsEnabled and not Item:IsEnabled() then return false end

		local Allow = hook.Run("ACF_OnEnableMenuItem", Item.Option, Item.Name)

		return Allow
	end

	local function UpdateTree(Tree, Old, New)
		local OldParent = Old and Old.Parent
		local NewParent = New.Parent

		if OldParent == NewParent then return end

		if OldParent then
			OldParent.AllowExpand = true
			OldParent:SetExpanded(false)
		end

		NewParent.AllowExpand = true
		NewParent:SetExpanded(true)

		Tree:SetHeight(Tree:GetLineHeight() * (Tree.BaseHeight + NewParent.Count))
	end

	local function FixStupidNodeCutoffTextIssue(Node)
		function Node:AnimSlide( anim, delta, data )
			if not IsValid(self.ChildNodes) then anim:Stop() return end

			if anim.Started then
				data.To = self:GetTall()
				data.Visible = self.ChildNodes:IsVisible()
			end

			if anim.Finished then
				self:InvalidateLayout()
				self.ChildNodes:SetVisible( data.Visible )
				self:SetTall( data.To )
				self:GetParentNode():ChildExpanded()
				return
			end
			self:SetTall(Lerp(math.ease.InOutSine(delta), data.From, data.To))

			-- These fix the label overflow
			self.ChildNodes:SetVisible(true)
			self.ChildNodes:SetWide(20000)
			self.Label:SetWide(20000)

			self:GetParentNode():ChildExpanded()
		end

		function Node:PerformLayout()
			if self:IsRootNode() then
				return self:PerformRootNodeLayout()
			end

			if self.animSlide:Active() then return end

			local LineHeight = self:GetLineHeight()

			self.Expander:SetPos(-11, 0)
			self.Expander:SetSize(15, 15)
			self.Expander:SetVisible(false)

			self.Label:StretchToParent(0, nil, 0, nil)
			self.Label:SetTall(LineHeight)

			self.Icon:SetVisible(true)
			self.Icon:SetPos(self.Expander.x + self.Expander:GetWide() + 4, (LineHeight - self.Icon:GetTall()) * 0.5)
			self.Label:SetTextInset(self.Icon.x + self.Icon:GetWide() + 4, 0)

			if not IsValid(self.ChildNodes) or not self.ChildNodes:IsVisible() then
				self:SetTall(LineHeight)
				return
			end

			self.ChildNodes:SizeToContents()
			self:SetTall(LineHeight + self.ChildNodes:GetTall())

			self.ChildNodes:StretchToParent(7, LineHeight, 0, 0)

			self:DoChildrenOrder()
		end

		Node:SetHideExpander(true)
		Node.animSlide = Derma_Anim("Anim", Node, Node.AnimSlide)
	end

	local function PopulateTree(Tree)
		local OptionList = GetSortedList(Options)
		local First

		Tree.BaseHeight = 0.5
		Tree.VBar:SetSize(0, 0)
		Tree:SetLineHeight(19)

		for _, Option in ipairs(OptionList) do
			if not AllowOption(Option) then continue end

			local Parent = Tree:AddNode(Option.Name, Option.Icon)
			local SetExpanded = Parent.SetExpanded

			FixStupidNodeCutoffTextIssue(Parent)

			Parent.Action = Option.Action
			Parent.Master = true
			Parent.Count = 0

			function Parent:SetExpanded(Bool)
				if not self.AllowExpand then return end

				SetExpanded(self, Bool)

				self.AllowExpand = nil
			end

			Tree.BaseHeight = Tree.BaseHeight + 1

			local ItemList = GetSortedList(Option.List)
			for _, Item in ipairs(ItemList) do
				if not AllowItem(Item) then continue end

				local Child = Parent:AddNode(Item.Name, Item.Icon)
				Child.Action = Item.Action
				Child.Parent = Parent

				Parent.Count = Parent.Count + 1

				function Child.Label:Paint(w, h)
					local Skin = self:GetSkin()
					surface.SetAlphaMultiplier(math.Remap(math.sin(CurTime() * 7), -1, 1, 0.6, 1))
					Skin:PaintTreeNodeButton(self, w, h)
					surface.SetAlphaMultiplier(1)
				end

				if not Parent.Selected then
					Parent.Selected = Child

					if not First then
						First = Child
					end
				end
			end
		end

		Tree:SetSelectedItem(First)
	end

	local function SetupMenuTree(Menu, Tree)
		function Tree:OnNodeSelected(Node)
			if self.Selected == Node then return end

			if Node.Master then
				self:SetSelectedItem(Node.Selected)
				return
			end

			UpdateTree(self, self.Selected, Node)

			Node.Parent.Selected = Node
			self.Selected = Node

			ACF.SetToolMode("acf_menu", "Main", "Idle")
			ACF.SetClientData("Destiny")

			Menu:ClearTemporal()
			Menu:StartTemporal()

			Node.Action(Menu)

			Menu:EndTemporal()
		end

		PopulateTree(Tree)
	end

	--- Generates the menu used in the main menu tool.
	--- @param Panel panel The base panel to build the menu off of.
	function ACF.CreateSpawnMenu(Panel)
		local Menu = ACF.InitMenuBase(Panel, "SpawnMenu", "acf_reload_spawn_menu")
		local Tree = Menu:AddPanel("DTree")
		SetupMenuTree(Menu, Tree)
	end

	ACF.SetupMenuTree = SetupMenuTree
end

do -- Client and server settings
	ACF.SettingsPanels = ACF.SettingsPanels or {
		Client = {},
		Server = {},
	}

	local Settings = ACF.SettingsPanels

	--- Generates the following functions:
	-- ACF.AddClientSettings(Index, Name, Function)
	-- ACF.RemoveClientSettings(Name)
	-- ACF.GenerateClientSettings(MenuPanel)
	-- ACF.AddServerSettings(Index, Name, Function)
	-- ACF.RemoveServerSettings(Name)
	-- ACF.GenerateServerSettings(MenuPanel)

	--- Uses the following hooks:
	-- ACF_PreLoadServerSettings
	-- ACF_OnLoadServerSettings
	-- ACF_PostLoadServerSettings
	-- ACF_PreLoadClientSettings
	-- ACF_OnLoadClientSettings
	-- ACF_PostLoadClientSettings

	for Realm, Destiny in pairs(Settings) do
		local PreHook  = "ACF_PreLoad" .. Realm .. "Settings"
		local OnHook   = "ACF_OnLoad" .. Realm .. "Settings"
		local PostHook = "ACF_PostLoad" .. Realm .. "Settings"
		local Message  = "No %sside settings have been registered."

		local function CreateSection(Menu, Name, Data)
			local Result = hook.Run(PreHook, Name)

			if not Result then return end

			local Base, Section = Menu:AddCollapsible(Name, false)

			function Section:OnToggle(Bool)
				if not Bool then return end
				if self.Created then return end

				local Result = hook.Run(OnHook, Name, Base)

				if not Result then
					Data.Create(Base)
				end

				hook.Run(PostHook, Name, Base)

				self.Created = true
			end
		end

		ACF["Add" .. Realm .. "Settings"] = function(Index, Name, Function)
			if not isnumber(Index) then return end
			if not isstring(Name) then return end
			if not isfunction(Function) then return end

			Destiny[Name] = {
				Create = Function,
				Index = Index,
			}
		end

		ACF["Remove" .. Realm .. "Settings"] = function(Name)
			if not isstring(Name) then return end

			Destiny[Name] = nil
		end

		ACF["Generate" .. Realm .. "Settings"] = function(Menu)
			if not ispanel(Menu) then return end

			if not next(Destiny) then
				Menu:AddTitle("Nothing to see here.")
				Menu:AddLabel(Message:format(Realm))

				return
			end

			for Name, Data in SortedPairsByMemberValue(Destiny, "Index") do
				CreateSection(Menu, Name, Data)
			end
		end
	end
end