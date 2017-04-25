#!/usr/bin/env ruby

require 'twitter'
require 'json'
require 'rest-client'

def degender(input)
  output = input
  output.gsub!(/\b(a man and woman|a woman and man|a man and a woman|a woman and a man)\b/,'two people')
  output.gsub!(/\bof \b(her|him|herself|himself)$/,'of themself')
  output.gsub!(/\bof \b(her|him)\b/,'of their')
  output.gsub!(/\blittle \b(boy|girl)\b/,'child')
  output.gsub!(/\b(man|woman|boy|girl)\b/,'person')
  output.gsub!(/\b(men|women|boys|girls)\b/,'people')
  output.gsub!(/\b(his|her)\b/,'their')
  output.gsub!(/\b(himself|herself)\b/,'themself')
  return output
end

secrets = JSON.parse(File.read('.secrets.json'))
TV_PATH = secrets['sync_path']
IMAGE_BOTS = %w{pixelsorter imgblur imgshredder imgblender lowpolybot a_quilt_bot ArtyMash ArtyCurve ArtyNegative ArtyAbstract ArtyCrush ArtyWinds ArtyPolar IMG2ASCII acidblotbot kaleid_o_bot CommonsBot imgbotrays baldesorry tinyimagebot imgavgbot ClipArtBot _emo_ji}

# delete old files, so we don't overwhelm neuraltalk2
$stderr.puts `find #{TV_PATH} -type f -mmin +10 -print -delete`
$stderr.puts `rm -rfv #{TV_PATH}/vis`

# delete small files, these are likely blank/corrupt screenshots
$stderr.puts `find #{TV_PATH} -name '*.jpg' -size -10k -print -delete`

# $stderr.puts `cd neuraltalk2 && th eval.lua -model model_id1-501-1448236541.t7 -image_folder #{TV_PATH} -num_images -1`

$stderr.puts `gtimeout -k 16m 15m docker run -i -v #{TV_PATH}:/data/images -v #{File.expand_path(File.dirname(__FILE__))}/model:/data/model ryanfb/neuraltv-neuraltalk2:latest`

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

  vis = JSON.parse(File.read("#{TV_PATH}/vis/vis.json"))
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
    image = "#{TV_PATH}/vis/imgs/img#{selected['image_id']}.jpg"
    $stderr.puts image

    bot_mention = ''
    if rand(0..9) <= 0
      bot_mention = " /cc @#{IMAGE_BOTS.sample}"
    end

    tweet_text = degender(selected['caption']) + bot_mention
    $stderr.puts "Tweeting: #{tweet_text}"
    client.update_with_media(tweet_text, File.new(image))

    if secrets.has_key?('mastodon_access_token') && secrets.has_key?('mastodon_instance') && (rand.round == 0)
      $stderr.puts "Tooting:"
      result = RestClient.post "#{secrets['mastodon_instance']}/api/v1/media", {:file => File.new(image,'rb')}, {:Authorization => "Bearer #{secrets['mastodon_access_token']}"}
      media =  JSON.parse(result.body)
      result = RestClient.post "#{secrets['mastodon_instance']}/api/v1/statuses", {:status => degender(selected['caption']), :sensitive => "true", :media_ids => [media["id"]], :visibility => "public"}, {:Authorization => "Bearer #{secrets['mastodon_access_token']}"}
      $stderr.puts (JSON.parse(result.body).inspect)
    end
  rescue Twitter::Error, Twitter::Error::Forbidden => e
    $stderr.puts e.inspect
    retry
  end

  File.open('neuraltv-utterances.txt', 'w') do |f|
    f.puts utterances.join("\n")
  end

  $stderr.puts `rm -rv #{TV_PATH}/vis`
  $stderr.puts `rm -v #{TV_PATH}*.jpg`
end
$stderr.puts "neuraltv.rb finished!"
