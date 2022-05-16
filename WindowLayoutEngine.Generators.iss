objectdef windowLayoutGenerator
{
    variable string Name="Unnamed Window Layout"
    variable string Description="Fails to generate a Window Layout"

    member:jsonvalueref GenerateRegions(jsonvalueref joInput)
    {
        return NULL
    }

    member ToText()
    {
        return "${Name~}"
    }
}

objectdef windowLayoutGenerators
{    
    variable windowLayoutGenerator_Edge Edge
    variable windowLayoutGenerator_Stacked Stacked    
    variable windowLayoutGenerator_ScreenPer ScreenPer    

    variable collection:weakref Generators

    method Initialize()
    {
        Generators:Set["${Edge~}",Edge]
        Generators:Set["${Stacked~}",Stacked]
        Generators:Set["${ScreenPer~}",ScreenPer]
;        Generators:Set["${Horizontal~}",Horizontal]
;        Generators:Set["${Vertical~}",Vertical]
    }

    member:weakref GetGenerator(string name)
    {
        return "This.Generators.Get[${name~}]"
    }
}

/*
input
{
    "numSlots":5,
    "useMonitor":1,
    "monitors":[
        {
            "id":0,
            "name":"\\\\.\\DISPLAY609",
            "primary":true,"left":0,"right":1920,"top":0,"bottom":1080,"width":1920,"height":1080,
            "maximizeLeft":0,"maximizeRight":1920,"maximizeTop":0,"maximizeBottom":1040,"maximizeWidth":1920,"maximizeHeight":1040
        }
    ],
    "avoidTaskbar":false,
    "leaveHole":true
}
output:
[
    {"mainRegion":true,"x":0,"y":0,"width":1920,"height":900},
    {"x":0,"y":900,"width":384,"height":180},
    {"x":384,"y":900,"width":384,"height":180},
    {"x":768,"y":900,"width":384,"height":180},
    {"x":1152,"y":900,"width":384,"height":180},
    {"x":1536,"y":900,"width":384,"height":180}
]
*/

