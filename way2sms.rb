#!/usr/bin/env ruby

require "nokogiri"
require 'net/http'
require 'yaml'
require 'logger'

module Way2Sms
  CRED_FILE = "#{Dir.home}/.way2sms_creds.yml"
  AUTH_FILE = "#{Dir.home}/.way2sms_auth.yml"
  AUTH_EXPIRY = (5*60)
  LOG = Logger.new('way2sms.log', 10, 10024000)
  
  def self.get_with_cookie url, cookie
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req['Cookie'] = cookie
    req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    LOG.info "GET:#{res.code} #{url}"
    puts "GET: #{res.code}"
    res
  end

  def self.post_with_cookie url, data, cookie
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(data)
    req['Cookie'] = cookie
    req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    LOG.info "POST:#{res.code} #{url}"
    puts "POST: #{res.code}"
    res
  end

  def self.get_auth_cookie login_url
    cookie, token = get_auth_from_file
    return cookie, token unless cookie.nil?
    get_auth_cookie_from_network login_url
  end
  
  def self.get_auth_from_file
    begin
      return nil unless File.exists?(AUTH_FILE)
      file = File.open(AUTH_FILE)
      data = YAML.load(file)
      return nil if Time.now > data[:time]
      LOG.info "Cookie from file..."
      puts "Cookie from file..." 
      return data[:cookie], data[:token]
    rescue Exception => e
      nil
    end
  end

  def self.get_auth_cookie_from_network login_url
    params = YAML.load(File.open(CRED_FILE))
    login_res = post_with_cookie login_url, params, nil
    cookie = login_res.get_fields('Set-Cookie').map{|c| c.split('; ')[0] }.join("; ")
    token = login_res['Location'].match(/Token=(.*?)&/)[1]

    file = File.open(AUTH_FILE, "w")
    YAML.dump({cookie: cookie, token: token, time: (Time.now + AUTH_EXPIRY)}, file)
    file.close
    
    LOG.info "Cookie from network..."
    puts "Cookie from network..." 
    return cookie, token
  end


  def self.send_sms number, message
    cookie, token = get_auth_cookie "http://site24.way2sms.com/Login1.action"

    data = {
      "ssaction" => "ss",
      "Token" => token,
      "mobile" => number,
      "message" => message,
      "msgLen" => 140 - message.length
    }

    resp = post_with_cookie "http://site21.way2sms.com/smstoss.action", data, cookie  
  end 
end

