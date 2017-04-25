#!/usr/bin/env ruby

require 'net/http'
require 'json'

secrets = JSON.parse(File.read('.secrets.json'))

blocked_channels = secrets['blocked_channels']

# hdhomerun device ASDF found at 10.0.1.1
hdhomerun_discover = `hdhomerun_config discover | head -1`
hdhomerun_ip = hdhomerun_discover.split(' ').last

lineup = JSON.parse(Net::HTTP.get(URI("http://#{hdhomerun_ip}/lineup.json")))
lineup_clear = lineup.reject{|c| c['DRM'] == 1}
lineup_hd = lineup_clear.select{|c| c['HD'] == 1}
lineup_selected = lineup.select{|c| c['GuideName'] == 'UNCHD'}
lineup_non_blocked = lineup_clear.reject{|c| blocked_channels.include?(c['GuideName'].gsub(/[^0-9A-Za-z]/, ''))}

$stderr.puts "#{lineup.length} channels"
$stderr.puts "#{lineup_clear.length} non-DRM channels"
$stderr.puts "#{lineup_hd.length} non-DRM HD channels"

channel = nil
if (Time.now.strftime("%Y-%m-%d") == "2016-10-04") && (Time.now.hour >= 21) && (Time.now.hour <= 22) # lock channel for specific date/time
  channel = lineup_selected.sample
else
  channel = lineup_non_blocked.sample
end

filename = "#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}-#{channel['GuideName'].gsub(/[^0-9A-Za-z]/, '')}"

$stderr.puts channel.inspect

`curl -o #{filename}.ts #{channel['URL']}?duration=10`
`ccextractor #{filename}.ts -o "srt/#{filename}.srt"`
`bundle exec ./tv_sounds.rb srt/#{filename}.srt #{filename}.ts`
`ffmpeg -i #{filename}.ts -vf "yadif=0:-1:0" -r 1/4 "#{File.join(secrets['sync_path'],filename)}_%03d.jpg"`

# single frame extraction and manual conversion
# `ffmpeg -i #{filename}.ts -ss 00:00:01 -vf "yadif=0:-1:0" -vframes 1 #{filename}.png`
# `convert #{filename}.png -resize 1280x720 -quality 90 "#{File.join(secrets['sync_path'],filename)}.jpg"`
$stderr.puts `rm -vf #{filename}.png #{filename}.ts`

$stderr.puts filename
