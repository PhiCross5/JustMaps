--DIRTY HACK: MANUALLY SET PATHS FOR MODULES AND C LIBRARIES
--I'm only doing this because zerobrane won't find my packages.
package.path = [[./?.lua;/usr/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua]]
package.cpath = [[./?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so
]]

local xml = require("xmlua")
local osm = {}

local math = require("math")
local lgi = require("lgi")
local cairo = lgi.cairo

--prepare GUI window

--parse xml
function parse_xml(fname)
    local osm = {}
    osm["raw"] = io.open(fname,"r")
    osm["decoded"] = xml.XML.parse(osm["raw"]:read("*a"))

    --This is the map data object.
    --  map data is simply a copy of the OSM XML
    --  mapped to lua table semantics.
    local biri = {
        nodes = {};
        ways = {};
        relations = {}
    }

    --print(osm["decoded"]:search("/osm/node"):to_xml())
    --get all nodes (points in cartesian lat-lon coordinates)
    for k,v in ipairs(osm["decoded"]:search("/osm/node")) do
        biri.nodes[v["id"]] ={
            ["lat"] = v["lat"];
            ["lon"] = v["lon"]
        }
    end

    --fetch ways (paths of nodes)
    for i,v in pairs(osm["decoded"]:search("/osm/way")) do

        --template way Entry structure
        local wayEntry =
        {
            ["nodes"] = {};
            ["tags"] = {}
        }

        --fill each way with its nodes
        for m, n in pairs(
            osm["decoded"]:search(
                string.format("/osm/way[@id=%s]/nd", v["id"])))
        do
            --print("inserting node", n["ref"], "at wayEntry", v["id"])
            table.insert(wayEntry["nodes"], n["ref"])
        end

        --fill each way with its tags
        for m, n in pairs(
            osm["decoded"]:search(
                string.format("/osm/way[@id=%s]/tag", v["id"])))
        do
            --print("inserting tag", n["k"], "=", n["v"], "at wayEntry", v["id"])
            wayEntry["tags"][n["k"]] = n["v"]
            --print(wayEntry["tags"]["highway"])
        end

        --on each way, append it to the ways table with its id as an index
        biri["ways"][v["id"]] = wayEntry
    end
    return biri
end

local daMap = parse_xml("osm.xml")

chosen_way = daMap.ways["129833256"]
--[[
for k,v in pairs(daMap.ways) do
    print(v["id"])
end
]]

print(string.format("a certain path of this map goes through:\n"))
for k,v in pairs(chosen_way.nodes) do
    print(string.format("point %d:\t\t(%2.4f,%2.4f)", k, daMap.nodes[v].lat, daMap.nodes[v].lon))
end
--print(biri:search("/osm/node"):to_xml())

--(DISCLAIMER : UNSTABLE API)
--As of this comment, *data* is a table containing  a *nodes* array with ref-indexed {latitude, longitude} pairs and a *ways* array with ref-indexed {node_reference, type} pairs.
function draw_map(config, data)
    for k,v in ipairs(data.ways) do
        draw_line(data.nodes,v)
    end
end
