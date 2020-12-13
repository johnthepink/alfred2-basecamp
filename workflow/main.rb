#!/usr/bin/env ruby
# encoding: utf-8

($LOAD_PATH << File.expand_path("..", __FILE__)).uniq!

require "rubygems" unless defined? Gem # rubygems is only needed in 1.8
require "bundle/bundler/setup"
require "alfred"
require 'httpclient'
require "json"

Alfred.with_friendly_error do |alfred|

  ALFRED = alfred

  # prepend ! in query to refresh
  is_refresh = false
  if ARGV[0].start_with? '!'
    is_refresh = true
    ARGV[0] = ARGV[0].gsub(/!/, '')
  end

  # contants
  QUERY = ARGV[0]
  BASECAMP_TOKEN = ARGV[1]
  BASECAMP2_COMPANY_IDS = ARGV[2].split(",")
  BASECAMP3_COMPANY_IDS = ARGV[3].split(",")

  def get_uri(api, company_id)
    if api == 2
      "https://basecamp.com/#{company_id}/api/v1/projects.json"
    else
      "https://3.basecampapi.com/#{company_id}/projects.json"
    end
  end

  def get_project_json(api, company_id)
    client = HTTPClient.new
    client = HTTPClient.new default_header: {"User-Agent" => "alfred2-basecamp (john.pinkerton@me.com)"}
    client = HTTPClient.new default_header: {"Authorization" => "Bearer #{BASECAMP_TOKEN}"}

    uri = get_uri(api, company_id)
    parsed = []

    loop do
      res = client.request 'GET', uri
      parsed += JSON.parse(res.body)

      # https://github.com/basecamp/bc3-api/blob/master/README.md#pagination
      link_header = res.header['Link'][0]
      break if (link_header.nil? || link_header.empty?)
      end_index = link_header.index('>');
      uri = link_header[1..end_index]
    end

    begin
      throw_token_error if parsed["error"]
    rescue
      parsed
    end
  end

  def load_projects
    fb = ALFRED.feedback

    b2_projects = BASECAMP2_COMPANY_IDS.map{ |company|
      get_project_json(2, company)
    }

    b3_projects = BASECAMP3_COMPANY_IDS.map{ |company|
      get_project_json(3, company)
    }

    projects_collection = b2_projects + b3_projects

    projects_collection.each do |projects|
      projects.each do |project|
        url = project["app_url"] || project["url"]
        url.sub!("basecampapi", "basecamp") if url.include?("basecampapi")
        fb.add_item({
          :uid => project["id"],
          :title => project["name"],
          :subtitle => url,
          :arg => url,
          :autocomplete => project["name"],
          :valid => "yes"
        })
      end
    end

    fb
  end

  def throw_token_error
    fb = ALFRED.feedback

    if BASECAMP_TOKEN != ""
      title = "You need a new token"
    else
      title = "You need a token"
    end

    fb.add_item({
      :uid => "gettoken",
      :title => title,
      :subtitle => "Press enter and follow the instructions",
      :arg => "https://alfred2-basecamp-auth.herokuapp.com"
    })

    puts "<?xml version=\"1.0\"?>" + fb.to_alfred
    exit
  end

  throw_token_error if BASECAMP_TOKEN == ""

  ALFRED.with_rescue_feedback = true
  ALFRED.with_cached_feedback do
    use_cache_file :expire => 86400
  end

  if !is_refresh and fb = ALFRED.feedback.get_cached_feedback
    # cached feedback is valid
    puts "<?xml version=\"1.0\"?>" + fb.to_alfred(ARGV[0])
  else
    fb = load_projects
    fb.put_cached_feedback
    puts "<?xml version=\"1.0\"?>" + fb.to_alfred(ARGV[0])
  end
end
