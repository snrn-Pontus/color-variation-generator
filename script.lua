function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function setupDialog(plugin)
    local setup_dlg = Dialog("Sprite Generator")

    if plugin.preferences.output == nil then
        plugin.preferences.output = "slices"
    end

    if plugin.preferences.baseName == nil then
        plugin.preferences.baseName = app.activeSprite.filename:gsub(".png", "")
    end

    if plugin.preferences.columns == nil then
        plugin.preferences.columns = 1
    end

    if plugin.preferences.divider == nil then
        plugin.preferences.divider = "_"
    end

    if plugin.preferences.selectedColors == nil then
        plugin.preferences.selectedColors = {}
    end

    --setup_dlg:button {
    --    id = "debug",
    --    text = "Debug",
    --    onclick = function()
    --        print(dump(plugin.preferences))
    --        print(dump(setup_dlg.data))
    --    end
    --}

    setup_dlg:combobox { id = "output",
                         label = "Output:",
                         option = plugin.preferences.output,
                         options = {
                             "slices",
                             "frames",
                             "sprites",
                         },
    }

    --setup_dlg:number { id = "columns",
    --                   label = "Columns:",
    --                   text = plugin.preferences.columns,
    --                   decimals = 0,
    --}

    setup_dlg:slider { id = "columns",
                       label = "Columns:",
                       min = 1,
                       max = 10,
                       value = plugin.preferences.columns,
                       onchange = function(ev)
                           plugin.preferences.columns = ev.value
                       end }

    setup_dlg:entry { id = "baseName",
                      label = "base name:",
                      text = plugin.preferences.baseName,
                      onchange = function(ev)
                          setup_dlg:modify {
                              id = "nameExample",
                              text = setup_dlg.data.baseName .. setup_dlg.data.divider .. 1,
                          }
                      end,
    }
    setup_dlg:entry { id = "divider",
                      label = "divider:",
                      text = plugin.preferences.divider,
                      onchange = function(ev)
                          setup_dlg:modify {
                              id = "nameExample",
                              text = setup_dlg.data.baseName .. setup_dlg.data.divider .. 1,
                          }
                      end,
    }

    setup_dlg:label { id = "nameExample", label = "Example name", text = app.activeSprite.filename:gsub(".png", "") .. "_" .. 1 }
             :newrow()
             :separator()

    local paletteColors = {}
    local palette = app.activeSprite.palettes[1]

    for i = 1, #palette do
        paletteColors[i] = palette:getColor(i - 1)
    end

    setup_dlg:shades { id = "palette",
                       label = "Shades",
                       mode = "sort",
                       colors = paletteColors,
                       onclick = function(ev)
                           table.insert(plugin.preferences.selectedColors, ev.color)
                           setup_dlg:modify {
                               id = "shades",
                               colors = plugin.preferences.selectedColors,
                           }
                       end,
    }
    setup_dlg:shades { id = "shades",
                       label = "Shades",
                       mode = "sort",
                       colors = plugin.preferences.selectedColors,
                       onclick = function(ev)
                           for i = 1, #plugin.preferences.selectedColors do
                               if plugin.preferences.selectedColors[i] == ev.color then
                                   table.remove(plugin.preferences.selectedColors, i)
                                   break
                               end
                           end
                           setup_dlg:modify {
                               id = "shades",
                               colors = plugin.preferences.selectedColors,
                           }
                       end
    }

    setup_dlg:button { id = "cancel", text = "Cancel" }
    setup_dlg:button { id = "next", text = "Next" }
    setup_dlg:show()

    local setup_data = setup_dlg.data

    if setup_data.cancel then
        return
    end

    if setup_data.next then
        return setup_data
    end
end

function generationDialog(numberOfSprites, sprite, output, selectedColors, baseName, divider)

    local dlg = Dialog(
            "Sprite Generator"
    )

    dlg:label { id = "label", text = "Generating: " .. numberOfSprites .. " " .. output .. " from " .. sprite.filename .. "..." }
       :newrow()
       :separator()

    local doubleStep = 1

    for i = 1, numberOfSprites do

        if (output == "sprites") or (output == "slices") then
            dlg:entry { id = "colorName_" .. i, label = "Color name:", text = baseName .. divider .. i }
        end

        dlg:color { id = "color_1_" .. i, label = "Color " .. i, color = selectedColors[doubleStep] }
        dlg:color { id = "color_2_" .. i, label = "Color " .. i, color = selectedColors[doubleStep + 1] }

        doubleStep = doubleStep + 2
    end

    dlg:button { id = "cancel", text = "Cancel" }
    dlg:button { id = "confirm", text = "Generate" }
    dlg:show()

    if dlg.data.cancel then
        return
    end

    if dlg.data.confirm then
        return dlg.data
    end

