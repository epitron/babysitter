#!/usr/bin/env ruby

require 'lib/sysinfo'

Sys.trap(:ignore=>"VTALRM") do |signal|
  open("sigs.txt", "a") do |f|
    message = "#{[:signal, signal ].inspect}\n"
    f.write message
    print message
    f.flush
  end rescue nil
end
  
loop { sleep 1 }

#Sys.trap(:ignore=>[]) do |sig|
#  p [:signal, sig]
#end
