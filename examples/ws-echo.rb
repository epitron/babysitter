require 'rubygems'
require 'eventmachine'
require 'em-websocket'
require 'socket'

PORT = 9876

EventMachine.run {

  conn = EventMachine::WebSocket.start(:host => "0.0.0.0", :port => PORT) do |ws|
    ws.onopen {
      cport, chost = Socket.unpack_sockaddr_in(ws.get_peername)
      @client = "#{chost}:#{cport}"
 
      puts "[#{@client}] WebSocket connection open"

      # publish message to the client
      ws.send "Hello #{@client}!"
      
      puts "Adding heartbeat..."
      EM.add_periodic_timer(1) { ws.send("[#{Time.now.strftime('%Y-%d-%m @ %H:%M:%S%p')}] Thump.") }
    }

    ws.onclose { puts "[#{@client}] Connection closed" }
    ws.onmessage { |msg|
      puts "[#{@client}] Recieved message: #{msg}"
      ws.send "Pong: #{msg}"
    }
  end

  puts "* WebSocket server listening on port #{PORT}..."
  
}

