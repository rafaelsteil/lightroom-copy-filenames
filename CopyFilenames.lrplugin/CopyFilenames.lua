--[[
Copy selected photo filenames to the macOS clipboard.

Lightroom has no clipboard API and this plug-in must not export or rename
anything, so names are read from catalog metadata, written to a temp file,
and piped to pbcopy. Putting the names on the command line would break on
spaces, quotes, and large selections.
]]

local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'
local LrDialogs = import 'LrDialogs'
local LrErrors = import 'LrErrors'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local SEPARATORS = {
    newline = '\n',
    spaces = ' ',
    commas = ', ',
}

-- The temp path is the only value that reaches the shell.
local function shellQuote(value)
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

-- Prefer the catalog's display filename; fall back to the file path when
-- formatted metadata is empty (typical for some offline/missing photos).
local function photoFileName(photo)
    local filename = photo:getFormattedMetadata('fileName')
    if filename and filename ~= '' then
        return filename
    end
    local path = photo:getRawMetadata('path')
    if path and path ~= '' then
        return LrPathUtils.leafName(path)
    end
    return nil
end

local function displayName(filename, includeExtension)
    if includeExtension then
        return filename
    end
    -- Keep the original if stripping the extension would leave nothing.
    local withoutExt = LrPathUtils.removeExtension(filename)
    if withoutExt and withoutExt ~= '' then
        return withoutExt
    end
    return filename
end

-- throwUserError surfaces a readable message instead of a Lua file:line dump.
local function writeFile(path, contents)
    local file, openError = io.open(path, 'wb')
    if not file then
        LrErrors.throwUserError('Could not create temporary file: ' .. tostring(openError))
    end
    local wrote, writeError = file:write(contents)
    local closed, closeError = file:close()
    if not wrote or not closed then
        LrErrors.throwUserError('Could not write temporary file: ' .. tostring(writeError or closeError))
    end
end

local function showCopyDialog(context, photoCount)
    local prefs = LrPrefs.prefsForPlugin()
    local props = LrBinding.makePropertyTable(context)

    -- Copy prefs into a transient table so Cancel does not persist edits.
    if prefs.separator == 'spaces' or prefs.separator == 'commas' then
        props.separator = prefs.separator
    else
        props.separator = 'newline'
    end

    -- `or true` would treat an explicit false as missing and reset the checkbox.
    if prefs.includeExtension == false then
        props.includeExtension = false
    else
        props.includeExtension = true
    end

    local f = LrView.osFactory()
    local bind = LrView.bind
    local countLabel = string.format(
        '%d filename%s will be copied.',
        photoCount,
        photoCount == 1 and '' or 's'
    )
    local iconPath = LrPathUtils.child(_PLUGIN.path, 'Icon.jpg')

    -- f:picture often fails to load PNG (especially with alpha) and resourceId
    -- references. A small JPEG from the plug-in folder is what actually shows.
    -- The trailing spacer absorbs extra row width so the count stays left of
    -- the icon instead of being pushed to the far right.
    local header = f:row {
        fill_horizontal = 1,
        spacing = 10,
        f:picture {
            value = iconPath,
            width = 48,
            height = 48,
            frame_width = 0,
        },
        f:static_text {
            title = countLabel,
            alignment = 'left',
            place_vertical = 0.5,
            text_color = LrColor(0.42, 0.42, 0.45),
        },
        f:spacer { fill_horizontal = 1 },
    }

    local result = LrDialogs.presentModalDialog {
        title = 'Copy selected filenames',
        actionVerb = 'Copy',
        contents = f:column {
            bind_to_object = props,
            spacing = f:control_spacing(),

            header,

            f:group_box {
                title = '',
                show_title = false,
                fill_horizontal = 1,
                spacing = f:control_spacing(),
                f:row {
                    spacing = f:label_spacing(),
                    fill_horizontal = 1,
                    f:static_text {
                        title = 'Separate filenames:',
                    },
                    f:popup_menu {
                        value = bind('separator'),
                        fill_horizontal = 1,
                        items = {
                            { title = 'One per line', value = 'newline' },
                            { title = 'Spaces', value = 'spaces' },
                            { title = 'Commas', value = 'commas' },
                        },
                    },
                },
                f:separator { fill_horizontal = 1 },
                f:checkbox {
                    title = 'Include file extension',
                    value = bind('includeExtension'),
                },
            },
        },
    }

    if result ~= 'ok' then
        return nil
    end

    prefs.separator = props.separator
    prefs.includeExtension = props.includeExtension
    return props.separator, props.includeExtension
end

-- Catalog reads, dialogs, and LrTasks.execute must run in a task. A function
-- context is used so errors become user dialogs (not stack traces) and the
-- temp file is deleted even when pbcopy fails.
LrFunctionContext.postAsyncTaskWithContext('Copy selected filenames', function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    if not MAC_ENV then
        LrErrors.throwUserError('This plugin requires macOS.')
    end

    local catalog = LrApplication.activeCatalog()
    local activePhoto = catalog:getTargetPhoto()
    if not activePhoto then
        LrDialogs.message('Copy Selected Filenames', 'Select one or more photos first.', 'info')
        return
    end

    -- getTargetPhotos() returns the whole filmstrip when nothing is selected.
    -- The active-photo check above is what prevents that.
    local photos = catalog:getTargetPhotos()
    if not photos or #photos == 0 then
        photos = { activePhoto }
    end

    local names = {}
    for _, photo in ipairs(photos) do
        local filename = photoFileName(photo)
        if filename then
            names[#names + 1] = filename
        end
    end

    if #names == 0 then
        LrDialogs.message('Copy Selected Filenames', 'No filenames were found.', 'warning')
        return
    end

    local separator, includeExtension = showCopyDialog(context, #names)
    if not separator then
        return
    end

    local outputNames = {}
    for _, filename in ipairs(names) do
        outputNames[#outputNames + 1] = displayName(filename, includeExtension)
    end

    local tempDir = LrPathUtils.getStandardFilePath('temp') or '/tmp'
    local tempPath = LrFileUtils.chooseUniqueFileName(
        LrPathUtils.child(tempDir, 'lightroom-selected-filenames.txt')
    )

    context:addCleanupHandler(function()
        LrFileUtils.delete(tempPath)
    end)

    writeFile(tempPath, table.concat(outputNames, SEPARATORS[separator] or '\n'))

    -- Lightroom often runs with a non-UTF-8 locale, which would mangle
    -- non-ASCII filenames in pbcopy.
    local command = 'LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /usr/bin/pbcopy < ' .. shellQuote(tempPath)
    local exitCode = LrTasks.execute(command)
    if exitCode ~= 0 then
        LrErrors.throwUserError('pbcopy failed (exit code ' .. tostring(exitCode) .. '). This plugin requires macOS.')
    end

    local message = string.format('Copied %d filename%s to the clipboard.', #outputNames, #outputNames == 1 and '' or 's')
    LrDialogs.showBezel(message)
end)
