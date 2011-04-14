require 'yaml'
require 'pp'

pp YAML.load(%{
blah: stuff
what: yay
other: 
  - 1
  - 2
  - 3
  - 4
stuff: ["what", "who", "when"]
})

pp YAML.load(%{
parent: &default
  cookies: yay

child1:
  <<: *default
  buckets: yay

child2:
  <<: *default
  cookies: boo
  buckets: what
  
  
})
  
