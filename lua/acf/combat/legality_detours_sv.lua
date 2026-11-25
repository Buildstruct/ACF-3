-- Purpose: Registers a bunch of legality detours for chip interactions with
-- ACF entities and contraptions. Still a lot of work to do here...

local ACF = ACF
local Notify  = ACF.Utilities.Notify

-- The chip, gate or entity running the current detour, so a blocked call can point the owner at it
-- Chip is "E2" or "SF" for chips, since both report the same call names
local Source, Chip

local function WithSource(GetSource, Hook, Kind)
    local function Finish(PreviousSource, PreviousChip, Ok, ...)
        Source, Chip = PreviousSource, PreviousChip

        if not Ok then error(..., 0) end -- Rethrown unchanged, chips throw their runtime errors as tables

        return ...
    end

    return function(First, ...)
        local PreviousSource, PreviousChip = Source, Chip

        Source, Chip = GetSource(First), Kind

        return Finish(PreviousSource, PreviousChip, pcall(Hook, First, ...))
    end
end

-- Used like ACF.Detours, but records the caller around each chip, gate and entity detour
local Detours = setmetatable({
    Expression2 = function(Sig, Hook) return ACF.Detours.Expression2(Sig, WithSource(function(Scope) return Scope.entity end, Hook, "E2")) end,
    Starfall    = function(Expr, Hook) return ACF.Detours.Starfall(Expr, WithSource(function(Instance) return Instance.entity end, Hook, "SF")) end,
    WireGate    = function(Name, Hook) return ACF.Detours.WireGate(Name, WithSource(function(Gate) return Gate end, Hook)) end,
    SENT        = function(Class, Method, Hook) return ACF.Detours.SENT(Class, Method, WithSource(function(Ent) return Ent end, Hook)) end,
}, { __index = ACF.Detours, __newindex = ACF.Detours })

local function PreCheck()
    if not ACF.LegalityDetours then return true end
end

-- TARGET  : Entering seats on ACF contraptions remotely
-- METHODS : Expression 2, Starfall (Entity & Physobj bindings), Wiremod
-- ON CALL : If target's contraption is an ACF contraption, evaluate the distance between the player, and the to-be-used entity.
-- We will allow the call if the distance is within ~120 Source units. Which is actually quite generous, the limit
-- defined in baseplayer_shared.h (PLAYER_USE_RADIUS) is 80 units.

local PLAYER_USE_RADIUS = 120
local function ApproveUseEntity(PlayerInvoker, ToBeUsedEntity, DoNotify)
    if PreCheck() then return true end
    if not IsValid(PlayerInvoker) then return end
    if not IsValid(ToBeUsedEntity) then return end

    -- We don't care about non-vehicles in this case.
    -- TODO: Should we...?
    if not ToBeUsedEntity:IsVehicle() and ToBeUsedEntity:GetClass() ~= "acf_baseplate" then return true end

    local PlayerPos, ToBeUsedPos = PlayerInvoker:GetPos(), ToBeUsedEntity:GetPos()

    local DistanceFromPlayerToUsed  = PlayerPos:Distance(ToBeUsedPos)
    if DistanceFromPlayerToUsed > PLAYER_USE_RADIUS then
        local Contraption = ToBeUsedEntity:CFW_GetContraption()
        if not Contraption then return true end -- We don't care about non-contraptions, that's none of our business.

        -- Otherwise, if not an ACF contraption, approve it, otherwise deny it.
        if Contraption:ACF_IsACFContraption() then
            if DoNotify then
                Notify.EntityWarningToPlayer(ToBeUsedEntity, PlayerInvoker, "Cannot remote-use an ACF contraption from this distance.", string.format("The distance from your player to the target entity was %d, which exceeds the distance limit of %d", DistanceFromPlayerToUsed, PLAYER_USE_RADIUS))
            end
            return false
        end
    end

    return true
end

local function UseDetours()
    -- Propcore - Entity
    do
        local Func Func = Detours.Expression2("e:canUse(e)", function(Scope, Args, ...)
            if not IsValid(Args[1]) then return end
            if not Args[1]:IsPlayer() then return end

            if not ApproveUseEntity(Args[1], Args[2], false) then return end
            return Func(Scope, Args, ...)
        end)
    end
    do
        local Func Func = Detours.Expression2("e:use()", function(Scope, Args, ...)
            if not ApproveUseEntity(Scope.player, Args[1], true) then return end
            return Func(Scope, Args, ...)
        end)
    end
    -- Starfall
    do
        local Func Func = Detours.Starfall("instance.Types.Entity.Methods.use", function(Instance, Ent, ...)
            if not ApproveUseEntity(Instance.player, Instance.Types.Entity.Unwrap(Ent), true) then return end
            return Func(Instance, Ent, ...)
        end)
    end
    -- Wiremod users. 
    -- Wiremod users and E2 use a "WireUse" hook. Which would be great, if the E2 change wasn't 7 months ago and the user change 3 years ago...
    -- (i don't trust most servers to keep their addons up to date)
    -- Arguably would be fine for users (3+ years ago is a while now...), and I may re-evaluate later. For now, its just easier to do this. 
    do
        Detours.SENT("gmod_wire_user", "TriggerInput", function(self, iname, value)
            if iname == "Fire" and value ~= 0 then
                local start = self:GetPos()

                local ent = util.TraceLine({
                    start = start,
                    endpos = start + self:GetUp() * self:GetBeamLength(),
                    filter = self
                }).Entity

                if not ent:IsValid() then return end

                local ply = self:GetPlayer()
                if not ply:IsValid() then return end

                if not ApproveUseEntity(ply, ent, true) then return false end

                if hook.Run("PlayerUse", ply, ent) == false then return end
                if hook.Run("WireUse", ply, ent, self) == false then return end

                ent:Use(ply, self)
            end
        end)
    end
end

local function TriggerDetourRebuild()
    Detours.Loaded = true

    UseDetours()
end

ACF.TriggerDetourRebuild = TriggerDetourRebuild
timer.Simple(Detours.Loaded and 0 or 5, TriggerDetourRebuild)