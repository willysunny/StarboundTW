require "/interface/games/util.lua"
require "/scripts/vec2.lua"
require "/interface/games/fossilgame/generator.lua"
require "/interface/games/fossilgame/tools.lua"
require "/interface/games/fossilgame/tileset.lua"
require "/interface/games/fossilgame/ui.lua"

function init()
  self.toolButtons = RadioButtonSet:new()

  self.progressBar = ProgressBar:new({200, 110})
  self.progressBar.size[1] = 100
  self.progressBar.value = 0

  self.durabilityBar = ProgressBar:new({200, 140})
  self.durabilityBar.size[1] = 100
  self.durabilityBar.value = 0

  loadFromObject()
end

function initState(level, toolUses)
  self.level = level
  self.level.onComplete = function() 
    if not self.level.fossilDamaged then
      win()
    end
  end

  self.tools = {
    BrushTool:new(self.level),
    HammerTool:new(self.level, 0),
    PickaxeTool:new(self.level, 0)
  }
  for toolName,uses in pairs(toolUses) do
    for _,tool in pairs(self.tools) do
      if tool.name == toolName then
        tool.uses = uses
      end
    end
  end

  self.fossilCounter = Sprite:new("/interface/games/fossilgame/images/fossilcountericon.png", {21,21}, {1,1})
  self.winScreen = Sprite:new("/interface/games/fossilgame/images/winningframe.png", {278,203})
  self.frame = Sprite:new("/interface/games/fossilgame/images/frame.png", {314,221})

  self.toolButtons:add(ToggleButton:new("/interface/games/fossilgame/images/brushicon.png", {14,14}, {234,81}), self.tools[1])
  self.toolButtons:add(ToggleButton:new("/interface/games/fossilgame/images/hammericon.png", {14,14}, {255,81}), self.tools[2])
  self.toolButtons:add(ToggleButton:new("/interface/games/fossilgame/images/pickicon.png", {14,14}, {275,81}), self.tools[3])

  save()

  self.initialized = true
end

function generateLevel()
  local generator = LevelGenerator:new({
    HammerTool,
    PickaxeTool
  })

  generator.toolRockChance = console.configParameter("toolRockChance", 0.5)
  generator.randomRockChance = console.configParameter("randomRockChance", 0.3)

  local size = {math.random(10,10), math.random(9,9)}
  local position = {30,39}

  local level, toolUses = generator:generate(size, 16, position, 8, 3, 129)
  return level, toolUses
end

function save()
  local data = {
    levelData = self.level:save(),
    toolUses = toolData()
  }
  world.sendEntityMessage(console.sourceEntity(), "save", data)
end

function loadFromObject()
  self.loadHandler = world.sendEntityMessage(console.sourceEntity(), "load")
end

function loadState(data)
  local level = Level:load(data.levelData)
  local toolUses = data.toolUses
  return level, data.toolUses
end

function activeTool()
  return self.toolButtons.value
end

function toolData()
  local data = {}
  for _,tool in pairs(self.tools) do
    data[tool.name] = tool.uses
  end
  return data
end

function win()
  self.won = true
  self.splash = true
  self.level:removeFossil()
  console.playSound("/sfx/objects/colonydeed_partyhorn.ogg")
end

function update(dt)
  if not self.initialized then
    if self.loadHandler:finished() then
      local result = self.loadHandler:result()
      local level
      local toolUses
      if result then
        level, toolUses = loadState(result)
      else
        level, toolUses = generateLevel()
      end

      initState(level, toolUses)
    end
  else
    activeTool():update(dt)
    self.level:update(dt)

    draw()
  end
end

function draw()
  self.level:draw()

  drawGui()

  if self.splash then
    self.winScreen:draw({18,9})
  else
    activeTool():draw()
  end
end

function drawGui()
  self.frame:draw({0,0})

  console.canvasDrawText("挖掘", {position = {230, 183}, width = 88, center = true}, 12)
  console.canvasDrawText("進度", {position = {235, 171}, width = 88, center = true}, 12)
  local progressColor = {255,255,255}
  if self.level.fossilDamaged then
    progressColor = {255,0,0}
  end
  console.canvasDrawText(self.level.progress .. "/" .. #self.level.fossilTiles, {position = {255, 153}}, 12, progressColor)
  self.fossilCounter:draw({230, 136})

  self.toolButtons:draw()

  console.canvasDrawText("工具", {position = {236, 116}, width = 88, center = true}, 12)
  local color = self.tools[2].uses == 0 and {255, 0, 0} or {255, 255, 255}
  console.canvasDrawText(self.tools[2].uses, {position = {270,88}}, 8, color)

  color = self.tools[3].uses == 0 and {255, 0, 0} or {255, 255, 255}
  console.canvasDrawText(self.tools[3].uses, {position = {290,88}}, 8, color)
end

function mousePosition()
  local position = console.canvasMousePosition()
  position[1] = position[1] + 3
  position[2] = position[2] - 1
  return position
end

function canvasClickEvent(position, button, isButtonDown)
  if isButtonDown then
    --world.logInfo("Button %s was pressed at %s", button, position)
    if self.splash then
      self.splash = false
    else
      activeTool():trigger()
      self.toolButtons:handleClick({position = position, button = button})
    end
  else
    --world.logInfo("Button %s was released at %s", button, position)
    activeTool():release()
  end
end

function canvasKeyEvent(key, isKeyDown)
  if isKeyDown then
    --world.logInfo("Key %s was pressed", key)
    if key == 49 then
      self.toolButtons:selectIndex(1)
    end
    if key == 50 then
      self.toolButtons:selectIndex(2)
    end
    if key == 51 then
      self.toolButtons:selectIndex(3)
    end
  else
    --world.logInfo("Key %s was released", key)
  end
end

function uninit()
  save()
end