require 'rubygems'
require 'eventmachine'
require 'simple_logger'
require 'file/tail'
require 'yaml'

class ChildConnection < EM::Connection

  LOGDIR = "log"

  attr_accessor :child

  def initialize(child)
    @child = child
  end

  #
  # Called when the child dies
  #
  def unbind
    child.on_exit
  end

  #
  # Called after the connection is created
  #
  def post_init
    child.on_start
  end

  #
  # Called when data is received from STDOUT
  #
  def receive_data data
    data.each { |line| receive_line line }
  end

  #
  # Called for each line of the data
  #
  def receive_line line
    child.on_output line
  end

end


class Child

  HEARTBEAT_RE = /\b(THUMP|heartbeat|don't kill me)\b/i
  
  DEATHS = [
    "swallowed a roll of pennies",
    "ate some rat-poison-O's",
    "fell off a cliff",
    "ran with scissors",
    "licked a plug socket",
    "tried to grab the cat's tail",
    "blowed himself up",
    "got flushed",
  ]

  #####################################
  # init
  #####################################

  attr_accessor :path, :logfile, :babysitter, :state, :crashes, :runconf, :autostart, :multiplexed

  def initialize(babysitter, path, options={})
    @babysitter     = babysitter
    @path           = path
    @conn           = nil

    # output
    @output         = options[:output]        || STDOUT
    @crash_limit    = options[:crash_limit]   || 4
    @restart_delay  = options[:restart_delay] || 2
    
    # load run.conf
    @runconf            = get_runconf_settings
    @heartbeat_timeout  = runconf["heartbeat_timeout"]
    @autostart          = runconf["autostart"].nil? ? true : runconf["autostart"]
    @autorestart        = runconf["autorestart"].nil? ? true : runconf["autorestart"]
    @custom_actions     = runconf["actions"]
    @filter             = runconf["filter"] && Regexp.new(runconf["filter"])
    @multiplexed        = runconf["multiplexed"]

    # initial state
    @state = :stopped
    
    puts "[#{name}] run.conf contents: #{runconf.inspect}" if runconf.any?
  end

  def get_runconf_settings
    conf_file = File.join(@path, "run.conf")
    if File.exists? conf_file
      YAML.load_file conf_file
    else
      {}
    end
  end

  def siblings
    @babysitter.children - [self]
  end

  def multiplexed_siblings
    @babysitter.multiplexed_children - [self]
  end

  #####################################
  # information / status
  #####################################

  ACTIONS_FOR_STATE = {
    # state        # actions
    :running    => %w[restart stop],
    :stopped    => %w[start],
    :crashed    => %w[start],
    :restarting => %w[stop],
    :waiting    => %w[kill!],
  }

  def actions
    names = ACTIONS_FOR_STATE[state] or []
    names += @custom_actions.keys if @custom_actions
    names.uniq
  end

  def do_action(name)
    if @custom_actions and command = @custom_actions[name]
      msg = "Executing: #{command.inspect}"
      print msg
      msg + `#{command}`
    elsif respond_to? name
      send(name)
    else
      puts "Action #{name} not defined"
    end
  end

  def pid
    @conn and @conn.get_pid
  end

  def relative_path
    @relative_path ||= path.gsub(%r{^#{Regexp.escape(babysitter.root)}/?}, '')
  end

  def name
    relative_path
  end

  def cause_of_death
    DEATHS.shuffle.first
  end
  
  def timed_out?
    if @heartbeat_timeout and @state == :running and @last_heartbeat
      duration = (Time.now - @last_heartbeat).to_f
      duration > @heartbeat_timeout
    else
      false
    end
  end

  def running?
    state == :running
  end

  #####################################
  # callbacks
  #####################################

  def on_output(line)
    if line =~ HEARTBEAT_RE
      @last_heartbeat = Time.now
    else
      log(line) unless @filter and @filter =~ line
    end
  end

  def on_start
    @state = :running
    init_logger
    log "--- Process started. -----------------"
  end

  def on_exit
    unless @conn
      log "--- process closed (unknown cause -- the connection disappeared!)"
      return
    end
    
    status = @conn.get_status

    @conn   = nil

    if @intentional_stop
      log "--- Process STOPPED on purpose -----------------"
      log "#{name} stopped."
      @state = :stopped
      @intentional_stop = nil
    else
      if not @autorestart
        @state = :stopped
      else
        # crashed!
        @crashes += 1
        log "--- CRASH!!!! -----------------"
        log "--- process ##{status.pid} terminated (exitcode: #{status.exitstatus.inspect}, #{@crashes} crashes in a row... restarting in #{@restart_delay} seconds)"
        if @crashes >= @crash_limit
          @state = :crashed
        else
          @state = :restarting
          EM.add_timer(@restart_delay) { restart(false) }
        end
      end
    end
  end

  #####################################
  # control
  #####################################

  def start(intentional=true)
    return if running?

    if multiplexed
      puts "* Shutting down siblings..."
      for sibling in multiplexed_siblings
        puts "  |_ #{sibling.name}"

        if sibling.state == :running
          puts "     - Stopping..."
          sibling.stop
        end
      end
    end

    @crashes = 0 if intentional
    puts "Start: #{name}"
    launch_process
  end

  def stop(intentional=true)
    return unless running?

    puts "Stop: #{name}"
    @intentional_stop = intentional
    send_kill_signal("TERM")
  end

  def restart(intentional=true)
    puts "Restart: #{name}"
    stop(intentional)
    @state = :restarting
    EM.add_timer(3) { start(intentional) }
  end

  def send_kill_signal(signal="TERM")
    @state = :waiting
    unless system("kill", "-#{signal}", pid.to_s)
      log "Couldn't kill pid #{pid.inspect} with signal #{signal.inspect}. Process already dead?"
      @state = :stopped
    end
  end

  ## ununobsolete...
  def old_send_kill_signal(signal="TERM")
    begin
      Process.kill(signal, pid)
      @state = :waiting
    rescue => e
      log "Couldn't kill #{pid}. (#{e.inspect})"
      @state = :stopped
    end
  end

  def kill!
    send_kill_signal("KILL")
  end

  def launch_process
    Dir.chdir(path) do
      @conn = EM.popen("./run", ChildConnection, self) 
      #@conn = EM.popen("bash -c './run 2>&1'", ChildConnection, self) 
      #@conn = EM.popen3("./run", Child, self, path, relative)
      #@conn = EM.ptyopen("./run", Child, self, path, relative)
    end
  end

  def check_timeout
    if timed_out?
      log "---------- TIMEOUT! Restarting... ----------------------"
      puts "#{name} timed out. restarting..."
      EM.next_tick { restart }
    end
  end
  

  #####################################
  # logging
  #####################################
  
  def init_logger
    @logfile = File.join logdir, "#{name}-#{Time.now.strftime("%Y-%m-%d_%I:%M:%S%p")}.log"
    @symlink = File.join path, "current.log"

    # make the logdir
    dir = File.dirname @logfile
    unless File.exists? dir
      @output.puts "* Creating #{dir.inspect}"
      FileUtils.mkdir_p(dir)
    end
    
    # create the logger
    @logger = SimpleLogger.new(open(@logfile, "w"))

    # refresh the symlink
    File.unlink(@symlink) if File.symlink?(@symlink)
    File.symlink(@logfile, @symlink)
  end

  def log(message)
    @logger.info message if @logger
    if babysitter.verbose or !@logger
      @output.puts "[#{@logger.timestamp}] [#{name}] #{message}"
    end
  end

  def logdir
    File.join path, "logs"
  end

  def loglines(*args)
    #p [:loglines, *args]
    options = args.last.is_a?(Hash) ? args.pop : {:backward=>3000} 
    file    = args.first

    if file
      file = File.join logdir, file
    else
      file = logfile
    end

    File::Tail::Logfile.open(file, options).read
  end

  def greplog(expression)
    loglines
  end
  
  def logfiles
    Dir[File.join logdir, "*.log"].sort_by { |path| File.mtime(path) }.reverse
  end

end
