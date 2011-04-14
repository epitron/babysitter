#!/usr/bin/env ruby
$stdout.sync = true
loop { $stdout.write("OUT!!\n"); $stderr.write("ERR!!\n"); sleep 1; puts "THUMP" }
