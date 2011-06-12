#
# Tells the state of each child process to something that can receive OSC messages.
#
# Sends two types of messages:
#   /health/<hostname> s <status>
#   /<hostname>/<child_name> s <status>
#

class OSCStatus
  
  attr_reader :client, :babysitter

  def initialize(babysitter, hoststring)
    host, port = hoststring.split(':')
    port = port.to_i
    @client       = OSC::Client.new(host, port)
    @babysitter   = babysitter
    @counter      = 0
  end
  
  def update
    @counter += 1
    char = @counter % 2 == 0 ? "+" : "-"
    
    hostname = babysitter.hostname
    @client.send( OSC::Message.new("/health/#{hostname}", "#{char} running #{char}") )
    
    babysitter.children.each do |child|
      uri     = "/#{hostname}/#{child.name}" 
      message = "#{char} #{child.state} #{char}"
      @client.send( OSC::Message.new(uri, message) )
    end
  end

end


