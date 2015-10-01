#!/usr/bin/env ruby
require 'rexml/document'

if ARGV.size != 2  then
  puts("Usage: #{$0} /path/to/root/pom.xml 'mvn command to use'")
  exit 1
end
puts "This script will remove extra Maven dependencies of #{ARGV[0]} and all it's sub modules."
puts "Dependencies are removed one by one and if the command '#{ARGV[1]}' is successful the dependency is left out."

def get_dependencies(pom)
  array = Array.new
  REXML::Document.new(File.new(pom)).elements.each("project/dependencies/dependency") do | dependency |
    array << dependency.to_s
  end
  array
end

def get_poms_and_dependencies(pom, result)
  dir = File.dirname(pom)
  result[pom] = get_dependencies(pom)
  doc = REXML::Document.new(File.new(pom))
  REXML::XPath.match(doc, "//module").each do | mod |
    get_poms_and_dependencies(dir + "/" +mod.text + "/pom.xml", result)
  end
end

def replace(file, string, with)
  content = IO.read(file);
  File.open(file, 'w') { |f| f.write(content.gsub(string, with)) }
end

def remove_dependency_if_possible(pom, dependency)
  place_holder = "<!-- " + rand().to_s + " -->"
  replace(pom, dependency, place_holder)
  if system("cd #{File.dirname(pom)} && #{ARGV[1]} > /dev/null 2> /dev/null")
    puts "SUCCESS"
    replace(pom, /\n^\s*#{place_holder}\s*$/m, "")
  else
    puts "FAILED"
    replace(pom, place_holder, dependency)
  end
end

class Dep
   def initialize(group, artifact, version, scope, systemPath)
      @group=group
      @artifact=artifact
      @version=version
      @scope=scope
      @systemPath=systemPath
   end
   
   def id
    to_s
   end
   
   def to_s
      "All #{@group}:#{@artifact}:#{@version}:#{@scope}:#{@systemPath}"
   end
   
   def asDep
    result = """<dependency>
    <groupId>#{@group}</groupId>
    <artifactId>#{@artifact}</artifactId>
"""
    
    result << (@version.empty? ? "" : "    <version>#{@version}</version>\n")
    result << (@scope.empty? ? "" : "    <scope>#{@scope}</scope>\n")
    result << (@systemPath.empty? ? "" : "    <systemPath>#{@systemPath}</systemPath>\n")
    result << "</dependency>"
   end
end

all = Array.new
dependencies = get_dependencies(ARGV[0])
dependencies.each do |dependency |
    group = dependency.match(/.*<groupId>(.*)<\/groupId>.*/)[1].strip
    artifact = dependency.match(/.*<artifactId>(.*)<\/artifactId>.*/)[1].strip
    version = begin dependency.match(/.*<version>(.*)<\/version>.*/)[1].strip rescue "" end
    scope = begin dependency.match(/.*<scope>(.*)<\/scope>.*/)[1].strip rescue "" end
    systemPath = begin dependency.match(/.*<systemPath>(.*)<\/systemPath>.*/)[1].strip rescue "" end
    
    dep = Dep.new(group,artifact,version,scope,systemPath)
    all << dep
end

all.sort! { |a,b| a.id <=> b.id }.uniq!
all.each do |one|
    puts one.to_s    
end
all.each do |one|
    puts one.asDep
end
