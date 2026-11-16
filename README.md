# Copy Selected Filenames

A **Lightroom Classic** plug-in for macOS that copies the filenames of the selected photos to the clipboard.

It does not export images, rename files, or write to the catalog. Last-used options are remembered.

## Requirements

- **macOS** (uses `/usr/bin/pbcopy`)
- **Lightroom Classic 6** or later, including current Lightroom Classic

This will not load in the cloud-native **Lightroom** app (the one without “Classic” in the name), Lightroom web/mobile, or Lightroom on Windows.

## Install

The loadable plug-in is the `CopyFilenames.lrplugin` folder in this repository. On a Mac that folder looks like a single file in Finder; that is expected.

1. Clone the repo or download the ZIP from GitHub. Keep `CopyFilenames.lrplugin` intact — do not rename it or open it as a package.
2. Move the clone somewhere permanent. Lightroom stores a *reference* to that location, so do not leave it in Downloads if you might delete it later. `Documents` is fine.
3. In Lightroom Classic, open **File > Plug-in Manager**.
4. Click **Add**, select the `CopyFilenames.lrplugin` folder, and confirm it is enabled.

**Optional:** copy `CopyFilenames.lrplugin` into `~/Library/Application Support/Adobe/Lightroom/Modules/`. Lightroom then loads it automatically. Plug-ins in that folder can be disabled but not removed from Plug-in Manager.

To update, pull the latest files and click **Reload** under Plug-in Author Tools in Plug-in Manager (or restart Lightroom). If Lightroom was already pointing at this folder, you do not need to Add it again.

## Use

1. In the **Library** module, select one or more photos. Grid view is recommended.
2. Choose **Library > Plug-in Extras > Copy Selected Filenames**.
3. Choose how names are separated (one per line, spaces, or commas) and whether to keep the file extension.
4. Click **Copy**, then paste with **Cmd+V**.

The command only appears in the Library module.

## Notes

- Names come from the catalog (the files on disk), not from export renaming templates.
- Comma-separated lists use a comma and a space: `file1.jpg, file2.jpg`.
- In Loupe view, Lightroom may report only the photo on screen even if more were selected in Grid. Use Grid for a multi-photo copy.
- Virtual copies share the master’s filename.

## License

[MIT](LICENSE)
