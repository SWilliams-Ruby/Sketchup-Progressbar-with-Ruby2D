
module SW
  module ProgressBarRuby2DExamples
    def self.demo1()
      begin

        model = Sketchup.active_model.start_operation('Progress Bar Example', true)

        # Specify the progress bar script
        dialog_path = File.join(SW::ProgressBarRuby2DExamples::PLUGIN_DIR, 'dialogs/example1_dialog.rb')
        
        # Specify a hash of elements that will be passed to the dialog script
        pbar_status = {:operation => "Adding Cubes", :value => 0.0, :label => "Remaining:"}
        
        SW::ProgressBarRuby2D::ProgressBar.new(dialog_path) { |pbar|

          # update the progressbar with initial values
          pbar.refresh(pbar_status)
          
          # create an array of random points 
          points =  []
          1000.times{points << [rand(100),rand(100),rand(100)]}

          # Add cubes to the model, keeping the progress bar updated
          points.each_with_index { |point, index|
            make_cube(point)
            if pbar.update?
              pbar_status[:label] = "Remaining: #{points.size - index}"
              pbar_status[:value] = 100 * index / points.size
              pbar.refresh(pbar_status)
            end
          }
        }

        Sketchup.active_model.commit_operation
        puts 'Demo Completed'

      rescue => exception
        Sketchup.active_model.abort_operation
        # Catch a user initated cancel 
        if exception.is_a? SW::ProgressBarRuby2D::ProgressBarAbort
          #UI.messagebox('Demo Aborted', MB_OK)
          puts 'Demo Canceled'
        else
          raise exception
        end
      end

    end
    
    # add a cube to the model  
    def self.make_cube(point)
      ents = Sketchup.active_model.entities
      grp = ents.add_group
      face = grp.entities.add_face [0,0,0],[2,0,0],[2,2,0],[0,2,0]
      face.pushpull(2)
      grp.material = "red"
      tr = Geom::Transformation.new(point)
      grp.transform!(tr)
    end

  end
end
nil

