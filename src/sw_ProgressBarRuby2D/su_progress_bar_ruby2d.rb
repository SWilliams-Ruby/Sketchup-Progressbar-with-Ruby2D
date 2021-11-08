# https://github.com/ruby2d/ruby2d
# https://www.ruby2d.com/
# https://rubygems.org/gems/ruby2d/versions/0.9.2
# https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.0.2-1/rubyinstaller-devkit-3.0.2-1-x64.exe
#

# do I need to wrap this in an SUtool to prevent multiple invocations

#############################################
#
# Initializer:
#   new(dialog_path) -> progressbar
#   new(dialog_path) { |progressbar| block } -> result of block
#
# If a code block is given the progressbar will be shown, the code block will be
# executed, and the progressbar will then be hidden. The progressbar instance
# will be passed to the code block as an arguement. With no associated block the
# progressbar instance will be returned to the caller. The caller will then be
# responsible for showing and hiding the progressbar.
#
# block example:
# module SW::ProgressBarWebSocketExample
# def self.run_demo1()
#     begin
#       model = Sketchup.active_model.start_operation('Progress Bar Example', true)
# 
#       dialog_path = File.join(SW::ProgressBarWebSocketExamples::PLUGIN_DIR, 'dialogs/example1_dialog.html')
#       pbar_status = {:operation => "Progress Bar Example", :value => 0.0, :label => "Remaining:100"}
# 
#       SW::ProgressBarWebSocket::ProgressBar.new(dialog_path) {|pbar|
#         100.times {|i|
#           # modify the sketchup model here
#           sleep(0.02)
#           # update the progressbar
#            if pbar.update?
#             pbar_status[:label] = "Remaining: #{100 - i}"
#             pbar_status[:value] = i / 100
#             result = pbar.refresh(pbar_status)
#           end
#         }
#       }
#       Sketchup.active_model.commit_operation
#     rescue => exception
#       Sketchup.active_model.abort_operation
#       raise exception
#     end
#   end
#   run_demo1()
# end
#
# no block example:
# module SW::ProgressBarWebSocketExample
#   def self.run_demo2()
#     begin
#       model = Sketchup.active_model.start_operation('Progress Bar Example', true)
# 
#       dialog_path = File.join(SW::ProgressBarWebSocketExamples::PLUGIN_DIR, 'html/example1_dialog.html')
#       pbar_status = {:operation => "Progress Bar Example", :value => 0.0, :label => "Remaining:100"}
# 
#       pbar = SW::ProgressBarWebSocket::ProgressBar.new(dialog_path)
#       pbar.show
#       
#       100.times {|i|
#         # modify the sketchup model here
#         sleep(0.02)
#         # update the progressbar
#          if pbar.update?
#           pbar_status[:label] = "Remaining: #{100 - i}"
#           pbar_status[:value] = i / 100
#           result = pbar.refresh(pbar_status)
#         end
#       }
#       Sketchup.active_model.commit_operation
#     rescue => exception
#       Sketchup.active_model.abort_operation
#       raise exception
#     ensure
#       pbar.hide
#     end
#   end
#   run_demo2()
# end
#

