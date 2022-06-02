;#include "WindowLayoutEngine.Generators.iss"

objectdef windowLayoutEngine
{
    variable jsonvalue Settings="{}"
    variable jsonvalue Regions="[]"

    variable jsonvalueref CurrentRegion


    variable jsonvalueref ResetRegion
    variable uint NumResetRegion

    variable jsonvalueref ActiveRegion
    variable uint NumActiveRegion
    variable jsonvalueref InactiveRegion
    variable uint NumInactiveRegion

    variable bool Active=FALSE

    method Initialize()
    {
        LGUI2:LoadPackageFile[WindowLayoutEngine.Session.lgui2Package.json]
        This:LoadTests
        This:RefreshActiveStatus

        uplink "WLEngine:Event_OnSessionStartup[\"${Session~}\"]"
    }

    method Shutdown()
    {
        uplink "WLEngine:Event_OnSessionShutdown[\"${Session~}\"]"
        LGUI2:UnloadPackageFile[WindowLayoutEngine.Session.lgui2Package.json]
    }

    method LoadTests()
    {
        Settings:SetValue["$$>
        {
            "resetRegion":1,
            "frame":"none"
        }
        <$$"]
        Regions:SetValue["$$>
        [
            {"x":0,"y":0,"width":640,"height":360,"numRegion":1},
            {"x":640,"y":0,"width":640,"height":360,"numRegion":2},
            {"x":1280,"y":0,"width":640,"height":360,"numRegion":3},
            {"x":0,"y":360,"width":640,"height":360,"numRegion":4},
            {"x":640,"y":360,"width":640,"height":360,"numRegion":5}
        ]
        <$$"]
        /*
        Regions:SetValue["$$>
        [
            {"mainRegion":true,"x":0,"y":0,"width":1920,"height":900,"numRegion":1},
            {"x":0,"y":900,"width":384,"height":180,"numRegion":2},
            {"x":384,"y":900,"width":384,"height":180,"numRegion":3},
            {"x":768,"y":900,"width":384,"height":180,"numRegion":4},
            {"x":1152,"y":900,"width":384,"height":180,"numRegion":5},
            {"x":1536,"y":900,"width":384,"height":180,"numRegion":6}
            ]
        <$$"]
        /**/
        This:SelectRegions[1,2]
        This:SelectResetRegion[1]
    }    

    member:bool RenderSizeMatchesClient()
    {
        ; check desired rendering size
        if ${ResetRegion.Reference(exists)}
        {
            if ${Display.Width}!=${Display.ViewableWidth} || ${Display.Height}!=${Display.ViewableHeight}
                return FALSE
        }
        return TRUE
    }

    member:bool RenderSizeMatchesReset()
    {
        ; check desired rendering size
        if ${ResetRegion.Reference(exists)}
        {
            if ${Display.Width}!=${ResetRegion.GetInteger[width]} || ${Display.Height}!=${ResetRegion.GetInteger[height]}
                return FALSE
        }
        return TRUE
    }

    method ApplyRegion(jsonvalueref useRegion)
    {
        if !${useRegion.Reference(exists)} || !${useRegion.Type.Equal[object]}
            return
        
        echo "windowLayoutEngine:ApplyRegion: ${useRegion~}"

        variable bool rescale

        ; check desired rendering size
        if ${ResetRegion.Reference(exists)}
        {
            rescale:Set[1]
            if ${Display.Width}!=${ResetRegion.GetInteger[width]} || ${Display.Height}!=${ResetRegion.GetInteger[height]}
                rescale:Set[0]
        }

        variable string wlParams="-pos -viewable ${useRegion.Get[x]},${useRegion.Get[y]} -size -viewable ${useRegion.Get[width]}x${useRegion.Get[height]}"

        if !${forceReset} && ${rescale}
            wlParams:Set["-stealth ${wlParams~}"]

        if ${Settings.Has[frame]}
            wlParams:Concat[" -frame ${Settings.Get[frame]~}"]

        echo "WindowCharacteristics ${wlParams~}"
        WindowCharacteristics ${wlParams~}
    }

    method Apply(bool forceReset=FALSE)
    {
        This:ApplyRegion[CurrentRegion]

        ; WindowCharacteristics ${stealthFlag}-pos -viewable ${useX},${mainHeight} -size -viewable ${smallWidth}x${smallHeight} -frame none
    }

    method SetCurrentRegion(jsonvalueref useRegion)
    {
        CurrentRegion:SetReference[useRegion]
        LGUI2.Element["windowLayoutEngine.events"]:FireEventHandler[currentRegionChanged]
    }

    method SelectResetRegion(uint numRegion)
    {
        if ${numRegion}>0 && ${numRegion}<${Regions.Size}
        {
            NumResetRegion:Set[${numRegion}]
            ResetRegion:SetReference["Regions.Get[${numRegion}]"]
        }
        else
        {
            NumResetRegion:Set[0]
            ResetRegion:SetReference[NULL]
        }
        LGUI2.Element["windowLayoutEngine.events"]:FireEventHandler[resetRegionChanged]
    }


    method SelectActiveRegion(uint numRegion)
    {
        if ${numRegion}>0 && ${numRegion}<${Regions.Size}
        {
            NumActiveRegion:Set[${numRegion}]
            ActiveRegion:SetReference["Regions.Get[${numRegion}]"]

        }
        else
        {
            NumActiveRegion:Set[0]
            ActiveRegion:SetReference[NULL]
        }
        LGUI2.Element["windowLayoutEngine.events"]:FireEventHandler[activeRegionChanged]

        if ${Active}
            This:SetCurrentRegion[ActiveRegion]

    }

    method SelectInactiveRegion(uint numRegion)
    {
        if ${numRegion}>0 && ${numRegion}<${Regions.Size}
        {
            NumInactiveRegion:Set[${numRegion}]
            InactiveRegion:SetReference["Regions.Get[${numRegion}]"]
        }
        else
        {
            NumInactiveRegion:Set[0]
            InactiveRegion:SetReference[NULL]
        }

        LGUI2.Element["windowLayoutEngine.events"]:FireEventHandler[inactiveRegionChanged]

        if !${Active}
            This:SetCurrentRegion[InactiveRegion]

    }

    method SelectRegions(uint numActiveRegion, uint numInactiveRegion)
    {
        This:SelectActiveRegion[${numActiveRegion}]
        This:SelectInactiveRegion[${numInactiveRegion}]
    }

    method SetActiveStatus(bool newValue)
    {
        variable bool oldValue=${Active}
        variable bool fireEvent
        Active:Set[${newValue}]

        if !${CurrentRegion.Reference(exists)}
            fireEvent:Set[1]

        if ${Active}
            CurrentRegion:SetReference[ActiveRegion]
        else
            CurrentRegion:SetReference[InactiveRegion]

        if ${fireEvent} || ${oldValue} != ${Active}
        {
            LGUI2.Element["windowLayoutEngine.events"]:FireEventHandler[activeStatusChanged]
        }
    }

    method RefreshActiveStatus(bool forceUpdate=FALSE)
    {
        variable bool newValue=${Display.Window.IsForeground}
        if ${forceUpdate} || ${newValue}!=${Active}       
            This:SetActiveStatus[${newValue}]
    }

    method SetLayout(jsonvalue jo)
    {
        if !${jo.Type.Equal[object]}
        {
            echo expected object, got ${jo~}
            return
        }

        echo "SetLayout ${jo~}"

        Regions:SetValue["${jo.Get[regions]}"]
        LGUI2.Element["windowLayoutEngine.events"]:FireEventHandler[regionsChanged]

        This:SelectRegions[${NumActiveRegion},${NumInactiveRegion}]
        This:SelectResetRegion[${NumResetRegion}]
    }
}

variable(global) windowLayoutEngine WLEngine

function main()
{
    while 1
        waitframe
}