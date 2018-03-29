 #
 # ============================================================================
 #                   The XyloComp Software License, Version 1.1
 # ============================================================================
 # 
 #    Copyright (C) 2016 XyloComp Inc. All rights reserved.
 # 
 # Redistribution and use in source and binary forms, with or without modifica-
 # tion, are permitted provided that the following conditions are met:
 # 
 # 1. Redistributions of  source code must  retain the above copyright  notice,
 #    this list of conditions and the following disclaimer.
 # 
 # 2. Redistributions in binary form must reproduce the above copyright notice,
 #    this list of conditions and the following disclaimer in the documentation
 #    and/or other materials provided with the distribution.
 # 
 # 3. The end-user documentation included with the redistribution, if any, must
 #    include  the following  acknowledgment:  "This product includes  software
 #    developed  by  XyloComp Inc.  (http://www.xylocomp.com/)." Alternately, 
 #    this  acknowledgment may  appear in the software itself,  if
 #    and wherever such third-party acknowledgments normally appear.
 # 
 # 4. The name "XyloComp" must not be used to endorse  or promote  products 
 #    derived  from this  software without  prior written permission. 
 #    For written permission, please contact fred.patrick@xylocomp.com.
 # 
 # 5. Products  derived from this software may not  be called "XyloComp", 
 #    nor may "XyloComp" appear  in their name,  without prior written 
 #    permission  of Fred Patrick
 # 
 # THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 # FITNESS  FOR A PARTICULAR  PURPOSE ARE  DISCLAIMED.  IN NO  EVENT SHALL
 # XYLOCOMP INC. OR ITS CONTRIBUTORS  BE LIABLE FOR  ANY DIRECT,
 # INDIRECT, INCIDENTAL, SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL  DAMAGES (INCLU-
 # DING, BUT NOT LIMITED TO, PROCUREMENT  OF SUBSTITUTE GOODS OR SERVICES; LOSS
 # OF USE, DATA, OR  PROFITS; OR BUSINESS  INTERRUPTION)  HOWEVER CAUSED AND ON
 # ANY  THEORY OF LIABILITY,  WHETHER  IN CONTRACT,  STRICT LIABILITY,  OR TORT
 # (INCLUDING  NEGLIGENCE OR  OTHERWISE) ARISING IN  ANY WAY OUT OF THE  USE OF
 # THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 # 
 #

require 'sketchup.rb'
require 'langhandler.rb'
require "#{$trkdir}/base.rb"
require "#{$trkdir}/section.rb"
require "#{$trkdir}/zone.rb"
require "#{$trkdir}/switches.rb"
require "#{$trkdir}/trk.rb"

$exStrings = LanguageHandler.new("track.strings")

include Math
include Trk

class AddRiserTab

    def initialize
        puts "AddRiserTab.initialize"
        TrackTools.tracktools_init("AddRiserTab")

        $current_connection_point = nil
        @dtxt = ""
        cursor_path = Sketchup.find_support_file("riser_cursor_0.png",
                                                 "Plugins/xc_tracktools/")
        if cursor_path
            @cursor_looking = UI.create_cursor(cursor_path, 16, 16) 
        else
            UI.messagebox("Couldnt get cursor_path")
            return
        end 
        cursor_path = Sketchup.find_support_file("riser_cursor_1.png", 
                                                 "Plugins/xc_tracktools/")
        if  cursor_path
            @cursor_on_target = UI.create_cursor(cursor_path, 16, 16) 
        else
            UI.messagebox("Couldnt get cursor_path")
            return
        end 

        @cursor_id = @cursor_looking
        define_onRButtonDown
        @istate = 0 
    end

    def onSetCursor
        if @cursor_id
            
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "############################# activate AddRiserTab #{Time.now.ctime}"
        $logfile.flush
        puts          "############################# activate AddRiserTab #{Time.now.ctime}"
        @ip_xform = $zones.zones_group.transformation.clone
        @ip_xform.invert!
        Section.get_class_defaults
        puts "AddRiserTab.activate, SectionBuildDefaults"
        track_attributes = Sketchup.active_model.attribute_dictionary("SectionBuildDefaults")
        track_attributes.each_pair { |k, v| puts "\t #{k}    #{v}" }
        @ip = Sketchup::InputPoint.new
        @ptLast = Geom::Point3d.new 1000, 1000, 1000
        Trk::save_layer_state
        title = "RiserTab Build Selection"
        prompts = ["Location"]
        tlist   = ["lMouseButtonDown|Align w/RiserTab|InlineDistance|x,y coordinates"]
        defaults= ["lMouseButtonDown"]
        results = UI.inputbox(prompts, defaults, tlist, title)
        @build_mode = results[0]
        puts "addrisertab.initialize, #{@build_mode}"
        @drawn = false
        lower_camera
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate AddRiserTab #{Time.now.ctime}"
        puts          "############################ deactivate AddRiserTab #{Time.now.ctime}"
        TrackTools.model_summary
        $logfile.flush
        Trk::restore_layer_state
        view.invalidate if @drawn
        Section.set_class_defaults
        track_attributes = Sketchup.active_model.attribute_dictionary("SectionBuildDefaults")
        track_attributes.each_pair { |k, v| puts "\t #{k}    #{v}" }
    end

    def onMouseMove( flags, x, y, view)
        if @build_mode != "lMouseButtonDown" then return end
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        if npick > 0 
            pkcount = @ph.count
            @base_data = Zone.base_path?(@ph)
            if @base_data
                @base_data_0 = @base_data
                @tposition = @ip_xform * @ip.position
                @cursor_id = @cursor_on_target
                puts "addrisertab.onMouseMove, tposition = #{@tposition}"
            end
        end
    end # end onMouseMove

    def onLButtonDown(view, x, y, flags)
        puts "addrisertab.onLButtonDown"
        Trk.list_pick_paths(@ph)
        base = @base_data_0[0]
        face_code = @base_data_0[1]
        begin
            risertab = base.create_risertab(@tposition, face_code)
        rescue => ex
            puts ex.to_s
            trace = ex.backtrace
            trace.each{ |s| puts s}
            Sketchup.active_model.tools.pop_tool
        end
    end

    def define_onRButtonDown
        #puts "define_onRButtonDown"
        def onRButtonDown(flags, x, y, view)
            puts "AddRiserTag.onRButtonDown"
        end
    end

    def lower_camera
        puts "addrisertab.lower_camera"
        puts Trk.camera_parms 
        result = UI.messagebox("Do want to lower camera.up?", MB_YESNOCANCEL)
        if result == IDYES
            camera = Sketchup.active_model.active_view.camera
            eye = camera.eye
            eye = [eye.x, eye.y, 6.0]
            up = camera.up
            #up = up.reverse
            camera.set(eye, camera.target, up)
            puts Trk.camera_parms 

        elsif result == IDCANCEL
            return nil
        end
        return true
    end
    def onMouseEnter(view)
    end
    def resume(view)
        puts "addrisertab.resume.tool_name = #{Sketchup.active_model.tools.active_tool_name}"
    end
    def suspend(view)
        puts "addrisertab.suspend, tool_name = #{Sketchup.active_model.tools.active_tool_name}"
    end
end #end of Class AddRiserTab
