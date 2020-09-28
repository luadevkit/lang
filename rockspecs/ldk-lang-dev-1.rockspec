rockspec_format = '3.0'
package = 'ldk-lang'
version = 'dev-1'
source = {
   url = 'git://github.com/dwenegar/ldk-lang.git',
}
description = {
   summary = 'Classes and Mixins for lua',
   license = 'MIT',
   maintainer = 'simone.livieri@gmail.com'
}
dependencies = {
   'lua >= 5.4',
   'ldk-checks >= 0.1.0',
   'ldk-hash >= 0.1.0',
}
build = {
   modules = {
      ['ldk.lang'] = 'src/ldk/lang.lua',
   },
}
test = {
   type = 'busted'
}
