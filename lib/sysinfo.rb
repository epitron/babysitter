module Sys
  
  #-----------------------------------------------------------------------------

  PS_FIELD_TABLE = [
    [:pid,    :to_i],
    [:pcpu,   :to_f],
    [:pmem,   :to_f],
    [:stat,   :to_s],
    [:rss,    :to_i],
    [:vsz,    :to_i],
    [:user,   :to_s],
    [:majflt, :to_i],
    [:minflt, :to_i],
    [:command,:to_s],
  ]
  
  PS_FIELDS             = PS_FIELD_TABLE.map { |name, func| name }
  PS_FIELD_TRANSFORMS   = Hash[ *PS_FIELD_TABLE.flatten ]
  
  class ProcessNotFound < Exception; end
  
  class ProcessInfo < Struct.new(*PS_FIELDS+[:state])

    DARWIN_STATES = {
      "R"=>:running,
      "S"=>:sleeping,
      "I"=>:idle,
      "T"=>:stopped,
      "U"=>:wait,
      "Z"=>:zombie,
      "W"=>:swapped,
      
      "s"=>:session_leader,
      "X"=>:debugging,
      "E"=>:exiting,
      "<"=>:high_priority,
      "N"=>:low_priority,
      "+"=>:foreground,
      "L"=>:locked_pages,
    }
    
    LINUX_STATES = {
      "R"=>:running,
      "S"=>:sleeping,
      "T"=>:stopped,
      "D"=>:wait,
      "Z"=>:zombie,
      "W"=>:swapped,
      "X"=>:dead,

      "s"=>:session_leader,
      "<"=>:high_priority,
      "N"=>:low_priority,
      "+"=>:foreground,
      "L"=>:locked_pages,
      "l"=>:multithreaded,
    }
    
    def initialize(*args)
      @dead = false
      args << stat_to_state(args[PS_FIELDS.index(:stat)])
      super(*args)
    end
    
    def to_hash
      Hash[ *members.zip(values).flatten(1) ]
    end
    
    def kill!(signal="TERM")
      puts "Killing #{pid} (#{signal})"
      Process.kill(signal, pid)
      # TODO: handle exception Errno::ESRCH (no such process)
    end
    
    def dead?
      @dead ||= Sys.pid(pid).empty?
    end
    
    def refresh
      processes = Sys.ps(pid)
      
      if processes.empty?
        @dead = true
        raise ProcessNotFound
      end
      
      updated_process = processes.first
      members.each { |member| self[member] = updated_process[member] }
      self
    end

    private 
    
    def stat_to_state(str)
      states = case Sys.os
        when "Linux"  then LINUX_STATES
        when "Darwin" then DARWIN_STATES
        else raise "Unsupported platform: #{Sys.os}"
      end
      
      str.scan(/./).map { |char| states[char] }.compact
    end
    
  end

  #-----------------------------------------------------------------------------
  
  def self.ps(*pids)
    options = PS_FIELDS.join(',')
    
    if pids.any?
      command = "ps -p #{pids.join(',')} -o #{options}"
    else
      command = "ps ax -o #{options}"
    end

    lines = `#{command}`.to_a        

    lines[1..-1].map do |line|
      fields = line.split
      if fields.size > PS_FIELDS.size
        fields = fields[0..PS_FIELDS.size-2] + [fields[PS_FIELDS.size-1..-1].join(" ")] 
      end
      
      fields = PS_FIELDS.zip(fields).map { |name, value| value.send(PS_FIELD_TRANSFORMS[name]) }
      
      ProcessInfo.new(*fields)
    end
  end
  
  #-----------------------------------------------------------------------------

  def self.os
    return @os if @os

    require 'rbconfig'
    host_os = Config::CONFIG['host_os']
    case host_os
      when /darwin/
        @os = "Darwin"
      when /linux/
        @os = "Linux"
      when /mingw|mswin/
        @os = 'Windows'
    else
      raise "Unknown OS: #{host_os.inspect}"
    end

    @os
  end
  
  def self.linux?
    os == "Linux"
  end

  def self.darwin?
    os == "Darwin"
  end
  
  def self.mac?; darwin?; end
  
  #-----------------------------------------------------------------------------

  #
  # Trap signals!
  #
  # usage: trap("EXIT", "HUP", "ETC", :ignore=>["VTALRM"]) { |signal| puts "Got #{signal}!" }
  # (Execute Signal.list to see what's available.)
  #
  # No paramters defaults to all signals except VTALRM, CHLD, CLD, and EXIT.
  #  
  def self.trap(*args, &block)
    options = if args.last.is_a?(Hash) then args.pop else Hash.new end
    args = [args].flatten
    signals = if args.any? then args else Signal.list.keys end

    ignore = %w[ VTALRM CHLD CLD EXIT ] unless ignore = options[:ignore]
    ignore = [ignore] unless ignore.is_a? Array

    signals = signals - ignore

    signals.each do |signal|
      p [:sig, signal]
      Signal.trap(signal) { yield signal }
    end
  end
  
  #-----------------------------------------------------------------------------

  def self.metaclass
    class << self
      self
    end
  end

  def self.cross_platform_method(name)
    platform_method_name = "#{name}_#{os.downcase}"
    metaclass.instance_eval do
      define_method(name) do |*args|
        begin
          self.send(platform_method_name, *args)
        rescue NoMethodError
          raise NotImplementedError.new("#{name} is not yet supported on this platform.")
        end
      end
    end
  end

  #-----------------------------------------------------------------------------

  cross_platform_method :interfaces

  def self.interfaces_darwin
    sections = `ifconfig`.split(/^(?=[^\t])/)
    sections_with_relevant_ip = sections.select {|i| i =~ /inet/ }

    device_ips = {}
    sections_with_relevant_ip.each do |section|
      device  = section[/[^:]+/]
      ip      = section[/inet ([^ ]+)/, 1]
      device_ips[device] = ip
    end

    device_ips
  end

  def self.interfaces_linux
    sections = `ifconfig`.split(/^(?=Link encap:Ethernet)/)
    sections_with_relevant_ip = sections.select {|i| i =~ /inet/ }

    device_ips = {}
    sections_with_relevant_ip.each do |section|
      device  = section[/([\w\d]+)\s+Link encap:Ethernet/, 1]
      ip      = section[/inet addr:([^\s]+)/, 1]
      device_ips[device] = ip
    end

    device_ips
  end
  
  #-----------------------------------------------------------------------------

  cross_platform_method :browser

  def browser_linux(url)
    system("gnome-open", url)
  end

  def browser_darwin(url)
    system("open", "-a", "chrome", url)
  end

  #-----------------------------------------------------------------------------

  cross_platform_method :memstat

  def self.memstat_linux
    #$ free
    #             total       used       free     shared    buffers     cached
    #Mem:       4124380    3388548     735832          0     561888     968004
    #-/+ buffers/cache:    1858656    2265724
    #Swap:      2104504     166724    1937780
    
    #$ vmstat    
  end
  
  def self.memstat_darwin
    #$ vm_stat
    #Mach Virtual Memory Statistics: (page size of 4096 bytes)
    #Pages free:                         198367.
    #Pages active:                       109319.
    #Pages inactive:                      61946.
    #Pages speculative:                   18674.
    #Pages wired down:                    70207.
    #"Translation faults":            158788687.
    #Pages copy-on-write:              17206973.
    #Pages zero filled:                54584525.
    #Pages reactivated:                    8768.
    #Pageins:                            176076.
    #Pageouts:                             3757.
    #Object cache: 16 hits of 255782 lookups (0% hit rate)

    #$ iostat
  end

  def self.temperatures
    
    #/Applications/Utilities/TemperatureMonitor.app/Contents/MacOS/tempmonitor -a -l
    #CPU Core 1: 28 C
    #CPU Core 2: 28 C
    #SMART Disk Hitachi HTS543216L9SA02 (090831FBE200VCGH3D5F): 40 C
    #SMC CPU A DIODE: 41 C
    #SMC CPU A HEAT SINK: 42 C
    #SMC DRIVE BAY 1: 41 C
    #SMC NORTHBRIDGE POS 1: 46 C
    #SMC WLAN CARD: 45 C
    
  end

end  

class Array
#  if respond_to?
  def sum
    inject(0){|sum,e| sum + e}
  end
end

if $0 == __FILE__
  require 'pp'
  procs = Sys.ps
  p [:processes, procs.size]
#  some = procs[0..3]
#  some.each{|ps| pp ps}
#  some.first.kill!
#  pp some.first.to_hash
#  p [:total_cpu, procs.map{|ps| ps.pcpu}.sum]
#  p [:total_mem, procs.map{|ps| ps.pmem}.sum]

  pp Sys.interfaces
end
