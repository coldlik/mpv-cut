mp.msg = require 'mp.msg'
mp.utils = require "mp.utils"
mp.options = require 'mp.options'

MAKE_CUTS_SCRIPT_PATH = mp.utils.join_path(mp.get_script_directory(), "make_cuts")

options = {
	output_dir = ".",
	multi_cut_mode = "separate",
	audio_track_index = 1,
    merge_audio_tracks = false
}

mp.options.read_options(options, "mpv-cut")

cuts = {}
cut_index = 0

function log(...)
	mp.msg.info(...)
	mp.osd_message(...)
end

function cut_render()
    if cuts[cut_key()] == nil or cuts[cut_key()]['end'] == nil then
        log("No cuts to render")
        return
    end
    
    local cuts_json = mp.utils.format_json(cuts)
    local options_json = mp.utils.format_json(options)

    local inpath = mp.get_property("path")
    local filename = mp.get_property("filename")

    local indir = mp.utils.split_path(inpath)

    log("Rendering...")
    print("making cut")

    local args = { "node", MAKE_CUTS_SCRIPT_PATH,
        indir, options_json, filename, cuts_json }

    res, err = mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = args,
    })

    if res and res.status == 0 then
        log("Rendered cuts")
    else
        log("Failed to render cuts")
    end
end

function cut_key()
	return tostring(cut_index)  -- dumb, mp.utils.format_json only accepts string keys
end

function cut_set_start(start_time)
	if cuts[cut_key()] ~= nil and cuts[cut_key()]['end'] then
		cut_index = cut_index + 1
	end

	if cuts[cut_key()] == nil then
		cuts[cut_key()] = {}
	end

	cuts[cut_key()]['start'] = start_time
	log(string.format("[cut %d] Set start time: %.2fs", cut_index + 1, start_time))
end

function cut_set_end(end_time)
	if cuts[cut_key()] == nil then
		log('No start point found')
		return
	end

	cuts[cut_key()]['end'] = end_time
	log(string.format("[cut %d] Set end time: %.2fs", cut_index + 1, end_time))
end

function on_file_change()
	cuts = {}
	cut_index = 0
end

function cycle_audio_tracks()
    local audio_tracks = mp.get_property_native("track-list")
    local num_audio_tracks = 0

    for _, track in ipairs(audio_tracks) do
        if track.type == "audio" then
            num_audio_tracks = num_audio_tracks + 1
        end
    end
    options.audio_track_index = (options.audio_track_index % num_audio_tracks) + 1
    mp.set_property("aid", options.audio_track_index)

    log(string.format("Selected audio track: %d", options.audio_track_index))
end

function toggle_merge_audio_tracks()
    options.merge_audio_tracks = not options.merge_audio_tracks
    log(string.format("Merge audio tracks: %s", options.merge_audio_tracks and "Enabled" or "Disabled"))
end

function toggle_audio_tracks()
    options.toggle_audio_tracks = not options.toggle_audio_tracks

    if options.toggle_audio_tracks then
        mp.set_property('options/lavfi-complex', "[aid1] [aid2] amix [ao]")
    else
        mp.set_property('options/lavfi-complex', "")
        mp.set_property("aid", 1)
    end
end

mp.add_key_binding('g', "cut_set_start", function() cut_set_start(mp.get_property_number("time-pos")) end)
mp.add_key_binding('h', "cut_set_end", function() cut_set_end(mp.get_property_number("time-pos")) end)

mp.add_key_binding('G', "cut_set_start_sof", function() cut_set_start(0) end)
mp.add_key_binding('H', "cut_set_end_eof", function() cut_set_end(mp.get_property('duration')) end)

mp.add_key_binding('a', "cycle_audio_tracks", cycle_audio_tracks)
mp.add_key_binding('q', "toggle_audio_tracks", toggle_audio_tracks)
mp.add_key_binding('A', "toggle_merge_audio_tracks", toggle_merge_audio_tracks)

mp.add_key_binding('r', "cut_render", cut_render)

mp.register_event("end-file", on_file_change)

print("mpv-cut loaded")