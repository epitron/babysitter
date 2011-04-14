require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
 
class Handler  < EventMachine::Connection
  include EM::HttpServer
 
  # the http request details are available via the following instance variables:
  #   @http_protocol
  #   @http_request_method
  #   @http_cookie
  #   @http_if_none_match
  #   @http_content_type
  #   @http_path_info
  #   @http_request_uri
  #   @http_query_string
  #   @http_post_content
  #   @http_headers  
  def process_http_request
    p instance_variables.map{|v| [v, instance_variable_get(v)]}
    resp = EventMachine::DelegatedHttpResponse.new( self )
 
    #sleep 2 # Simulate a long running request
 
    resp.status = 200
    resp.content = "Hello World!"
    resp.send_response
  end
end
 
EventMachine::run {
  EventMachine.epoll
  EventMachine::start_server("0.0.0.0", 8080, Handler)
  puts "Listening..."
}
