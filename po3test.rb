require 'em_popen3'

module Handler

  def receive_data data
    p [:data, data]
  end

  def unbind
    p [:unbind]
  end
  
end

EM.run do
  EM.next_tick{ EM.popen3("test-pod/crashy/run", Handler) }
  EM.add_periodic_timer { p [:conns, EM.connections.size] }
end

