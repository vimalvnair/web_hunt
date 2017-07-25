#!/usr/bin/env ruby

require "nokogiri"
require 'net/http'
require 'yaml'

AUTH_FILE = "#{Dir.home}/.idea_cellular_auth.yml"

#YAML dump => {:mobileNumber: '8112176543', :password: 'pass'}
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
  cookie
end

def get_main_balance_html cookie
  res = get_with_cookie('https://care.ideacellular.com/wps/myportal/prepaid/dedicated-account', cookie)
  html = Nokogiri::HTML(res.body)
end

def get_all_balance cookie
  html = get_main_balance_html cookie
  h = {}
  current_key = nil
  html.css("div.plan table.table_small tr").each do |tr|
    tds = tr.css("td")
    if( tds.count == 1)
      current_key = tds.first.text.strip
      h[current_key] = []
    end
    if (tds.count == 4)
      tds.each{ |td| h[current_key] << td.text.strip }
    end
  end
  h
end

def get_data_balance all_hash
  all_hash['Data'][2]
end

def get_data_expiry all_hash
  all_hash['Data'][3]
end

def get_main_balance all_hash
  all_hash['Balance'][2]
end

begin
  retries ||= 0
  login_url = get_login_url
  cookie = get_auth_cookie login_url

  all_balance_hash  = get_all_balance cookie

  puts "\e[34m#{get_data_balance(all_balance_hash)}\e[0m / \e[35m#{get_main_balance(all_balance_hash)}\e[0m | ansi=true size=12"  
  puts "---"
  puts "Data Expiry: #{get_data_expiry all_balance_hash}"
rescue Exception => e
  puts "Error"
  File.delete(AUTH_FILE) if File.exists?(AUTH_FILE)
  sleep 5
  retry if (retries += 1 ) < 3
end
