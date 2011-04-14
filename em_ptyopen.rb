require 'rubygems'
require 'eventmachine'
require 'pty'

module IOWatcher

  def initialize(cb)
    @cb = cb
  end

  def notify_readable
    @cb.call :receive_data, @io.read_nonblock(4096)
  rescue EOFError, Errno::EIO
    unbind
  end

  def unbind
    @cb.call :unbind
  end

end

class ProcessThing < EM::Connection
  def receive_data(data)
    p [:data, data.lines.to_a]
  end
end

module EventMachine

  def self.ptyopen(cmd, handler=nil, *args)
    klass = klass_from_handler(Connection, handler, *args)
    
    begin
      stdout, stdin, pid = PTY.spawn(cmd)
    rescue => e #PTY::ChildExited
      p e
      p "DEAD CHILD"
    end
  
    c = klass.new pid, *args

    cb = proc do |meth, *args|
      c.send(meth, *args)
    end
    
    EM.watch(stdout, IOWatcher, cb) { |conn| conn.notify_readable = true }

    #EM.error_handler do |e|
    #  #p e
    #  case e
    #    when PTY::ChildExited
    #      p e
    #      #p "IT IS!"
    #      c.unbind
    #  else
    #    raise e
    #  end
    #end

    c
  end

end

if $0 == __FILE__
  EM.run do
    EM.error_handler { |e| p e }
    EM.next_tick { EM.ptyopen("./errtest.rb", ProcessThing) }
    #EM.ptyopen("ls", ProcessThing)
  end
end