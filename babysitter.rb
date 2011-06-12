#!/usr/bin/env ruby

#-----------------------------------------------------
# Set the path...
__DIR__ = File.expand_path(File.dirname(__FILE__))
$:.unshift __DIR__   # add location of this file to the path
$stdout.sync = true  # flush every line
#-----------------------------------------------------

require 'rubygems'

#-----------------------------------------------------

puts "* Loading modules..."

begin
  
  gem "file-tail"

  %w[
    child
    webserver
    lib/sysinfo
    lib/osc-ruby
    pp
    optparse
    fileutils
  ].each do |mod|
    puts "  |_ #{mod}"
    require mod
  end

rescue Exception => e
  
  puts "Error: #{e}"
  puts "(try 'sudo gem install <module>' to install this module)"
  exit 1
  
end

puts

#-----------------------------------------------------

class Exception
  def display
    puts "Exception: #{inspect}"
    puts backtrace.join("\n")
    puts
  end
end

#-----------------------------------------------------

class Babysitter

  attr_accessor :root, :children, :verbose, :paths, :hostname
  
  #
  # Root specifies the dir containing process dirs.
  # Paths is an optional list of specific dirs to run, instead of running
  # all the dirs inside root.
  #

  def initialize(root, options)
    @root       = File.expand_path(root)
    @paths      = runnable_paths(options[:run_dirs] || Dir[File.join @root, "*"])
    @verbose    = options[:verbose]
    @output     = options[:output]

    problem "No runnable directories found in launch path." if @paths.empty?

    # get the hostname
    @hostname = `uname -n`
    
    # instantiate children
    @children = @paths.map { |path| Child.new(self, path) }

    # create lookup table
    @children_by_name = {}
    @children.each { |child| @children_by_name[child.name] = child }
  end

  def runnable_paths(paths)
    paths.select do |path|
      File.exists?( File.join path, "run" ) 
    end
  end

  def run
    EM.run do
      EM.error_handler { |e| e.display }

      puts "* Launching children..."

      children.each do |child|
        if child.autostart and not child.multiplexed
          puts "Launching: #{child.path}"
          child.start
        else
          puts "SKIPPING: #{child.path}"
        end
      end

      puts
      
      # Check if children have timed out
      EM.add_periodic_timer(5) do
        children.each { |child| child.check_timeout }
      end
    end
  end
  
  def shutdown
    puts "Stopping children..."
    
    children.each do |child|
      child.stop(true)
    end
    
    tries = 0
    EM.add_periodic_timer(1) do
      alive = children.select { |child| child.state != :stopped }
      if alive.empty?
        puts "All children dead! Exiting..."
        exit
      else
        tries += 1
      end
      
      if tries > 10
        puts "Done waiting for children to die. Exiting."
        exit
      end
        
    end
  end

  def multiplexed_children
    @children.select { |child| child.multiplexed }
  end
  
  def [](name)
    @children_by_name[name]
  end
  
end


def problem(message)
  puts "* Error: #{message}"
  puts
  puts "(Use -h or --help for usage instructions)"
  puts
  exit 1
end


USAGE = %{
Usage: babysitter [options] <launch dir>

Where <launch dir> is a directory that contains a set of "process directories", one per
process to launch.

Each of these process directories must contain an executable in it called "run" that
launches the process.

If the process forks into the background, it must contain a "run_background" script that
launches the process and creates a "current.pid" file in that directory before it
terminates.
}


def parse_args

  options = {
    :master       => "localhost:4444",
    :web          => true,
    :output       => STDOUT,
  }
  
  option_parser = OptionParser.new do |opts|
    opts.banner = USAGE   # displays everything after __END__, below...

    opts.on("-p", "--port=PORT", Integer, "Listen to OSC messages on a specified port (default: #{options[:listen_port]}") do |value|
      options[:listen_port] = value
    end

    opts.on("-m", "--master=host:port", "Connect to the master server at host:port (default: #{options[:master]}") do |value|
      options[:master] = value
    end

    opts.on("-r", "--run=dir1,dir2,dir3", Array, "Run only these processes (which are dirs inside the launch dir)") do |value|
      options[:run_dirs] = value
    end

    opts.on("-v", "--[no-]verbose", "Run verbosely") do |value|
      options[:verbose] = value
    end

    opts.on("-n", "--no-webserver", "(Don't) launch web server") do |value|
      options[:web] = value
    end

    opts.on("-w", "--web-browser", "Load server in web browser") do |value|
      options[:browser] = value
    end

    opts.on("-t", "--[no-]test", "Run in test mode (use test.conf and log to the console)") do |value|
      options[:test_mode] = value
    end
    
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      puts
      exit
    end

    opts.on_tail("--version", "Show version") do
      puts OptionParser::Version.join('.')
      exit
    end
  end
  
  begin 
    option_parser.parse!
  rescue OptionParser::MissingArgument => e
    problem "#{e}"
  end

  if options[:verbose]
    puts "="*30
    puts "Options:"
    puts "-"*30
    pp options
    puts
  end
  
  [options, ARGV]
end


def make_babysitter_go_now
  options, args = parse_args
    
  if args.size == 1
    launch_dir = args.first
    unless File.directory? launch_dir 
      problem "Supplied launch dir (#{launch_dir.inspect}) does not exist "
    end
  else
    problem "Must specify launch dir."
  end

  options[:verbose] = true if not options[:web]

  babysitter = Babysitter.new(launch_dir, options)

  if options[:web]
    Thread.new { WebServer.run! :host =>'0.0.0.0', :port=>4567, :environment=>:development, :babysitter=>babysitter }
  end

  Sys.trap("HUP", "INT", "QUIT", "TERM") do
    babysitter.shutdown
  end

  Thread.new{ babysitter.run }
  
  loop { sleep 10 }
end


if $0 == __FILE__
  make_babysitter_go_now
end


