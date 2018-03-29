require 'sketchup.rb'
require 'langhandler.rb'

$exStrings = LanguageHandler.new("track.strings")

include Math

class TestTool
    def initialize
        SKETCHUP_CONSOLE.show
        if !TrackTools.tracktools_init("TestTool")
            return
        end
        rendering_options = Sketchup.active_model.rendering_options
        rendering_options["EdgeColorMode"]= 0
        rendering_options.each_pair { |key, value| puts "#{key} : #{value}" }
        @on_target = false
        @displayit = true if @section_list
    end

    def activate
        puts "activate TestTool"
        $logfile.puts "#############################  activate TestTool #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @drawn = false
        $a_group = Sketchup.active_model.entities.add_group
        $a_group.name = "a_group"
        $a_group.material = "red"
        p0 = Geom::Point3d.new(0.0,  0.0, 0.0)
        p1 = Geom::Point3d.new(0.0, 10.0, 0.0)
        p2 = Geom::Point3d.new(5.0, 5.0, 0.0)
        $a_group.entities.add_face(p0, p1, p2)
        q0 = Geom::Point3d.new(10.0,  0.0,  0.0)
        q1 = Geom::Point3d.new(20.0,  0.0,  0.0)
        q2 = Geom::Point3d.new(20.0, 20.0,  0.0)
        q3 = Geom::Point3d.new(10.0, 20.0,  0.0)
        face = $a_group.entities.add_face(q0, q1, q2, q3)
        face.material = "blue"
        face.back_material = "blue"
        r0 = Geom::Point3d.new( 30.0,  0.0,  0.0)
        r1 = Geom::Point3d.new( 30.0, 20.0,  0.0)
        r2 = Geom::Point3d.new( 35.0, 20.0,  0.0)
        r3 = Geom::Point3d.new( 35.0,  0.0,  0.0)
        edges = $a_group.entities.add_edges(r0, r1, r2, r3)
        edges.each { |e| e.material= "goldenrod"}
        vt = Geom::Vector3d.new(10.0, 40.0, 20.0)
        @xform_a = Geom::Transformation.translation(vt)
        $a_group.transformation = @xform_a
        puts @xform_a.to_s
        puts @xform_a.to_a
        puts @xform_a.to_a.to_s
        xf = @xform_a.to_a
        tag= "transformation:"
        xf = @xform_a.to_a
        tag= "transformation:"
        4.times { |n|
        n4 = n * 4
        printf("%15s %10.6f,%10.6f,%10.6f,%10.6f\n",tag, xf[0+n4], xf[1+n4], xf[2+n4],xf[3+n4])
        tag = ""
        }
        4.times { |n|
        n4 = n * 4
        printf("%15s %10.6f,%10.6f,%10.6f,%10.6f\n",tag, xf[0+n4], xf[1+n4], xf[2+n4],xf[3+n4])
        tag = ""
        }
        
        $b_group = $a_group.entities.add_group
        $b_group.name = "b_group"
        #$b_group.material = "blue"
        vb = Geom::Vector3d.new(50.0, 0.0,0.0)
        uz = Geom::Vector3d.new(0.0, 0.0, 1.0)
        circle  = $b_group.entities.add_circle(p0, uz, 10.0, 6)
        @xform_b_0 = Geom::Transformation.translation(vb)
        @xform_b_1 = Geom::Transformation.rotation(p0, uz, Math::PI / 6.0)
        $b_group.transformation = @xform_b_1

        $c_group = $b_group.entities.add_group
        $c_group.name = "c_group"
        @xform_c = Geom::Transformation.rotation(p0, uz, Math::PI / 2.0)
        $c_group.entities.add_3d_text("C_GROUP", TextAlignLeft, "Courier",
                            false,false, 5.0, 0.6, 0.0, false)
        $c_group.transformation = @xform_c
        #$c_group.explode
        @istate = 0

    end

    def deactivate(view)
        $logfile.puts "###########################  deactivate TestTool #{Time.now.ctime}"
        puts "deactivate TestTool"
        $logfile.flush
        view.invalidate if @drawn
    end

    def draw(view)
        if @ip.valid? && @displayit
            #@section_list.draw_sections(view)
        end
    end

    def onLButtonDown(flags, x, y, view)
        puts "onLButtonDown"
        if @istate == 0
            $b_group.transformation= @xform_b_1
            $a_group.material = "green"
        elsif @istate == 1
            $a_group.transformation= @xform_a
        elsif @istate = 2
            #$c_group.transformation= @xform_c
        end
        @istate += 1
            
        #b_entities = $b_group.explode
        #$b_group.erase!
        view.refresh
        @ip.pick view, x, y
        @ph = view.pick_helper
    end

    def onRButtonDown(flags, x, y, view)
        puts "onRButtonDown"
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        @ph.do_pick(x, y)
    end
end