objectdef windowLayoutGenerator_Common inherits windowLayoutGenerator
{
        variable uint numSlots
        variable uint useMonitor
        variable uint numInactiveRegions
        variable jsonvalueref joMonitor
        variable uint monitorWidth
        variable uint monitorHeight
        variable int monitorX
        variable int monitorY

    member:jsonvalueref GenerateRegions_Subclass(jsonvalueref joInput)
    {
        return NULL
    }

    member:jsonvalueref GenerateRegions(jsonvalueref joInput)
    {
        variable jsonvalue ja
        useMonitor:Set[${joInput.GetInteger[useMonitor]}]
        
        if !${useMonitor}
            useMonitor:Set[1]

        joMonitor:SetReference["joInput.Get[monitors,${useMonitor}]"]
        if !${joMonitor.Reference(exists)}
            return NULL

        numInactiveRegions:Set[${joInput.GetInteger[numInactiveRegions]}]

        numSlots:Set[${joInput.GetInteger[numSlots]}]
        if !${numSlots}
            numSlots:Set[1]
;        echo monitor=${joMonitor~} width=${joMonitor.GetNumber[width]}

        if !${numInactiveRegions}
            numInactiveRegions:Set[${numSlots}]

        if ${joInput.GetBool[avoidTaskbar]}
        {
            monitorX:Set["${joMonitor.GetNumber[maximizeLeft]}"]
            monitorY:Set["${joMonitor.GetNumber[maximizeTop]}"]
            monitorWidth:Set["${joMonitor.GetNumber[maximizeWidth]}"]
            monitorHeight:Set["${joMonitor.GetNumber[maximizeHeight]}"]
        }
        else
        {
            monitorX:Set["${joMonitor.GetNumber[left]}"]
            monitorY:Set["${joMonitor.GetNumber[top]}"]
            monitorWidth:Set["${joMonitor.GetNumber[width]}"]
            monitorHeight:Set["${joMonitor.GetNumber[height]}"]
        }

        ; if there's only 1 window, just go full screen windowed
        if ${numSlots}==1
        {
            ja:SetValue["$$>
            [
                {
                    "mainRegion":true,
                    "x":${monitorX},
                    "y":${monitorY},
                    "width":${monitorWidth},
                    "height":${monitorHeight},
                    "numRegion":1
                }
            ]
            <$$"]
            return ja
        }

        return "This.GenerateRegions_Subclass[joInput]"
    }

}

objectdef windowLayoutGenerator_ScreenPer inherits windowLayoutGenerator
{
    method Initialize()
    {
        Name:Set[ScreenPer]
        Description:Set["Generates a layout where each window is assigned to its own monitor (reusing monitors if there's too many characters)"]
    }

    member:jsonvalueref GenerateForScreen(jsonvalueref joInput, uint numMonitor, bool mainRegion)
    {
        variable jsonvalue joRegion

        variable bool avoidTaskbar=${joInput.GetBool[avoidTaskbar]}

        variable jsonvalueref joMonitor
        variable uint monitorWidth
        variable uint monitorHeight
        variable int monitorX
        variable int monitorY
        
        joMonitor:SetReference["joInput.Get[monitors,${numMonitor}]"]
        if !${joMonitor.Reference(exists)}
            return NULL

        if ${avoidTaskbar}
        {
            monitorX:Set["${joMonitor.GetNumber[maximizeLeft]}"]
            monitorY:Set["${joMonitor.GetNumber[maximizeTop]}"]
            monitorWidth:Set["${joMonitor.GetNumber[maximizeWidth]}"]
            monitorHeight:Set["${joMonitor.GetNumber[maximizeHeight]}"]
        }
        else
        {
            monitorX:Set["${joMonitor.GetNumber[left]}"]
            monitorY:Set["${joMonitor.GetNumber[top]}"]
            monitorWidth:Set["${joMonitor.GetNumber[width]}"]
            monitorHeight:Set["${joMonitor.GetNumber[height]}"]
        }

        joRegion:SetValue["$$>
            {
                "x":${monitorX},
                "y":${monitorY},
                "width":${monitorWidth},
                "height":${monitorHeight}
            }
        <$$"]

        if ${mainRegion}
            joRegion:SetBool[mainRegion,1]

        return joRegion
    }
    
    member:jsonvalueref GenerateRegions(jsonvalueref joInput)
    {
        variable jsonvalue ja=[]
        variable uint numMonitors=${joInput.Get[monitors].Used}
        variable uint numInactiveRegions=${joInput.GetInteger[numInactiveRegions]}
        variable uint numSlots=${joInput.GetInteger[numSlots]}

        if !${numSlots}
            numSlots:Set[1]

        if !${numInactiveRegions}
            numInactiveRegions:Set[${numSlots}-1]

        numSlots:Set[${numInactiveRegions}+1]

        variable uint numSlot
        variable jsonvalue joRegion
        variable bool mainRegion=1
        variable uint useMonitor
        for (numSlot:Set[1] ; ${numSlot}<=${numSlots} ; numSlot:Inc)
        {
            useMonitor:Set[(${numSlot.Dec}%${numMonitors})+1]            
            joRegion:SetValue["${This.GenerateForScreen[joInput,${useMonitor},${mainRegion}]~}"]
            joRegion:SetInteger["numRegion",${numSlot}]

            ja:Add["${joRegion~}"]

            mainRegion:Set[0]            
        }

        return ja
    }
}

objectdef windowLayoutGenerator_Stacked inherits windowLayoutGenerator_Common
{
    method Initialize()
    {
        Name:Set[Stacked]
        Description:Set["Generates a layout where all windows are stacked on top of each other in the same place (for example, full screen)"]
    }

    member:jsonvalueref GenerateRegions_Subclass(jsonvalueref joInput)
    {
        variable jsonvalue ja="[]"
        variable jsonvalue joRegion

        ; main region
        joRegion:SetValue["$$>
            {
                "mainRegion":true,
                "x":${monitorX},
                "y":${monitorY},
                "width":${monitorWidth},
                "height":${monitorHeight},
                "numRegion":1
            }
        <$$"]

        ja:Add["${joRegion~}"]

        variable uint numSlot

        joRegion:SetValue["$$>
            {
                "x":${monitorX},
                "y":${monitorY},
                "width":${monitorWidth},
                "height":${monitorHeight}
            }
        <$$"]

        for (numSlot:Set[1] ; ${numSlot}<=${numInactiveRegions} ; numSlot:Inc)
        {
            joRegion:SetInteger[numRegion,${numSlot.Inc}]
            ja:Add["${joRegion~}"]
        }
        return ja
    }
}

objectdef windowLayoutGenerator_Edge inherits windowLayoutGenerator_Common
{
    method Initialize()
    {
        Name:Set[Edge]
        Description:Set["Generates a standard layout with small regions along an edge of the screen"]
    }

    member:jsonvalueref GenerateRegions_Subclass(jsonvalueref joInput)
    {
        switch ${joInput.Get[edge]~}
        {
            case left
            case right
                return "This.GenerateRegions_Vertical[joInput]"
            case top
            case bottom
                return "This.GenerateRegions_Horizontal[joInput]"
        }
    }

     member:jsonvalueref GenerateRegions_Horizontal(jsonvalueref joInput)
    {
        variable jsonvalue ja="[]"
        variable jsonvalue joRegion

        variable uint mainHeight
        variable uint mainWidth
        variable uint smallHeight
        variable uint smallWidth            

        variable bool useBottom=${joInput.Get[edge]~.NotEqual[top]}

        if !${joInput.GetBool[leaveHole]} && !${joInput.Has[numInactiveRegions]}
            numInactiveRegions:Dec

        ; 2 windows is actually a 50/50 split screen and should probably handle differently..., pretend there's 3
        if ${numInactiveRegions}<3
            numInactiveRegions:Set[3]

        mainWidth:Set["${monitorWidth}"]
        mainHeight:Set["${monitorHeight}*${numInactiveRegions}/(${numInactiveRegions}+1)"]

        smallHeight:Set["${monitorHeight}-${mainHeight}"]
        smallWidth:Set["${monitorWidth}/${numInactiveRegions}"]

        variable int useY=${monitorY}
        if !${useBottom}
            useY:Set[${monitorY}+${smallHeight}]

        ; main region
        joRegion:SetValue["$$>
            {
                "mainRegion":true,
                "x":${monitorX},
                "y":${useY},
                "width":${mainWidth},
                "height":${mainHeight},
                "numRegion":1
            }
        <$$"]

        ja:Add["${joRegion~}"]

        variable int useX=${monitorX}
        variable uint numSlot

        useY:Set[${mainHeight}+${monitorY}]
        if !${useBottom}
        {
            useY:Set[${monitorY}]
        }

        joRegion:SetValue["$$>
            {
                "x":${useX},
                "y":${useY},
                "width":${smallWidth},
                "height":${smallHeight}
            }
        <$$"]

        for (numSlot:Set[1] ; ${numSlot}<=${numInactiveRegions} ; numSlot:Inc)
        {
            joRegion:SetInteger[x,${useX}]
            joRegion:SetInteger[numRegion,${numSlot.Inc}]
            ja:Add["${joRegion~}"]
            useX:Inc["${smallWidth}"]
        }

        return ja
    }

    member:jsonvalueref GenerateRegions_Vertical(jsonvalueref joInput)
    {
        variable jsonvalue ja="[]"
        variable jsonvalue joRegion

        variable uint mainHeight
        variable uint mainWidth
        variable uint smallHeight
        variable uint smallWidth            

        variable bool useRight=${joInput.Get[edge]~.NotEqual[left]}

        if !${joInput.GetBool[leaveHole]} && !${joInput.Has[numInactiveRegions]}
            numInactiveRegions:Dec

        ; 2 windows is actually a 50/50 split screen and should probably handle differently..., pretend there's 3
        if ${numInactiveRegions}<3
            numInactiveRegions:Set[3]

        mainHeight:Set["${monitorHeight}"]
        mainWidth:Set["${monitorWidth}*${numInactiveRegions}/(${numInactiveRegions}+1)"]

        smallWidth:Set["${monitorWidth}-${mainWidth}"]
        smallHeight:Set["${monitorHeight}/${numInactiveRegions}"]

        variable int useX=${monitorX}
        if !${useRight}
            useX:Set[${monitorX}+${smallWidth}]

        ; main region
        joRegion:SetValue["$$>
            {
                "mainRegion":true,
                "x":${useX},
                "y":${monitorY},
                "width":${mainWidth},
                "height":${mainHeight},
                "numRegion":1
            }
        <$$"]

        ja:Add["${joRegion~}"]

        variable int useY=${monitorY}
        variable uint numSlot

        useX:Set[${mainWidth}+${monitorX}]
        if !${useRight}
        {
            useX:Set[${monitorX}]
        }
        joRegion:SetValue["$$>
            {
                "x":${useX},
                "y":${useY},
                "width":${smallWidth},
                "height":${smallHeight}
            }
        <$$"]

        for (numSlot:Set[1] ; ${numSlot}<=${numInactiveRegions} ; numSlot:Inc)
        {
            joRegion:SetInteger[y,${useY}]
            joRegion:SetInteger[numRegion,${numSlot.Inc}]
            ja:Add["${joRegion~}"]
            useY:Inc["${smallHeight}"]
        }

        return ja
    }
}
