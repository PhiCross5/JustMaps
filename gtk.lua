local lgi = require("lgi")
local time = require("posix.unistd")

local inotify = require("inotify")
local poll = require("posix.poll")

local gtk = lgi.Gtk
local async = lgi.Gio.Async
local glib = lgi.GLib

local osmParser = require("osmParser")

gtk.init()

local daMap = osmParser.parse_xml("osm.xml")

local window = gtk.Window{
    id = "main",
    title = "hello world",
    default_width=332, default_height=332,
    gtk.Grid {
        orientation = gtk.Orientation.VERTICAL,
        gtk.Toolbar{
            gtk.ToolButton {id = "about", stock_id = gtk.STOCK_ABOUT},
            gtk.ToolButton {id = "quit", stock_id = gtk.STOCK_QUIT}
        },
        gtk.Label {
            id="monitor",
            label="no changes yet."
        }
    }
}

window.child.quit.on_clicked = function()
    window:destroy()
end



local fileChangeScanner = coroutine.create(function(filename)
    local ihandle = inotify.init{blocking = false}
    local iwatch = ihandle:addwatch("osmParser.lua", inotify.IN_MODIFY)
    local ifd = ihandle:getfd()

    --the time it takes until a change is checked for again.
    --all delays inside this function have this value unless *the same variable* is overriden inside another scope
    local pollInterval = 100

    local state = "unchanged"
    local recentChangeElapsed = 0;

    local step = {
        unchanged = function()
            window.child.monitor.label="unchanged."
            if(poll.rpoll(ifd,0) > 0) then
                local p = ihandle:read()
                print("source was changed.")
                window.child.monitor.label = "just changed!"
                return "changed"
            else
                print("source was not changed.")
                return "unchanged"
            end
        end,
        changed = function()
            --HACK: wait another cycle if an application is still writing to the file.
            if(poll.rpoll(ifd,0) > 0) then
                local p = ihandle:read()
                return "changed"
            else
                --you should probably reload the library and redraw the map at this point.
                return "unchanged"
            end
        end
    }
    --main loop of this coroutine
    while(true) do
        print("next step.")
        state = step[state]()
        coroutine.yield()
    end
end
)
--do a first run on the scanner.
coroutine.resume(fileChangeScanner,ifd)

window:show_all()
--check for filechanges every 300ms
glib.timeout_add(glib.PRIORITY_DEFAULT,300,function()
    coroutine.resume(fileChangeScanner,ifd)
    assert(coroutine.status(fileChangeScanner) ~= "died", "file change scanner died!")
    return glib.SOURCE_CONTINUE
end)

gtk.main()