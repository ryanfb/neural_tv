#!/usr/bin/env ruby

require 'twitter'
require 'json'

secrets = JSON.parse(File.read('.secrets.json'))
TV_PATH = secrets['sync_path']

# delete small files, these are likely blank/corrupt screenshots
$stderr.puts `find #{TV_PATH} -name '*.jpg' -size -10k -print -delete`

$stderr.puts `cd neuraltalk2 && th eval.lua -model model_id1-501-1448236541.t7 -image_folder #{TV_PATH} -num_images -1`

if $?.success?
  $stderr.puts "neuraltalk2 succeeded, tweeting random result"
  $stderr.puts `pwd`

  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = secrets['consumer_key']
    config.consumer_secret     = secrets['consumer_secret']
    config.access_token        = secrets['access_token']
    config.access_token_secret = secrets['access_token_secret']
  end

  utterances = []
  if File.exist?('neuraltv-utterances.txt')
    utterances = File.readlines('neuraltv-utterances.txt').map{|u| u.chomp}
  end

  vis = JSON.parse(File.read('neuraltalk2/vis/vis.json'))
  begin
    selected = nil

    # try to tweet something new first
    new_utterances = vis.reject{|v| utterances.include?(v['caption'])}
    if new_utterances.length > 0
      $stderr.puts new_utterances.map{|v| v['caption']}.join("\n")
      selected = new_utterances.sample
      utterances << selected['caption'].chomp
    else
      selected = vis.sample
    end
    $stderr.puts selected.inspect
    image = "neuraltalk2/vis/imgs/img#{selected['image_id']}.jpg"
    $stderr.puts image

    client.update_with_media(selected['caption'], File.new(image))
  rescue Twitter::Error, Twitter::Error::Forbidden => e
    $stderr.puts e.inspect
    retry
  end

  File.open('neuraltv-utterances.txt', 'w') do |f|
    f.puts utterances.join("\n")
  end

  `rm -v #{TV_PATH}*.jpg`
end
