#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'twitter'
# require 'mastodon'
require 'json'
require 'rest-client'

def change_extension(filename, new_ext)
  File.join(File.dirname(filename),File.basename(filename, File.extname(filename)) + ".#{new_ext}")
end

def parse_textfile(filename)
  File.read(filename).strip.gsub(/<\/?[ib]>/,'')
end

secrets = JSON.parse(File.read('.secrets.json'))
TV_PATH = secrets['sync_path']
# mastodon_client = nil

# if secrets.has_key?('mastodon_instance') && secrets.has_key?('mastodon_access_token')
#   mastodon_client = Mastodon::REST::Client.new(base_url: secrets['mastodon_instance'], bearer_token: secrets['mastodon_access_token'])
# end

begin
  utterances = []
  if File.exist?('tv_sounds-utterances.txt')
    utterances = File.readlines('tv_sounds-utterances.txt').map{|u| u.chomp}.uniq
  end 

  extension = 'txt'
  textfiles = Dir.glob(File.join(TV_PATH, "*.#{extension}"))
  textfiles = textfiles.reject{|s| s.nil?}.select{|s| File.exist?(change_extension(s, 'gif'))}
  $stderr.puts "#{textfiles.length} sounds"
  textfiles_new = textfiles.reject{|t| utterances.include?(parse_textfile(t).split("\n").join(' '))}
  $stderr.puts "#{textfiles_new.length} new sounds"
  textfile = textfiles.sample
  # textfile = (textfiles_new.length > 0) ? textfiles_new.sample : textfiles.sample
  screenshot = change_extension(textfile, 'gif')

  text = parse_textfile(textfile)

  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = secrets['consumer_key']
    config.consumer_secret     = secrets['consumer_secret']
    config.access_token        = secrets['access_token']
    config.access_token_secret = secrets['access_token_secret']
  end

  $stderr.puts "Tweeting: #{text}"
  $stderr.puts "With image: #{screenshot}"
  client.update_with_media(text, File.new(screenshot))

  utterances << text.split("\n").join(' ')
  File.open('tv_sounds-utterances.txt', 'w') do |f|
    f.puts utterances.join("\n")
  end

  if secrets.has_key?['mastodon_access_token'] && secrets.has_key?('mastodon_instance')
    $stderr.puts "Tooting:"
    # $stderr.puts mastodon_client.verify_credentials.inspect
    result = RestClient.post "#{secrets['mastodon_instance']}/api/v1/media", {:file => File.new(screenshot,'rb')}, {:Authorization => "Bearer #{secrets['mastodon_access_token']}"}
    media =  JSON.parse(result.body)
    result = RestClient.post "#{secrets['mastodon_instance']}/api/v1/statuses", {:status => text, :media_ids => [media["id"]], :visibility => "public"}, {:Authorization => "Bearer #{secrets['mastodon_access_token']}"}
    $stderr.puts (JSON.parse(result.body).inspect)
    # media = mastodon_client.upload_media(File.open(screenshot,'rb'))
    # $stderr.puts media.id
    # result = mastodon_client.create_status(text, nil, [media["id"]])
    # $stderr.puts result.inspect
  end

  $stderr.puts "Removing files for #{screenshot} after tweeting #{text}"
  %w{jpg gif txt}.each do |ext|
    cleanup = change_extension(screenshot, ext)
    if File.exist?(cleanup)
      # $stderr.puts "Cleaning: #{cleanup}"
      File.delete(cleanup)
    end
  end
rescue Twitter::Error::Forbidden => e
  $stderr.puts e.inspect
  sleep 1
  $stderr.puts "Retrying..."
  retry
end

$stderr.puts "Done."
