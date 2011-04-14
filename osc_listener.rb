#----------------------------------------------------------------------

%w[ rubygems eventmachine lib/osc-ruby ].each { |m| require m } 

#----------------------------------------------------------------------

module OSC

  #
  # Doesn't do EM.run, just adds a new listener to the existing EM.
  #
  class EMServer2

    def initialize( port = 5555 )
      @port = port
      setup_dispatcher
      @tuples = []
      listen
    end

    def listen
      EM.open_datagram_socket "localhost",  @port, Connection
    end

    def add_method(address_pattern, &proc)
      matcher = AddressPattern.new( address_pattern )

      @tuples << [matcher, proc]
    end

  private
    def setup_dispatcher
      OSC::Channel.subscribe do  |messages|
        messages.each do |message|
          diff =  ( message.time || 0 ) - Time.now.to_ntp

          if diff <=  0
            sendmesg( message )
          else
            EM.defer  do
              sleep(  diff  )
              sendmesg( message )
            end
          end
        end
      end
    end

    def sendmesg(mesg)
      @tuples.each do |matcher, obj|
        if matcher.match?( mesg.address )
          obj.call( mesg )
        end
      end
    end
  end
end

