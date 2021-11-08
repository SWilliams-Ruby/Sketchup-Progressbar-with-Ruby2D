require File.join(SW::ProgressBarRuby2DExamples::PLUGIN_DIR, 'progress_bar_ruby2d_example1.rb')


module SW
  module ProgressBarRuby2DExamples
    def self.load_menus()
          
      # Load Menu Items  
      if !@loaded
        toolbar = UI::Toolbar.new "SW ProgressBarRuby2DExamples"
        
        cmd = UI::Command.new("Progress1") {SW::ProgressBarRuby2DExamples.demo1}
        cmd.large_icon = cmd.small_icon =  File.join(SW::ProgressBarRuby2DExamples::PLUGIN_DIR, "icons/example1.png")
        cmd.tooltip = "ProgressBar Ruby2D"
        cmd.status_bar_text = "Example 1"
        toolbar = toolbar.add_item cmd
       
        toolbar.show
      @loaded = true
      end
    end
    load_menus()
  end
  
end


