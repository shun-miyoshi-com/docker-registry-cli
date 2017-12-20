require 'net/http'
require 'uri'
require 'json'
require './cmdline-option-parser'

# APIs
# https://github.com/docker/distribution/blob/master/docs/spec/api.md
#
# Method URL                            FunctionName
# GET    /v2/<image>/tags/list          getAllTags
# GET    /v2/<image>/manifests/<tag>    getDigest
# DELETE /v2/<image>/manifests/<digest> deleteImage
# GET    /v2/_catalog                   getImages

def getAllTag(url, image)
  u = URI.parse(url+"/v2/"+image+"/tags/list")

  req = Net::HTTP::Get.new(u.path)
  res = Net::HTTP.start(u.host, u.port) do |http|
    http.request(req)
  end

  return JSON.parse(res.body)
end

def getDigest(url, image, tag)
  u = URI.parse(url+"/v2/"+image+"/manifests/"+tag)

  req = Net::HTTP::Get.new(u.path)
  req["Accept"]="application/vnd.docker.distribution.manifest.v2+json"
  res = Net::HTTP.start(u.host, u.port) do |http|
    http.request(req)
  end

  return res.header['Docker-Content-Digest']
end

def getAllImage(url)
  u = URI.parse(url+"/v2/_catalog")

  req = Net::HTTP::Get.new(u.path)
  res = Net::HTTP.start(u.host, u.port) do |http|
    http.request(req)
  end

  return JSON.parse(res.body)
end

def deleteTag(url, image, digest)
  u = URI.parse(url+"/v2/"+image+"/manifests/"+digest)

  req = Net::HTTP::Delete.new(u.path)
  res = Net::HTTP.start(u.host, u.port) do |http|
    http.request(req)
  end
end

# Main Process
val=OptionParser(ARGV)
if val[:err] then
  $stderr.puts val[:err]
  exit 1
else
  url=val[:option][:url]
  image=val[:option][:image]

  case val[:command]
  when "getImages" then
    images=getAllImage(url)
    images["repositories"].each do |i|
      puts i
    end
  when "getTags" then
    if !image then
      $stderr.puts "This command requires --image option"
      exit 1
    end
    tags=getAllTag(url,image)
    if !tags.has_key?("tags") then
      $stderr.puts "There is no tags in --image="+image
      exit 1
    end
    tags["tags"].each do |t|
      puts t
    end
  when "delete" then
    if !image then
      $stderr.puts "This command requires --image option"
      exit 1
    end
    tags=Array.new
    if val[:option][:tags] then
      tags=val[:option][:tags]
    else
      ts=getAllTag(url,image)
      if !ts.has_key?("tags") then
        $stderr.puts "There is no tags in --image="+image
        exit 1
      else
        tags=ts["tags"]
      end
    end
    tags.each do |tag|
      digest=getDigest(url,image,tag)
      if !digest then
        $stderr.puts image+"has no such tag ("+tag+")"
        exit 1
      end
      deleteTag(url,image,digest)
    end
  end
end

