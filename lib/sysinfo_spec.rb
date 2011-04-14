require 'sysinfo'

describe Sys::ProcessInfo do

  specify "checks OS" do
    proc { Sys.os }.should_not raise_error
    proc { Sys.linux? }.should_not raise_error
    proc { Sys.mac? }.should_not raise_error
    proc { Sys.darwin? }.should_not raise_error

    %w[Linux Windows Darwin].include?(Sys.os).should == true
    
    ( (Sys.linux? and not Sys.mac?) or (Sys.mac? and not Sys.linux?) ).should == true
  end
    
  
  specify "list all processes" do
#    procs = Sys.ps
#
#    procs.first.state.is_a?(Array).should == true
#
#    pids = procs.map{ |process| process.pid }
#
#    p2s = Hash[ *Sys.ps(*pids).map { |process| [process.pid, process] }.flatten ]
#    matches = 0
#    procs.each do |p1|
#      if p2 = p2s[p1.pid]
#        matches += 1
#        p1.command.should == p2.command
#      end
#    end
#
#    matches.should > 1
  end

  
  specify "refresh processes" do

#    STDOUT.sync = true
#
#    procs = Sys.ps
#    procs.shuffle!
#    procs.each do |process|
#      proc do
#        begin
#          process.refresh
#          print "."
#        rescue Sys::ProcessNotFound
#        end
#      end.should_not raise_error
#    end
#
#    puts

  end


  specify "cross-platform method" do
    Sys.interfaces.should_not be_nil
    Sys.cross_platform_method(:cross_platform_test)
    proc{ Sys.cross_platform_test }.should raise_error
  end
  
end
