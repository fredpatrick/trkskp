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
require "#{$trkdir}/base.rb"
require "#{$trkdir}/riser.rb"
require "#{$trkdir}/trk.rb"

class AddRiser
    def initialize
        puts "AddRiserConnector.initialize"
        test_rotate_code
        TrackTools.tracktools_init("AddRiser")

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
    end

    def onSetCursor
        if @cursor_id
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "########################### activate AddRiser #{Time.now.ctime}"
        puts          "########################### activate AddRiser #{Time.now.ctime}"
        @defaults = Hash.new
        read_defaults
        @ip_xform = $zones.zones_group.transformation.clone
        @ip_xform.invert!
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        save_layer_state
        @primary_riserconnector = nil
        set_required_definitions
        @riser_defs = Hash.new
        rcp_opts, rcp_defs = filter_definitions_by_type("risercraddle_p")
        rcs_opts, rcs_defs = filter_definitions_by_type("risercraddle_s")
        rbt_opts, rbt_defs = filter_definitions_by_type("riserbase_t")
        rbb_opts, rbb_defs = filter_definitions_by_type("riserbase_b")
        prompts = ["PrimaryConnector", "SecondaryConnector", "TopBase", "BottomBase",
                   "Pick_Modes", "StopAfterBuild"] 
        defaults = ["", "", "", "", "", "nearest_section", "No"]
        tlcs = [rcp_opts, rcs_opts, rbt_opts,rbb_opts, 
                "nearest_section|pick position", "No|Yes"]
        title = "Riser Definitions"
        results = UI.inputbox(prompts, defaults, tlcs, title)
        rcp_nam, rcs_nam, rbt_nam, rbb_nam, @pick_mode, @stop_after_build = results
        @riser_defs["risercraddle_p"] = Sketchup.active_model.definitions[rcp_nam]
        @riser_defs["risercraddle_s"] = Sketchup.active_model.definitions[rcs_nam]
        @riser_defs["riserbase_t"]    = Sketchup.active_model.definitions[rbt_nam]
        @riser_defs["riserbase_b"]    = Sketchup.active_model.definitions[rbb_nam]

        @riser_defs.each_pair { |k,v| puts sprintf("%-15s - %-12s\n", k, v.name) } 

        @cursor_id      = @cursor_looking
        @state          = "looking"
        @on_target      = false
        @connector_type = ""
    end

    def set_required_definitions
        @def_types = Trk.find_definition_types
        #@def_types.each_with_index { |t,i| puts "set_required_definitions, i = #{i}, #{t}" }
    end

    def read_defaults
        @defaults_filnam = Trk.make_filename("addriser.dflt")
        return if !File.exist?(@defaults_filnam)
        lines = IO.readlines(@defaults_filnam)
        lines.each do |l|
            words = l.split
            type  = words[0]
            if type == "Defaults"
                words.delete_at(0)
                key, value = words
                @defaults[key] = value
            end
        end
    end

    def write_defaults
        puts "addriser.defaults"
        @defaults.each_pair         { |k,v| puts "addriser.defaults #{k}  #{v}" }
        dfltfil   = File.open(@defaults_filnam, "w+")
        @defaults.each_pair         { |k,v| dfltfil.puts "Defaults #{k}  #{v}" }
        dfltfil.close
    end

    def filter_definitions_by_type(type)
        opts = nil
        defs = Hash.new
        Sketchup.active_model.definitions.each do |d|
            if !d.group?
                if type == d.get_attribute("TrkDefinitionAttrs", "definition_type")
                    defs[d.name] = d
                    if opts.nil?
                        opts = d.name
                    else
                        opts += "|" + d.name
                    end
                end
            end
        end
        return opts, defs
    end

    def deactivate(view)
        $logfile.puts "######################## deactivate AddRiser #{Time.now.ctime}"
        puts          "######################## deactivate AddRiser #{Time.now.ctime}"
        $logfile.flush
        write_defaults
        restore_layer_state
    end

    def onMouseMove( flags, x, y, view)
        pick_helper = nil
        npick       = 0
        @ip.pick view, x, y
        pick_helper   = view.pick_helper
        npick         = pick_helper.do_pick(x, y, 1.0)
        pick_location = @ip_xform * @ip.position

        if npick > 0
            #Trk.list_pick_paths(pick_helper)
            @base, @basedata = identify_target(pick_helper, pick_location, @pick_mode)

            if @base
                @cursor_id = @cursor_on_target
                @on_target = true
                @target = "base"
                @connector_type = "primary"
            else
                @on_target = false
                @connector_type = ""
                @cursor_id = @cursor_looking
            end
        else
            @on_target = false
            @connector_type = ""
            @cursor_id = @cursor_looking
        end
    end

    def onLButtonDown(flags, x, y, view)
        return if !@on_target
        puts @base.basedata_to_s(@basedata,1)
        begin
            attach_point = @basedata["attach_point"]
            @riser = $risers.create_new_riser(@base, @basedata, @riser_defs, @stop_after_build)
        rescue => ex
            puts ex.to_s
            $logfile.puts ex.to_s
            trace = ex.backtrace
            trace.each{ |s|
                puts s
                $logfile.puts s
            }
            Sketchup.active_model.tools.pop_tool
        end
        puts "onLButtonDown, connector created, back to looking"
        @on_target = false
        @cursor_id = @cursor_looking
        @connector_type = ""
        slice_index     = @basedata["slice_index"]
        q               = @basedata["centerline_point"]
        slope           = @basedata["slope"]
        jmin            = @base.slices.secondary_centerline_point(q, slice_index, slope)
        section         = @base.slices.section(slice_index)
        section_index_z = section.section_index_z
        puts "addriser, @base.spiral = #{@base.spiral}"
        if @base.spiral 
            if @base.section_in_spiral?(section) && jmin != -1
                
                ans = UI.messagebox("Do you want to add secondary_riserconnector?", MB_YESNO)
                if ans == IDYES
                    
                    rc_opts, rc_defs = filter_definitions_by_type(@rc_type)
                    tlcs = [rc_opts]
                    results = UI.inputbox(["RiserConnectorDefs"], [" "], tlcs, 
                                              "Secondary _RiserConnector")
                    rc_name = results[0]
                    rc_def  = rc_defs[rc_name]
                    @riser.add_secondary(@riser_defs)
                end
            end
        end
    end

    def identify_target(pick_helper, pick_location, pick_mode)
        base_group     = nil
        skins_group    = nil
        facecode       = nil
        pick_helper.count.times do |n|
            path = pick_helper.path_at(n)
            path.each do  |e|
                if e.is_a? Sketchup::Group
                    if e.name == "base"
                        base_group = e                          # base_group is always defined 
                        base       = Base.base(base_group.guid) # because "base" always comes 
                        next                                    # first in path
                    elsif e.name == "skins"
                        skins_group = e
                        next
                    elsif e.name == "slices"
                        break
                    end
                elsif ((e.is_a? Sketchup::Face) || (e.is_a? Sketchup::Edge)) && skins_group
                    puts "identify_target, skins_group is nil" if skins_group.nil?
                    facecode = e.get_attribute("FaceAttributes", "face_code")
                    break if facecode
                end
            end
            if facecode
                base     = Base.base(base_group.guid)
                basedata = base.slices.new_basedata(pick_location, facecode, pick_mode)

                return [base, basedata]
            end
        end
        return nil
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

    def test_rotate_code
        source_xline  = Geom::Vector3d.new(1.0, 0.0, 0.0)
        source_normal = Geom::Vector3d.new(0.0, 0.0, 1.0)
        source_point  = Geom::Point3d.new( 0.3, 0.0, 0.0)
        12.times do |n|
            theta_d = n * 30.0
            theta_r = theta_d.degrees
            target_xline = Geom::Vector3d.new(Math.cos(theta_r), Math.sin(theta_r), 0.0)
            target_point = Geom::Point3d.new( 0.3 * Math.cos(theta_r), 0.3 * Math.sin(theta_r), 0.0)

            cos = source_xline.dot(target_xline)
            sin = (source_xline.cross(target_xline)).z
            angle = Math.atan2(sin, cos)
            xform_rotation = Geom::Transformation.rotation(source_point, source_normal, angle)
            xform_translation = Geom::Transformation.translation(target_point - source_point)
            xform = xform_translation * xform_rotation
            v     = source_xline.transform(xform)
            puts sprintf("%4d %10.6f %10.6f %10.6f %10.6f %10.6f %10.6f", 
                                    n, theta_d, cos, sin, angle, v.x, v.y)
        end
    end
end        #end of class AddRiser
