#!/usr/bin/env ruby
# encoding: utf-8

($LOAD_PATH << File.expand_path("..", __FILE__)).uniq!

require 'rubygems' unless defined? Gem # rubygems is only needed in 1.8
require "bundle/bundler/setup"
require "alfred"
require "net/http"
require "json"

Alfred.with_friendly_error do |alfred|

  # prepend ! in query to refresh
  is_refresh = false
  if ARGV[0].start_with? '!'
    is_refresh = true
    ARGV[0] = ARGV[0].gsub(/!/, '')
  end

  # contants
  QUERY = ARGV[0]
  BASECAMP_USERNAME = ARGV[1]
  BASECAMP_PASSWORD = ARGV[2]
  BASECAMP_EMAIL = ARGV[3]
  BASECAMP_COMPANY_IDS = ARGV[4].split(",")

  def get_project_json(company_id)
    # setup URI
    uri = URI("https://basecamp.com/#{company_id}/api/v1/projects.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    # setup request
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(BASECAMP_USERNAME, BASECAMP_PASSWORD)
    request["User-Agent"] = "Alfred App (#{BASECAMP_EMAIL})"

    # make request
    response = http.request(request)
    JSON.parse(response.body)
  end

  def load_projects(alfred)
    fb = alfred.feedback
    projects_collection = BASECAMP_COMPANY_IDS.map{ |company| get_project_json(company) }

    projects_collection.each do |projects|
      projects.each do |project|
        fb.add_item({
          :uid => project["id"],
          :title => project["name"],
          :subtitle => project["app_url"],
          :arg => project["app_url"],
          :autocomplete => project["name"],
          :valid => "yes"
        })
      end
    end

    fb
  end

  alfred.with_rescue_feedback = true
  alfred.with_cached_feedback do
    use_cache_file :expire => 3600
  end

  if !is_refresh and fb = alfred.feedback.get_cached_feedback
    # cached feedback is valid
    puts fb.to_alfred(ARGV[0])
  else
    fb = load_projects(alfred)
    fb.put_cached_feedback
    puts fb.to_alfred(ARGV[0])
  end
end



