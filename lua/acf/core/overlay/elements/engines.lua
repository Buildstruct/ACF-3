local Overlay = ACF.Overlay

local acf_overlay_torquemult = CreateClientConVar("acf_overlay_torquemult", "0", true, false, "ACF Overlay; If true, engine power/torque elements in the overlay will be multiplied by the internal torque multiplier.\nIt should be noted that the torque multiplier is a temporary stopgap for internal code issues, and will be removed in a future mobility update.")
local function GetNum(Slot) return math.Round(Slot.Data[2] * (acf_overlay_torquemult:GetBool() and (ACF.GetServerData("TorqueMult") or ACF.TorqueMult or 1) or 1)) end

do
    local ELEMENT = {}
    local function GetText(Num) return ("%s Nm / %s ft-lb"):format(Num, math.Round(Num * ACF.KwToHp)) end
    function ELEMENT.Render(_, Slot)
        Overlay.KeyValueRenderMode = 1
        Overlay.BasicKeyValueRender(_, Slot.Data[1], GetText(GetNum(Slot)))
    end

    function ELEMENT.PostRender(_, Slot)
        Overlay.KeyValueRenderMode = 1
        Overlay.BasicKeyValuePostRender(Slot, Slot.Data[1], GetText(GetNum(Slot)))
    end

    Overlay.DefineElementType("EnginePower", ELEMENT)
end
local Overlay = ACF.Overlay
do
    local ELEMENT = {}
    local function GetText(Num) return ("%s - %s RPM"):format(Num, math.Round(Num * ACF.NmToFtLb)) end
    function ELEMENT.Render(_, Slot)
        Overlay.KeyValueRenderMode = 1
        Overlay.BasicKeyValueRender(_, Slot.Data[1], GetText(GetNum(Slot)))
    end

    function ELEMENT.PostRender(_, Slot)
        Overlay.KeyValueRenderMode = 1
        Overlay.BasicKeyValuePostRender(Slot, Slot.Data[1], GetText(GetNum(Slot)))
    end

    Overlay.DefineElementType("EngineTorque", ELEMENT)
end