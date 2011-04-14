class SimpleLogger

  def initialize(file)
    @file = file
  end

  def info(msg)
    begin
      @file.puts("[#{timestamp}] #{msg.chomp}")
      @file.flush
    rescue => e
      
    end
  end

  def timestamp
    Time.now.strftime("%Y-%m-%d %I:%M:%S%p")
  end

end
