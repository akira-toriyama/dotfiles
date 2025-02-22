use framework "CoreGraphics"

on run argv
    application's CGWarpMouseCursorPosition({(item 1 of argv), (item 2 of argv)})
end run
