#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'srt'

srtfile = ARGV[0]
mkvfile = ARGV[1]

def burn_sub(line, line_text, mkvfile, position)
  duration = line.end_time - line.start_time
  if (duration >= 3.0)
    duration = 3.0
  end
  duration_str = sprintf('%0.03f',duration).rjust(6, '0') # duration.to_i.to_s.rjust(2, '0')
  File.open('sound.srt','w:UTF-8') do |file|
    file.puts "#{"\ufeff"}1"
    # file.puts line.time_str
    file.puts "00:00:00,000 --> 00:00:#{duration_str.tr('.',',')}"
    file.puts line_text
  end
  puts line_text
  `ffmpeg -ss #{line.time_str.split(' --> ')[0].tr(',','.')} -i "#{mkvfile}" -t 00:00:#{duration_str} -vf subtitles=sound.srt -an sound_burned.mkv`
  if File.exist?('sound_burned.mkv')
    filters = "fps=15,scale=400:-1:flags=lanczos"
    gif_duration = duration_str
    if duration >= 1.5
      gif_duration = '01.500'
    end
    `ffmpeg -v warning -t 00:00:#{gif_duration} -i sound_burned.mkv -vf "#{filters},palettegen" -y /tmp/palette.png`
    `ffmpeg -v warning -t 00:00:#{gif_duration} -i sound_burned.mkv -i /tmp/palette.png -lavfi "#{filters} [x]; [x][1:v] paletteuse" -y "/Users/ryan/Dropbox/Photos/tv_sounds/#{File.basename(mkvfile, '.ts')}_#{position}.gif"`
    avg_time = rand(duration.to_i) # 0 # duration / 2 # (line.start_time + line.end_time) / 2
    `ffmpeg -ss 00:00:#{avg_time.to_i.to_s.rjust(2, '0')} -i sound_burned.mkv -vf "yadif=0:-1:0" -y -f image2 -vcodec mjpeg -vframes 1 "/Users/ryan/Dropbox/Photos/tv_sounds/#{File.basename(mkvfile, '.ts')}_#{position}.jpg"`
    if File.exist?("/Users/ryan/Dropbox/Photos/tv_sounds/#{File.basename(mkvfile, '.ts')}_#{position}.jpg")
      File.open("/Users/ryan/Dropbox/Photos/tv_sounds/#{File.basename(mkvfile, '.ts')}_#{position}.txt",'w') do |file|
        file.puts line_text
      end
    end
  end
  `rm -f sound.srt sound_burned.mkv` #{mkvfile}`
end

sounds = []

subtitles = SRT::File.parse(File.new(srtfile))
subtitles.lines.each do |line|
  line_text = line.text.join("\n")
  $stderr.puts "Checking:\n#{line_text}"
  match = line_text.gsub(/<\/?[ib]>/,'').match(/^[[:space:]]*(-*[[:space:]]*[\[(*][^!.?]+[\])*])[[:space:]]*$/m)
  if match && match.captures.length > 0
    sounds << [line, match.captures.join("\n")]
  end
  # line.text.each do |line_text|
  #  if line_text.gsub(/<\/?[ib]>/,'') =~ /^[[:space:]]*-* *[\[(*][^!.?]+[\])*][[:space:]]*$/
  #    sounds << [line, line_text] 
  #  end
  # end
end

if sounds.length > 0
  sounds.each_with_index do |value, position|
    chosen_line, chosen_text = sounds[position]
    burn_sub(chosen_line, chosen_text, mkvfile, position)
  end
else
  $stderr.puts "No sounds!"
end
# `rm #{mkvfile}`
