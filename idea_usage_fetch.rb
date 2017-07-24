#!/usr/bin/env ruby

require "nokogiri"
require 'net/http'
require 'yaml'

AUTH_FILE = "#{Dir.home}/.idea_cellular_auth.yml"
CRED_FILE = "#{Dir.home}/.idea_creds.yml"
AUTH_EXPIRY = (5*60*60) # 5.hours

def get_with_cookie url, cookie
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req['Cookie'] = cookie
  req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"
  
  res = Net::HTTP.start(uri.hostname, uri.port,  :use_ssl => true) do |http|
    http.request(req)
  end
  puts "GET: #{res.code}"
  res
end

def post_with_cookie url, data, cookie
  uri = URI(url)
  req = Net::HTTP::Post.new(uri)
  req.set_form_data(data)
  req['Cookie'] = cookie
  req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"

  res = Net::HTTP.start(uri.hostname, uri.port,  :use_ssl => true) do |http|
    http.request(req)
  end
  puts "POST: #{res.code}"
  res
end

def get_login_url
  host = "https://care.ideacellular.com"
  response = get_with_cookie "https://care.ideacellular.com/wps/portal/account/account-login", nil
  html = Nokogiri::HTML(response.body)
  scr = html.css("script")
  res_script_text = scr.select{|b| b.text.include?("LoginAction") }.first.text
  path = res_script_text.match(/action=(.*?);/)[1]

  login_url = host + path.tr("'", "")
end

def get_auth_cookie login_url
  cookie = get_auth_from_file
  return cookie unless cookie.nil?
  get_auth_cookie_from_network login_url
end

def get_auth_from_file
  begin
    return nil unless File.exists?(AUTH_FILE)
    file = File.open(AUTH_FILE)
    data = YAML.load(file)
    return nil if Time.now > data[:time]
    puts "Cookie from file..." 
    data[:cookie]
  rescue Exception => e
    nil
  end
end

def get_auth_cookie_from_network login_url
  params = YAML.load(File.open(CRED_FILE))
  login_res = post_with_cookie login_url, params, nil
  cookie = login_res.get_fields('Set-Cookie').map{|c| c.gsub("Path=/;", "").gsub("HttpOnly", "").gsub(";", "").strip}.join('; ')  
  file = File.open(AUTH_FILE, "w")
  YAML.dump({cookie: cookie, time: (Time.now + AUTH_EXPIRY)}, file)
  puts "Cookie from network..." 
  cookie
end

def get_data_balance_html cookie
  data_view_res = get_with_cookie('https://care.ideacellular.com/wps/myportal/prepaid/databalance-view', cookie)
  data_view_html = Nokogiri::HTML(data_view_res.body)
end

def get_remaining_balance html
  html.css("div.plan table tr")[2].css("td")[2].text.strip
end

def get_expiry_date html
  html.css("div.plan table tr")[2].css("td")[3].text.strip
end

begin
  login_url = get_login_url
  cookie = get_auth_cookie login_url
  data_balance_html = get_data_balance_html cookie
  puts get_remaining_balance(data_balance_html), get_expiry_date(data_balance_html)
rescue Exception => e
  File.delete(AUTH_FILE) if File.exists?(AUTH_FILE)
  sleep 10
  retry
end


