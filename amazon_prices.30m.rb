#!/usr/bin/env ruby

require "nokogiri"
require 'net/http'
require 'yaml'
require 'logger'


LOG = Logger.new("#{Dir.home}/logs/amazon_prices.log", 10, 10024000)


products_name_url = [
  ['G3010', 'https://www.amazon.in/Canon-Pixma-Wireless-Colour-Printer/dp/B07B4KDTHP/'],
  ['G3000', 'https://www.amazon.in/Canon-G3000-Wireless-Colour-Printer/dp/B01H25A1AE/'],
  ['G3012', 'https://www.amazon.in/gp/product/B07B4FZ2KJ/']
] 

def get_price url
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"

  res = Net::HTTP.start(uri.hostname, uri.port,  :use_ssl => true) do |http|
  http.request(req)
  end

  LOG.info "GET: #{res.code} #{url}"
  html = Nokogiri::HTML(res.body)
  price = html.css("#priceblock_ourprice").text().gsub(/[[:space:]]+/, "")
  LOG.info "Price: #{price}"
  price
end

products_name_url.each do |name_url|
  price = get_price name_url[1]
  LOG.info "Name: #{name_url[0]}, Price: #{price}"
  puts "#{name_url[0]}: #{price} | color=#ef5350 ansi=true size=14 font=Hack-Bold" 
  puts "---"
end
