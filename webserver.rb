require 'rubygems'
require 'sinatra/base'
require 'reloader'
require 'haml'
require 'sass'

class WebServer < Sinatra::Base

  #######################################################################
  ## Config
  #######################################################################

  set :root, File.dirname(__FILE__)
  set :environment, :development
  set :static, true
  #set :sessions, true
  #use Sinatra::Reloader, 0

  def self.run!(options={})
    set options
    handler      = detect_rack_handler
    handler_name = handler.name.gsub(/.*::/, '')
    
    unless handler_name =~ /cgi/i
      puts "* Webserver started on http://#{host}:#{port}/ (Sinatra/#{Sinatra::VERSION}, #{handler_name}, #{environment})"
    end

    handler.run self, :Host => host, :Port => port do |server|
      set :running, true
    end

  rescue Errno::EADDRINUSE
    puts "* Error: Cannot start webserver -- port #{port} is in use!"
    exit 1
  end


  def babysitter
    options.babysitter
  end


  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end

#  before do
#    p [:request, request]
#  end

  #######################################################################
  ## HTTP actions
  #######################################################################

  get '/screen.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :"css/screen"
  end
  
  get '/' do
    #"asdf"
    haml :index
  end

  get '/', :agent => /(Android|iPhone)/ do
    "Dude, you're using an #{$1}! (#{params[:agent][0]})"
  end

  get '/processes' do
    #"asdf"
    haml :processes, :layout=>false
  end

  get "/:child" do
    name = params[:child]
    @child = babysitter[name]
    @title = name
    raise "Can't find child #{name.inspect}" unless @child
    haml :child
  end

  get "/:child/log" do
    # :backward => 10 to go backwards
    # :forward => 10 to go forwards
    name = params[:child]
    @child = babysitter[name]

    if file = params[:logfile]
      @loglines = @child.loglines(file)
    else
      @loglines = @child.loglines(:backward=>200)
    end
    @title = name
    haml :log, :layout=>false
  end

  get "/:child/:action" do
    # :backward => 10 to go backwards
    # :forward => 10 to go forwards

    name = params[:child]
    @action = params[:action]
    @child = babysitter[name]
    result = @child.do_action(@action)
    #haml :action
    h "[#{Time.now}] #{@action} \"#{@child.name}\": complete.#{" output:\n#{result}" if result}\n"
  end
  
  
end