module SW
  module ProgressBarRuby2D
  
    # Exception class for Progress bar control messages
    class ProgressBarAbort < RuntimeError; end

    class ProgressBar
      @@inuse = false
      
      def initialize(dialog_path, &block)
        @dialog_path = dialog_path
        if block
          begin
            show()
            block.call(self)
          ensure
            hide()
          end
        end
      end # initialize
   
      # Show the progress bar
      # 
      def show()
        return if @@inuse # one at a time please
        @@inuse = true
        @activated = true
        @update_interval = 0.1
        setup_and_show()
        start_update_thread()
      end

      # Stop the update? thread
      # Close the dialog
      #
      def hide()
        @@inuse = false
        @activated = false
        @running = false
        ruby2d_client_close()
        @outbound_pipe_rd.close
        @outbound_pipe_wr.close
        stop_update_thread()
      end
     
      # Instruct the dialog to open: 
      #
      def setup_and_show()
        setup_pipes()
        post_initial_outbound()
        open_dialog()
      end
      
      def setup_pipes()
        @ruby2d_client_status = :waiting
        @inbound_queue = Queue.new
        @outbound_pipe_rd, @outbound_pipe_wr = IO.pipe
      end
            
      def post_initial_outbound()
        # cmd = "hide"
        # @outbound_pipe_wr.puts(cmd)
      end

      def open_dialog()
        cmd  = ["rubyw", @dialog_path, :err=>[:child, :out] ]
        
        @dialog_thread = Thread.new() {
          begin
            IO.popen(cmd, mode = 'a+') { |popen_pipe|
              console_log("popen client opened #{popen_pipe}")
              #popen_pipe.puts "Text.new('Testing 1, 2, 3,...')"
              
              @running = true
              while @running
                readable = IO.select([@outbound_pipe_rd, popen_pipe, ])[0][0]
                outbound_transfer(popen_pipe) if readable == @outbound_pipe_rd && @running
                inbound_transfer(popen_pipe) if (readable == popen_pipe) && @running
              end
            }
          rescue IOError
            # ignore a normal closure
          
          rescue => e
            #console_log("#{e.class}: #{e.message}")
            #console_log(e.backtrace.join("\n"))
          end
          console_log("Popen client closed\n")
        }
        @dialog_thread.priority = 2
      end
      
      #
      # Transfer outbound messages from the outbound pipe
      # to the client pipe
      #
      def outbound_transfer(popen_pipe)
        message = @outbound_pipe_rd.gets()
        # console_log(outbound_message)
        popen_pipe.puts(message)
      end
      
      #
      # Transfer inbound messages from the client pipe
      # to the inbound_queue
      #
      def inbound_transfer(popen_pipe)
        inbound_message = popen_pipe.gets.chomp
        console_log(inbound_message) if inbound_message.match('^RUBY2D')
        accept_connection(inbound_message)
        check_for_cancel(inbound_message)
        @inbound_queue << inbound_message if inbound_message
      end
      
      #
      #  Check inbound stream for initial connection message
      #
      def accept_connection(inbound_message)
        if @ruby2d_client_status == :waiting && /RUBY2D_Connect/ =~ inbound_message
          console_log("ruby2d connected")
          @ruby2d_client_status = :connected
        end
      end
      
      #
      # Check inbound stream for a User close message
      #
      def check_for_cancel(inbound_message)
        if /RUBY2D_Close/ =~ inbound_message
          @running = false
          @ruby2d_client_status = :closed_by_client
        end
      end
      
      #
      # Write to the outbound stream if the client is connected
      #
      def ruby2d_client_write(outbound_message)
        if @ruby2d_client_status == :connected
          @outbound_pipe_wr.puts(outbound_message) 
          sleep(0.001) # allow the pipes to have some running time
        end
        @ruby2d_client_status 
      end

      #
      # Read  inbound stream
      # return String or nil
      #
      # def ruby2d_client_read()      
        # inbound_message = @inbound_queue.pop(true) rescue inbound_message = nil
      # end
      
      #
      # Disable new inbound connection
      #
      def ruby2d_client_close()
        @ruby2d_client_status = :closed_by_client
        true
      end
      
 
      ###################################
      # Update routines 
      ###################################
      
      # Send status to the progressbar
      # @param status [Hash]
      #
      def refresh(status)
        cmd = "label.text = '#{status[:label]}'\noperation.text = '#{status[:operation]}'\nprogressbar.width = #{status[:value]/100.0} * progressbar_background.width\n"
        status = ruby2d_client_write(cmd)
        raise ProgressBarAbort, "User Cancel Clicked" if status == :closed_by_client
        @ruby2d_client_status  
      end
        
      # The update? method returns true approximately every @update_interval.
      # To regulate the frequency of refreshes the user code should query
      # the update? flag and refresh when the returned value is true.
      def update?
        temp = @update_flag
        @update_flag = false
        temp
      end
     
      def start_update_thread()
        @update_thread = Thread.new() {update_loop()}
        @update_thread.priority = 1
      end
      private :start_update_thread
      
      def stop_update_thread()
        @update_thread.exit if @update_thread.respond_to?(:exit)
        @update_thread = nil
      end
      private :stop_update_thread
      
      # A simple thread which will set the @update_flag approximately 
      # every @update_interval + @redraw_delay. 
      def update_loop()
        while @activated
          sleep(@update_interval)
          @update_flag = true
        end 
      end
      private :update_loop
      
      #
      # 
      #
      def console_log(message)
        #SW::Sigint_Trap.add_message("#{message}") if defined? SW::Sigint_Trap
      end
      private :console_log
      
    end # progressbar
  end
end
nil

