#!/usr/bin/env ruby

## This script has no dependency besides the standard Ruby library,
## hashes files, grabs the Imdb IDs from opensubtitles.org,
## asks the user for the exact movie in case that's ambiguous,
## and scrobbles them on trakt.tv.
## In ~94 lines of Ruby (counted by cloc).
##
## Actually, it's not. It's a love letter to trakt.tv, asking it kindly to
## extend its API just a bit to accomodate Unix beards like mine.


## Current problems
###################
## - Hard to pick a good action:
##   - checkin/scrobble require a dev key...
##   - an mplayer wrapper would want to checkin, as pinging regularly is hard
##   - a script invoked before removing files I've seen would want to use 'seen'
## - Not easy to use 'seen' because:
##   - Have to distinguish episodes vs movies (not too hard)
##     - http://trakt.tv/api-docs/show-episode-seen
##       I don't have the show Imdb ID, only the episode Imdb ID.
##     - http://trakt.tv/api-docs/movie-seen
##       No issues there.
## - It seems like much to collect an API key, username and password SHA1.
##   Shouldn't API key be enough? Or at least, only API key or password?

## What would be super awesome from trakt.tv?
#############################################
## A much simpler endpoint, like user/seen
## I can pass only a bunch of Imdb IDs or similar, no need to come up with more.
## Obviously other combinations of metadata could be supported, but only Imdb
## IDs would be enough.
## Ideally,
##   - I'd only need to pass the API key through the URI.
##   - I could specify a timestamp, and trakt.tv could guess if I've already watched it,
##     or if I'm watching it.
##
## See the scrobble method in this script for an example usage.

## Why would it be awesome for trakt.tv?
########################################
## It'd be much, much easier for the whole community to support trakt.tv.
## Whether it be scripts like this one, plugins for automated downloaders,
## collection managers, video players, etc.


# TODO:
# - rm mode (only removes files if properly scrobbled)
# - mv mode (only moves files if properly scrobbled)
# - Real command-line parsing, with -h
# - Nicer error reporting
# + Inline "TODO:" comments

require 'json'
require 'net/http'
require 'net/https'
require 'set'
require 'time'
require 'xmlrpc/client'

HASH_CHUNK_SIZE = 65536
UINT64_MAX = 2**64 - 1

def with_OST
  server = XMLRPC::Client.new_from_uri 'http://api.opensubtitles.org/xml-rpc'
  # TODO: grab our own user agent.
  # See http://trac.opensubtitles.org/projects/opensubtitles/wiki/DevReadFirst#Howtorequestanewuseragent
  login = server.call 'LogIn', '', '', 'en', 'OS Test User Agent'
  raise login['status'] unless login['status'] == '200 OK'
  begin
    yield server, login['token']
  ensure
    server.call 'LogOut', login['token']
  end
end

def log msg
  STDERR.puts "#{DateTime.now.rfc3339}: #{msg}"
end

def hashFile(file)
  file.seek(0, IO::SEEK_SET)
  buffer = file.sysread(HASH_CHUNK_SIZE)
  file.seek(-HASH_CHUNK_SIZE, IO::SEEK_END)
  buffer << file.sysread(HASH_CHUNK_SIZE)

  bufsize = buffer.size
  raise "Only read #{bufsize} bytes" if bufsize != 2 * HASH_CHUNK_SIZE

  buffhash = buffer.unpack('Q*').reduce do |acc, v|
    (acc + v) & UINT64_MAX
  end

  return (file.pos + buffhash) & UINT64_MAX
end

def format_OST i
  res = i['MovieName']
  res << " #{i['SeriesSeason']}x#{i['SeriesEpisode']}" if i['SeriesEpisode']
  res << " (#{i['MovieYear']}, IMDB:#{i['MovieImdbID']})"
end

def scan_for_IDs(files)
  md = Hash.new do |h,k|
    h[k] = {:filenames => []}
  end

  files.each do |name|
    hash = File.open(name, 'rb') { |f| '%08x' % hashFile(f) }
    md[hash][:filenames] << name
  end

  res = with_OST do |server, token|
    server.call 'CheckMovieHash2', token, md.keys
  end

  status = res['status']
  raise status unless status == '200 OK'
  
  res['data'].each do |hash, infos|
    md[hash][:ost] = infos
  end

  res = Set.new
  md.each do |h, v|
    ost = v[:ost]
    if ost.nil?
      log "Couldn't find #{v[:filenames].join ', '}"
    elsif ost.length == 1
      res << ost.first
    else
      v[:filenames].each do |f|
        puts "What is #{f}?"
        ost.each_with_index do |infos, i|
          puts "#{i}: #{format_OST infos}"
        end
        res << ost[STDIN.gets.to_i]
      end
    end
  end

  res
end

def scrobble(api_key, records)
  uri = URI.parse "https://api.trakt.tv/user/seen/#{api_key}"
  client = Net::HTTP.new uri.host, uri.port
  client.use_ssl = true
  req = Net::HTTP::Post.new uri.path
  payload = records.collect do |e|
    { :imdb_id => "tt#{e['MovieImdbID']}" }
  end
  req.body = payload.to_json
  log "Would have posted #{req.body}"
  raise NotImplementedError, 'Please help me, trakt.tv'
  rep = client.request req
  raise rep.header unless Net::HTTPSuccess === rep
end

if __FILE__ == $0
  to_scrobble = scan_for_IDs(ARGV)
  api_key = File.read(File.expand_path('~/.trakt_api')).strip
  scrobble api_key, to_scrobble
end