end

function init(plugin)
    plugin:newCommand {
        id = "sprite_variant",
        title = "Generate variants",
        group = "edit_new",
        onclick = function()
            local setup_data = setupDialog(plugin)

            if setup_data == nil then
                return
            end

            local output = setup_data.output
            plugin.preferences.output = output

            local columns = setup_data.columns
            plugin.preferences.columns = columns

            local selectedColors = setup_data.shades
            local baseName = setup_data.baseName
            local divider = setup_data.divider

            local numberOfSprites = #selectedColors / 2

            local sprite = app.activeSprite

            local generation_data = generationDialog(numberOfSprites, sprite, output, selectedColors, baseName, divider)

            if generation_data == nil then
                return
            end

            if output == "sprites" then
                generateSprites(generation_data, numberOfSprites, sprite)
            elseif output == "frames" then
                generateFrames(generation_data, numberOfSprites, sprite)
            elseif output == "slices" then
                generateSlices(generation_data, numberOfSprites, sprite, columns)
            end
        end
    }
end

function replaceColors(data, i)
    app.command.ReplaceColor {
        ui = false,
        from = Color(0, 0, 0),
        to = data["color_1_" .. i],
        tolerance = 0
    }
    app.command.ReplaceColor {
        ui = false,
        from = Color(255, 255, 255),
        to = data["color_2_" .. i],
        tolerance = 0
    }
end

function generateSprites(data, numberOfSprites, sprite)
    for i = 1, numberOfSprites do

        local s = Sprite(sprite)

        replaceColors(data, i)

        s:saveAs(data["colorName_" .. i]:gsub(".png", "") .. ".png")
    end
end

function generateFrames(data, numberOfSprites, sprite)
    for i = 1, numberOfSprites do
        sprite:newFrame(1)
        replaceColors(data, i)
        --local frame = sprite:newFrame(1)
        --local tag = sprite:newTag(frame.frameNumber, frame.frameNumber)
        --tag.name = data["colorName_" .. i]
    end

    --app.command.ExportSpriteSheet {
    --    ui = true,
    --    type = SpriteSheetType.HORIZONTAL,
    --    textureFilename = sprite.filename .. "_sheet.png",
    --    dataFilename = sprite.filename .. "_sheet.json",
    --    dataFormat = SpriteSheetDataFormat.JSON_HASH,
    --    filenameFormat = "{title} ({layer}) {frame}.{extension}",
    --    ignoreEmpty = true,
    --    mergeDuplicates = true,
    --    openGenerated = true,
    --    splitTags = false,
    --    splitGrid = false,
    --    listLayers = true,
    --    listTags = true,
    --    listSlices = true,
    --    fromTilesets = false,
    --}
end

function generateSlices(data, numberOfSprites, sprite, columns)

    local sourceImage = app.activeCel.image

    local left = sourceImage.cel.bounds.x;
    local top = sourceImage.cel.bounds.y;
    local right = sourceImage.cel.bounds.x + sourceImage.cel.bounds.width;
    local bottom = sourceImage.cel.bounds.y + sourceImage.cel.bounds.height;

    local width = sprite.width
    local height = sprite.height

    targetSprite = Sprite(width * columns, height * math.ceil(numberOfSprites / columns))
    app.command.BackgroundFromLayer()

    local outputImage = app.activeCel.image

    for i = 1, numberOfSprites do
        local x = ((i - 1) % columns) * width
        local y = math.floor((i - 1) / columns) * height
        print(dump(sourceImage.cel.bounds))
        outputImage:drawImage(sourceImage, x + left, y + top)
        replaceColors(data, i);
        local slice = targetSprite:newSlice(
                Rectangle(x, y, width, height)
        )
        slice.name = data["colorName_" .. i]
    end

    app.refresh()
end

function exit(plugin)

end
