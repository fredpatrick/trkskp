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
require "#{$trkdir}/risertab.rb"
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
        puts "AddRiserTab.initialize, global_variables =  #{global_variables}"
        gvars = global_variables
        puts "AddRiserTab.initialize, global_variables.length = #{gvars.length}"
        gvars.each_with_index do |v,i|
            if i <= 20
                puts "AddRiserTab.initialize, #{i} - #{v} - #{eval("v") } "
            end
        end
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
        @istate = 0 
        $logfile.puts "############################# initialize AddRiserTab #{Time.now.ctime}"
        $logfile.flush
        puts          "############################# initialize AddRiserTab #{Time.now.ctime}"
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
        puts "activate.ip_xform " + Trk.dump_transformation(@ip_xform, 1)
        Section.get_class_defaults
        puts "AddRiserTab.activate, SectionBuildDefaults"
        track_attributes = Sketchup.active_model.attribute_dictionary("SectionBuildDefaults")
        track_attributes.each_pair { |k, v| puts "\t #{k}    #{v}" }
        @ip = Sketchup::InputPoint.new
        @ptLast = Geom::Point3d.new 1000, 1000, 1000
        Trk::save_layer_state
        camera = Sketchup.active_model.active_view.camera
        @eye    = camera.eye
        @target = camera.target
        @up     = camera.up
        title = "RiserTab Build Selection"
        prompts = ["Location"]
        tlist   = ["PickLocation|ExistingRiserTab|NearestSectionBoundary"]
        defaults= ["lMouseButtonDown"]
        results = UI.inputbox(prompts, defaults, tlist, title)
        @build_mode = results[0]
        @onMouseMove_defined = false
        @onLButtonDown_defined = false
        puts "addrisertab.activate, #{@build_mode}"

        if @build_mode == "PickLocation"
            @on_target = false
            puts "AddRiserTab-PickLocation, defining onMouseMove"
            if @onMouseMove_defined
                undef onMouseMove
            end
            def onMouseMove( flags, x, y, view)
                @onMouseMove_defined = true
                @ip.pick view, x, y
                @ph = view.pick_helper
                npick = @ph.do_pick(x, y)
                if npick <= 0
                    @on_target = false
                    @cursor_id = @cursor_looking
                    return
                else
                    @base_data = Zone.base_path?(@ph)
                    if @base_data
                        @base_data_0 = @base_data
                        @position_1 = @ip_xform * @ip.position
                        @cursor_id = @cursor_on_target
                        @on_target = true
                    end
                end
            end # end onMouseMove

            puts "AddRiserTab-PickLocation, defining onLeftButtonDown"
            if @onLButtonDown_defined
                undef onLButtonDown
            end
            def onLButtonDown(flags, x, y, view)
                @onLButtonDown_defined = true
                if !@on_target then return end
                base = @base_data_0[0]
                face_code = @base_data_0[1]
                slice_index = (face_code / 100.0).floor
                m           = face_code - slice_index*100
                side = "right"
                if m == 0 || m == 1
                    side = "left"
                end
                begin
                    risertab = base.create_risertab(@position_1, slice_index, m, true)
                rescue => ex
                    puts ex.to_s
                    trace = ex.backtrace
                    trace.each{ |s| puts s}
                    Sketchup.active_model.tools.pop_tool
                end
            end
            #end of PickLocation
        elsif @build_mode == "ExistingRiserTab"
            @state = "Idle"
            puts "AddRiserTab-ExistingRisertab, defining onMouseMove"
            if @onMouseMove_defined
                undef onMouseMove
            end
            def onMouseMove( flags, x, y, view)
                @onMouseMove_defined = true
                if @state == "Idle"
                    @ip.pick view, x, y
                    @ph = view.pick_helper
                    npick = @ph.do_pick(x, y)
                    if npick <= 0
                        @cursor_id = @cursor_looking
                        return
                    else
                        puts "onMouseMove, state = {@state}, npick = #{npick}"
                        @primary_risertab = Base.risertab_path?(@ph)
                        puts @primary_risertab.class
                        if @primary_risertab
                            Trk.list_pick_paths(@ph)
                            puts @primary_risertab.to_s(2)
                            puts @primary_risertab.class
                            @cursor_id = @cursor_on_target
                            @state = "OnTarget1stRiserTab"
                            puts "onMouseMove, got the 1st risertab"
                        end
                    end
                elsif @state == "Selected1stRiserTab"
                    puts "onMouseMove, state = #{@state}, centerline_point = #{@centerline_point}"

                    @q   = @centerline_point
                    @q.z = 0.0
                    @qs = view.screen_coords(@centerline_point)
                    @ip.pick(view,@qs.x, @qs.y)
                    @ph = view.pick_helper
                    npick = @ph.do_pick(@qs.x, @qs.y)
                    @position_2 = @ip_xform * @ip.position
                    puts "onMouseMove-ExistingRiserTab, position_2 = #{@position_2}"
                    if npick <= 0
                        return
                    else
                        puts "onMouseMove, state = {@state}, npick = #{npick}"
                        @base_data_2nd = Zone.base_path?(@ph)
                        base     = @base_data_2nd[0]
                        facecode = @base_data_2nd[1]
                        slice_index = (facecode /100.0).floor
                        m           = facecode - slice_index * 100
                        puts "add2ndrisertab.onMouseMove, Selected1sRiserTab, facecode = #{facecode}"
                        side = @primary_risertab.side
                        begin
                            @secondary_risertab = 
                                       base.create_risertab(
                                               @position_2, slice_index, side,
                                               false,       @primary_risertab)
                        rescue => ex
                            puts ex.to_s
                            trace = ex.backtrace
                            trace.each{ |s| puts s}
                            Sketchup.active_model.tools.pop_tool
                        end
                        puts @secondary_risertab.to_s(2)
                        reset_camera(view, @eye, @target, @up)
                        view.invalidate
                        @state = "OnTarget2ndRiserTab"
                    end
                end
            end # end onMouseMove

            puts "AddRiserTab-ExistingRiserTab, defining onLeftButtonDown"
            if @onLButtonDown_defined
                undef onLButtonDown
            end
            def onLButtonDown(flags, x, y, view)
                @onLButtonDown_defined = true
                if @state == "OnTarget1stRiserTab" 
                    puts "addrisertab.onLButtonDown, state = #{@state}, x = #{x}, y = #{y}"
                        puts @primary_risertab.class
                    @centerline_point = @primary_risertab.centerline_point
                    puts "onLButtonDown, state = #{@state}, centerline_point = #{@centerline_point}"
                    lower_camera(view, @centerline_point.z - 1.0)
                    @state = "Selected1stRiserTab"
                end
            end
            def lower_camera(view, z)
                result = UI.messagebox("Do want to lower camerap?", MB_YESNOCANCEL)
                if result == IDYES
                    camera = view.camera
                    eye = camera.eye
                    target = camera.target
                    target = [target.x, target.y, 2.0]
                    eye = [eye.x, eye.y, z]
                    up = camera.up
                    camera.set(eye, target, up)
                    view.camera = camera
                    view.invalidate

                elsif result == IDCANCEL
                    return nil
                end
                return view
            end
            def reset_camera(view, eye, target, up)
                view.camera.set(eye, target, up)
            end
            #end of ExistingRiserTab
        elsif @build_mode == "NearestSectionBoundary"
            @on_target = false
            puts "AddRiserTab-NearestSectionBoundary, defining onMouseMove"
            if @onMouseMove_defined
                undef onMouseMove
            end
            def onMouseMove( flags, x, y, view)
                @onMouseMove_defined = true
                @ip.pick view, x, y
                @ph = view.pick_helper
                npick = @ph.do_pick(x, y)
                if npick <= 0
                    @on_target = false
                    @cursor_id = @cursor_looking
                    return
                else
                    @base_data = Zone.base_path?(@ph)
                    if @base_data
                        @base_data_0 = @base_data
                        @position_1 = @ip_xform * @ip.position
                        @cursor_id = @cursor_on_target
                        @on_target = true
                    end
                end
            end # end onMouseMove

            puts "AddRiserTab-NearestSectionBoundary, defining onLeftButtonDown"
            if @onLButtonDown_defined
                undef onLButtonDown
            end
            def onLButtonDown(flags, x, y, view)
                @onLButtonDown_defined = true
                if !@on_target then return end
                base          = @base_data_0[0]
                face_code     = @base_data_0[1]
                slice_index_t = (face_code/100.0).floor
                m_t           = face_code - 100 * slice_index_t
                side = "right"
                if m_t == 0 || m_t == 1
                    side = "left"
                end
                slice_index_s = base.slices.section_slice_index(@position_1, slice_index_t)
                inline_point  = base.slices.inline_point(slice_index_s)
                begin
                    risertab = base.create_risertab(inline_point, slice_index_s, side, true)
                    puts risertab.class
                rescue => ex
                    puts ex.to_s
                    trace = ex.backtrace
                    trace.each{ |s| puts s}
                    Sketchup.active_model.tools.pop_tool
                end
            end
            #end of NearestSectionBoundary
        end
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate AddRiserTab #{Time.now.ctime}"
        puts          "############################ deactivate AddRiserTab #{Time.now.ctime}"
        TrackTools.model_summary
        $logfile.flush
        Trk::restore_layer_state
        Section.set_class_defaults
        track_attributes = Sketchup.active_model.attribute_dictionary("SectionBuildDefaults")
        track_attributes.each_pair { |k, v| puts "\t #{k}    #{v}" }
    end

end #end of Class AddRiserTab
