#include "WindowLayoutEngine.Generators.iss"

objectdef windowLayoutEngine
{
    variable windowLayoutGenerators Generators
    variable jsonvalue Layouts="[]"

    method Initialize()
    {
        LGUI2:LoadPackageFile[WindowLayoutEngine.Uplink.lgui2Package.json]

        This:LoadTests
    }

    method Shutdown()
    {
        LGUI2:UnloadPackageFile[WindowLayoutEngine.Uplink.lgui2Package.json]
    }

    method AddLayout(string name, string generator, jsonvalueref inputData, jsonvalue regions)
    {
        variable jsonvalue jo="{}"

        jo:SetString["name","${name~}"]
        jo:SetString["generator","${generator~}"]
        jo:Set["inputData","${inputData.AsJSON~}"]
        jo:SetByRef["regions","regions"]    

        Layouts:AddByRef[jo]
    }

    method AddScreen(jsonvalueref ja, jsonvalueref joMonitor)
    {
        variable jsonvalue jo="{}"
        
        jo:SetString["itemType","screen"]
        jo:SetString["name","${joMonitor.Get[name]~}"]
        jo:SetInteger["left",${joMonitor.GetInteger[left]}]
        jo:SetInteger["top",${joMonitor.GetInteger[top]}]
        jo:SetInteger["width",${joMonitor.GetInteger[width]}]
        jo:SetInteger["height",${joMonitor.GetInteger[height]}]

        ja:AddByRef[jo]
    }

    method AddRegion(jsonvalueref ja, jsonvalueref joRegion)
    {
        variable jsonvalue jo="${joRegion.AsJSON~}"

        if ${joRegion.Has[numLayout]}
        {
            jo:SetString["itemType","region${joRegion.GetInteger[numLayout]}"]
        }
        else
        {
            jo:SetString["itemType","region"]
        }
        ja:AddByRef[jo]
    }

    member:jsonvalue GetPreviewExtents(jsonvalueref joLayout)
    {
        variable int left
        variable int right
        variable int top
        variable int bottom

        variable uint numMonitor

        variable uint numMonitors

        numMonitors:Set[${joLayout.Get[inputData,monitors].Used}]

        variable jsonvalueref joMonitor

        for (numMonitor:Set[1] ; ${numMonitor}<=${numMonitors} ; numMonitor:Inc)
        {
            joMonitor:SetReference["joLayout.Get[inputData,monitors,${numMonitor}]"]
            if !${joMonitor.Reference(exists)}
                break

            if ${joMonitor.GetInteger[left]}<${left}
                left:Set["${joMonitor.GetInteger[left]}"]
            if ${joMonitor.GetInteger[top]}<${top}
                top:Set["${joMonitor.GetInteger[top]}"]

            if ${joMonitor.GetInteger[right]}>${right}
                right:Set["${joMonitor.GetInteger[right]}"]
            if ${joMonitor.GetInteger[bottom]}>${bottom}
                bottom:Set["${joMonitor.GetInteger[bottom]}"]
        }

;        echo GetPreviewExtents "[${left},${top},${right.Dec[${left}]},${bottom.Dec[${top}]}]"
        return "[${left},${top},${right.Dec[${left}]},${bottom.Dec[${top}]}]"
    }

    member:jsonvalueref GetPreviewItems(uint numLayout,lgui2elementref element)
    {
        variable jsonvalue ja="[]"

        variable jsonvalueref joLayout
        joLayout:SetReference["Layouts.Get[${numLayout}]"]
        if !${joLayout.Reference(exists)}
            return NULL

;        echo GetPreviewItems element=${element}
        if ${element.Element(exists)}
        {
            variable jsonvalue jaExtents
            jaExtents:SetValue["${This.GetPreviewExtents[joLayout]}"]

            element:SetVirtualOrigin[${jaExtents.GetInteger[1]},${jaExtents.GetInteger[2]}]
            element:SetVirtualSize[${jaExtents.GetInteger[3]},${jaExtents.GetInteger[4]}]
        }

        ; screens
        joLayout.Get[inputData,monitors]:ForEach["This:AddScreen[ja,ForEach.Value]"]
        ; regions
        joLayout.Get[regions]:ForEach["This:AddRegion[ja,ForEach.Value]"]

        return ja
    }

    method LoadTests()
    {
        variable jsonvalue testData
        testData:SetValue["$$>
        {
            "numSlots":5,
            "useMonitor":1,
            "monitors":[
                ${Display.Monitor.AsJSON~}
            ],
            "avoidTaskbar":false,
            "leaveHole":true,
            "edge":"bottom",
            "rows":4,
            "columns":2
        }
        <$$"]

        This:AddLayout["Bottom","Edge",testData,"${Generators.Edge.GenerateRegions["testData"]~}"]
        testData:SetString[edge,"right"]
        This:AddLayout["Right","Edge",testData,"${Generators.Edge.GenerateRegions["testData"]~}"]
        testData:SetString[edge,"top"]
        This:AddLayout["Top","Edge",testData,"${Generators.Edge.GenerateRegions["testData"]~}"]
        testData:SetString[edge,"left"]
        This:AddLayout["Left","Edge",testData,"${Generators.Edge.GenerateRegions["testData"]~}"]

        This:AddLayout["Stacked","Stacked",testData,"${Generators.Stacked.GenerateRegions["testData"]~}"]


        This:AddLayout["Tile","Tile",testData,"${Generators.Tile.GenerateRegions["testData"]~}"]

        This:AddLayout["Grid","Grid",testData,"${Generators.Grid.GenerateRegions["testData"]~}"]

        variable jsonvalue joNextMonitor
        joNextMonitor:SetValue["$$>
        {
            "id":1,
            "primary":false,
            "left":1920,"right":3840,"top":0,"bottom":1080,"width":1920,"height":1080,
            "maximizeLeft":1920,"maximizeRight":3840,"maximizeTop":0,"maximizeBottom":1040,"maximizeWidth":1920,"maximizeHeight":1040
        }
        <$$"]
        joNextMonitor:SetString[name,"\\\\.\\DISPLAY2"]
        
        testData.Get[monitors]:Add["${joNextMonitor~}"]

        This:AddLayout["ScreenPer","ScreenPer",testData,"${Generators.ScreenPer.GenerateRegions["testData"]~}"]

        This:LoadComboTests
    }

    method LoadComboTests()
    {
        variable jsonvalue monitor2

        monitor2:SetValue["$$>
        {
            "id":1,
            "primary":false,
            "left":1920,"right":3840,"top":0,"bottom":1080,"width":1920,"height":1080,
            "maximizeLeft":1920,"maximizeRight":3840,"maximizeTop":0,"maximizeBottom":1040,"maximizeWidth":1920,"maximizeHeight":1040
        }
        <$$"]
        monitor2:SetString[name,"\\\\.\\DISPLAY2"]

        variable jsonvalue testData
        testData:SetValue["$$>
        {
            "layouts":[
                {
                    "useMonitor":1,
                    "generator":"Edge"
                },
                {
                    "useMonitor":2,
                    "generator":"Edge"
                }
            ],
            "numSlots":5,
            "avoidTaskbar":false,
            "leaveHole":true,
            "edge":"bottom",
            "rows":4,
            "columns":2,
            "monitors":[
                ${Display.Monitor.AsJSON~},
                ${monitor2.AsJSON~}                
            ]
        }
        <$$"]

        This:AddLayout["Combo","Combo",testData,"${Generators.Combo.GenerateRegions["testData"]~}"]

    }
}

variable(global) windowLayoutEngine WLEngine

function main()
{
    while 1
        waitframe
}