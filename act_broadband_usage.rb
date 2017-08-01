#!/usr/bin/env ruby

require "nokogiri"
require 'net/http'
require 'yaml'
require 'logger'

AUTH_FILE = "#{Dir.home}/.act_broadband.yml"
AUTH_EXPIRY = (2*60*60) # 5.hours
LOG = Logger.new('act_broadband_usage.log', 'weekly')

def get_with_cookie url, cookie
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req['Cookie'] = cookie
  req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"

  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end
  LOG.info "GET: #{res.code}"
  puts "GET: #{res.code}"
  res
end

def post_with_cookie url, data, cookie
  uri = URI(url)
  req = Net::HTTP::Post.new(uri)
  req.set_form_data(data)
  req['Cookie'] = cookie
  req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"

  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end
  LOG.info "POST: #{res.code}"
  puts "POST: #{res.code}"
  res
end

def get_auth_cookie login_url
  cookie, location = get_auth_from_file
  return cookie, location unless cookie.nil?
  get_auth_cookie_from_network login_url
end

def get_auth_from_file
  begin
    return nil unless File.exists?(AUTH_FILE)
    file = File.open(AUTH_FILE)
    data = YAML.load(file)
    return nil if Time.now > data[:time]
    LOG.info "Cookie from file..."
    puts "Cookie from file..." 
    return data[:cookie], data[:location]
  rescue Exception => e
    nil
  end
end

def get_auth_cookie_from_network login_url
  response = get_with_cookie login_url, nil
  cookie = response.get_fields('Set-Cookie').map{|c| c.split('; ')[0] }.join("; ")
  file = File.open(AUTH_FILE, "w")
  YAML.dump({cookie: cookie, location: URI.escape(response['Location']), time: (Time.now + AUTH_EXPIRY)}, file)
  file.close
  LOG.info "Cookie from network..."
  puts "Cookie from network..." 
  return cookie, URI.escape(response['Location'])
end


begin
  retries ||= 0
  cookie, login_url = get_auth_cookie "http://portal.actcorp.in/group/blr/myaccount"
  sleep 2

  get_with_cookie login_url, cookie
  sleep 1
  response3 = get_with_cookie "http://portal.actcorp.in/group/blr/myaccount", cookie
  html = Nokogiri::HTML(response3.body)
  usage_url = html.css("input[name='javax.faces.encodedURL']").map{|a|a.attributes["value"].text}.first

  h = {}
  html.css("form[id='A3220:j_idt35']").css("input[type='hidden']").each{|i| h[i['name']] = i['value'] }

  form_data = h.select{|k,v| !k.nil? }
  extra_params = {"javax.faces.source" => "A3220:j_idt35:j_idt39",
                  "javax.faces.partial.event" => "click",
                  "javax.faces.partial.execute" => "A3220:j_idt35:j_idt39 @component",
                  "javax.faces.partial.render" => "@component",
                  "org.richfaces.ajax.component" => "A3220:j_idt35:j_idt39",
                  "A3220:j_idt35:j_idt39" => "A3220:j_idt35:j_idt39",
                  "rfExt" => "null",
                  "AJAX" => "EVENTS_COUNT:1",
                  "javax.faces.partial.ajax" => "true"}

  response4 = post_with_cookie usage_url, form_data.merge(extra_params), cookie

  html = Nokogiri::HTML(response4.body)

  usage = html.css("table td").select{|t| t.text.include?('Quota')}.first.text

  puts usage
rescue Exception => e
  LOG.error "Error: #{e.inspect}"
  puts e.inspect
  File.delete(AUTH_FILE) if File.exists?(AUTH_FILE)
  sleep 5
  retry if (retries += 1 ) < 10
end
