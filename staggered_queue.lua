function widget:GetInfo()
  return {
      name = "Staggered Queue",
      desc = "When buildings are queued, the constructor will start each building for 5 seconds then move on to the next in the queue.",
      author = "Phyziik",
      date = "2023-06-06",
      license = 'GNU GPL, v2 or later',
      layer = 0,
      enabled = true
  }
end

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetCommandQueue = Spring.GetCommandQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitDefID = Spring.GetUnitDefID

local unitWorkTimes = {}
local unitCurrentCommands = {}
local unitLastBuildProgress = {}

local stagger = false

function widget:KeyPress(key, modifier, isRepeat)
  if (modifier.shift and modifier.ctrl and modifier.alt and key == 115) or
      (modifier.shift and modifier.alt and key == 115) then
      stagger = not stagger
      //Spring.Echo("Stagger Mode:" .. tostring(stagger))
      return true
  end
  return false
end

function widget:GameFrame(n)
local myTeamID = spGetMyTeamID()
local myUnits = spGetTeamUnits(myTeamID)

for i = 1, #myUnits do
    local unitID = myUnits[i]
    local unitDefID = spGetUnitDefID(unitID)
    local unitDef = UnitDefs[unitDefID]

    if unitDef.isBuilder and stagger then -- check if the unit is a constructor
        local commands = spGetCommandQueue(unitID, -1)

        if commands and #commands > 0 then
            local currentCommandID = commands[1].id
            if currentCommandID < 0 then -- check if the command is a build command
                local currentBuilding = spGetUnitIsBuilding(unitID)
                if currentBuilding then
                    if currentCommandID ~= unitCurrentCommands[unitID] then -- Unit has started a new building
                        unitCurrentCommands[unitID] = currentCommandID
                        unitWorkTimes[unitID] = n
                        unitLastBuildProgress[unitID] = select(1, Spring.GetUnitHealth(currentBuilding))
                        //Spring.Echo("Unit " .. unitID .. " started a new building.")
                    end

                    local buildProgress = select(1, Spring.GetUnitHealth(currentBuilding))
                    if buildProgress > unitLastBuildProgress[unitID] then -- Unit has been actively building since last frame
                        unitLastBuildProgress[unitID] = buildProgress
                        if n - unitWorkTimes[unitID] >= 30 * 1 and #commands > 1 then -- 0.25 seconds
                            spGiveOrderToUnit(unitID, CMD.REMOVE, {commands[1].tag}, {"ctrl"})
                            unitCurrentCommands[unitID] = nil
                            //Spring.Echo("Unit " .. unitID .. " moving to next building in the queue: " .. currentBuilding)
                        end
                    else
                        unitWorkTimes[unitID] = n -- Reset work time if unit was not actively building
                    end
                else
                    unitWorkTimes[unitID] = nil
                    unitCurrentCommands[unitID] = nil
                    unitLastBuildProgress[unitID] = nil
                end
            end
        end
    end
end
end
