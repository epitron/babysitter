require 'child'

@bs = Struct.new(:root, :verbose).new
@bs.verbose = true
@bs.root = File.expand_path "test-pod"
@path = File.expand_path("test-pod/test")

Thread.new{EM.run}

child = Child.new(@bs, @path, :test_mode=>true)
child.start
sleep 3
p child.pid
p child.alive?
child.stop
sleep 5
