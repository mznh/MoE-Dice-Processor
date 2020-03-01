#!/usr/bin/env ruby
# coding:utf-8
require "bundler/setup"
Bundler.require

require 'date'

set :environment, :production

UPLOAD_PATH = "./logs/"

helpers  do
  def log_process data, config
    regexp = /([0-9\/ :]+) ([a-zA-Zぁ-んァ-ヶー－]+) はマジックダイス\(0-1000\)を振った！ ([0-9]+) が出た！/
    tmp = data.select{|line|line.include? "マジックダイス"}
        .map{|rec|regexp.match(rec)}.select{|i|!i.nil?}
        .map{|rec|rec.to_a.drop(1)}
    p tmp
    ## 最新のダイス時刻を取得　
    last_time = tmp.map{|rec| DateTime.parse(rec[0].split(/ /)[1]) }.sort.last
    ## 最新ダイス時刻と差が 1 hour 以上のものを削除
    ## うーんリファクタリング候補
    ## DateTimeの-がRationalを返すのでごにょごにょ
    tmp = tmp.select{|rec| (last_time - DateTime.parse(rec[0].split(/ /)[1]))*24*60*60.to_i <= 60*60 }

    if config.fetch(:order,nil) == "asc" then
      return tmp.sort_by{|i|i[2].to_i}
    else 
      return tmp.sort_by{|i|i[2].to_i}.reverse
    end
  end
end

get '/' do
  if params.has_key? "logid" and params["logid"] != "" then
    fname = params["logid"]
    @log = File.open(UPLOAD_PATH+fname,"r:sjis:utf-8").readlines
    @log = log_process @log, params
  else 
    @log = []
  end
  
  tmp = @log.map.with_index(1){|res,idx|
    "#{idx}位>#{res[1]}:#{res[2]}"
  }
  p tmp
  @res_texts = tmp.each_slice(8).to_a.map{|i|i.join(" ")}
  p @res_texts
  haml :index
end

put '/upload' do
  if params[:file]
    p params
    p params[:file][:filename]

    tmp_filename = Digest::MD5.hexdigest(params[:file][:filename]+Time.now.iso8601(10).to_s)
    save_path = UPLOAD_PATH + "#{tmp_filename}"
    File.open(save_path, 'wb') do |f|
      f.write params[:file][:tempfile].read
      @mes = "アップロード成功"
    end
    hashed_filename = Digest::MD5.file(save_path).to_s
    File.rename(save_path, UPLOAD_PATH + hashed_filename )
    p save_path, UPLOAD_PATH + hashed_filename 
  else
    @mes = "アップロード失敗"
  end
  redirect "/?logid=#{hashed_filename}&order=#{params[:order]}"
end
