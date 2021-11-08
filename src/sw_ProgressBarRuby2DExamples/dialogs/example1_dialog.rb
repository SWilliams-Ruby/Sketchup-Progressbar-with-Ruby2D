# As you will see in the following code, the Ruby2D Gem is a strange beast
#
# https://github.com/ruby2d/ruby2d
# https://www.ruby2d.com/
# https://rubygems.org/gems/ruby2d/versions/0.9.2
# https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.0.2-1/rubyinstaller-devkit-3.0.2-1-x64.exe
#

###########
# Repair a bug in the Windows + Ruby + Sketcthup implementation
# where STDOUT is not piped correctly to the popen server.
#
# See: io.c > io_reopen(VALUE io, VALUE nfile)
# if (fptr == orig) return io;
#
def reopen_io()
  temp = STDOUT
  STDOUT.reopen(STDERR)
  STDOUT.reopen(temp)
  STDOUT.sync
  STDERR.sync
end

def print_exception(exception)
  STDOUT.puts "#{exception.class}: #{exception.message}"
  STDOUT.puts exception.backtrace.join("\n")
  STDOUT.flush
end

#
# Force Ruby to find the correct paths to the Gem storage
# See:  lib\rubygems\path_support.rb
#
def reset_gem_path()
  env = {'GEM_HOME' => nil,'GEM_PATH'=> nil}
  Gem.paths = env
end

begin
  reopen_io()
  reset_gem_path()
  $ruby2d_console_mode = true # force RUBY2D to read/write from standard IO
  puts "RUBY2D_Connect"  # complete the handshake with Sketchup

  require 'io/wait'
  require 'ruby2d'
  
  # Window size and border
  set width: 600, height: 150
  set borderless: true
  set title: 'Progress Bar', background: 'gray'
  border = Rectangle.new(x: 2, y: 2, width: 596, height: 146, color: 'white')

  # Labels and Progressbar
  operation = Text.new('Operation', x: 25, y: 10, size: 20, color: 'black')
  label = Text.new('label', x: 25, y: 38, size: 20, color: 'black')
  progressbar_background = Rectangle.new(x: 25, y: 68, width: 550, height: 25, color: 'silver', z: 10)
  progressbar =  Rectangle.new(x: 25, y: 68, width: 1, height: 25, color: 'blue', z: 20)
  closebutton = Rectangle.new(x: 25, y: 100, width: 77, height: 30, color: 'aqua', z: 20)
  Text.new('Cancel', x: 32, y: 103, size: 20, color: 'black', z: 30)
  
  # Keyboard and MouseHandlers
  on :key_down do |event|
    # A key was pressed
    puts "RUBY2D KeyEvent #{event.key}"
    if /escape/ =~ event.key
      puts "RUBY2D_Close"
      close
    end
  end  

  on :mouse_down do |event|
    case event.button
    when :left
      # STDOUT.puts "RUBY2D MouseEvent #{event.x} #{event.y}"
      # STDOUT.flush

      if closebutton.contains?(event.x, event.y)
        puts "RUBY2D_Close"
        close
      end
    end
  end
  
  show

rescue LoadError => e
  print_exception(e)
rescue => e
  print_exception(e)
end










  

