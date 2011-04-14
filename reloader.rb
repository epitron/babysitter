# Taken mostly from
# http://groups.google.com/group/sinatrarb/t/a5cfc2b77a013a86

class Sinatra::Reloader < Rack::Reloader
  def safe_load(file, mtime, stderr = $stderr)
    ::Sinatra::Application.reset!
    stderr.puts "#{self.class}: reseting routes"
    super
  end
end
