require 'rubygems'
require 'eventmachine'
require 'open3'

module EventMachine
  def self.connections
    EventMachine.instance_variable_get("@conns")
  end
end


module IOWatcher

  def initialize(cb)
    @cb = cb
  end

  def notify_readable
    begin
     @cb.call :receive_data, @io.read_nonblock(4096)
   rescue EOFError => e
     #close_connection
     @io.close
     unbind
   end
  end

  def unbind
    @cb.call :unbind
    close_connection
  end

end

class ProcessThing < EM::Connection
  [:stdout, :stderr].each do |thing|
    define_method "receive_#{thing}" do |data|
      p [thing, data]
    end
  end
end

module EventMachine

  def self.popen3(cmd, handler=nil, *args)

    klass = klass_from_handler(Connection, handler, *args)
    p klass
    c = klass.new cmd, *args
    p c
    stdin, stdout, stderr = Open3::popen3(cmd)

    pipes = {:stderr=>stderr, :stdout=>stdout}

    pipes.each do |name, pipe|

      cb = proc do |meth, *args|
        
        c.send(meth, *args)
        break
        case meth
          when :receive_data
            methname = "receive_#{name}"
            if c.respond_to? methname
              c.send(methname, data)
            else
              c.send(meth, data)
            end
          else
            c.send(meth, data)
        end
      end
      
      EM.watch(pipe, IOWatcher, cb) { |conn| conn.notify_readable = true }

    end

    c
  end

end

if $0 == __FILE__
  EM.run do
    EM.popen3("./errtest.rb", ProcessThing)
  end
end