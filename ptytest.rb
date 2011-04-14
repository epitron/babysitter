require 'em_ptyopen'

module Handler

  def receive_data data
    p [:data, data]
  end

end

EM.run do
  EM.next_tick{ EM.ptyopen("test-pod/crashy/run", Handler) }
end

