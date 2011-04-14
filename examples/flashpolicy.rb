require 'rubygems'
require 'eventmachine'
require 'socket'

PORT = 843

class FlashPolicyServer < EM::Connection

  REQUEST = "<policy-file-request/>"
  RESPONSE = %{<cross-domain-policy>\n    <allow-access-from domain="*" to-ports="*" />\n</cross-domain-policy>\n}

  def msg message
    puts "[#{@client}] #{message}"
  end
  
  
  def post_init
    cport, chost = Socket.unpack_sockaddr_in(get_peername)
    @client = "#{chost}:#{cport}"
    msg "Connect"
  end    
  
  def receive_data data
    if data[REQUEST]
      send_data(RESPONSE)
      msg "-- FLASH RESPONSE --"
    end
    close_connection_after_writing  
  end
  
  def unbind
    msg "Disconnect"
  end
  
end


EventMachine.run do
  
  begin
    
    EM::start_server "0.0.0.0", PORT, FlashPolicyServer
    puts "* Flash policy server listening on port #{PORT}..."
    
  rescue RuntimeError => e
    
    case e.message
      when "no acceptor"
        puts "Error: You must run this as root."
        exit 1
    else
      raise e
    end
    
  end
  
end

