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

include Math
include Trk

class Risers
    def initialize
        @risers = Hash.new
        @risers_group = nil
        Sketchup.active_model.entities.each do |e|
            if e.is_a? Sketchup::Group
                if e.name == "risers"
                    @risers_group = e
                    @risers_group.layer = "base"
                end
            end
        end
        if @risers_group.nil? 
            @risers_group      = Sketchup.active_model.entities.add_group
            @risers_group.name = "risers"
            @risers_group.description = "group risers"
            @risers_group.layer       = "base"
            @risers_group.make_unique
            @riser_count       = 0
            @risers_group.set_attribute("RisersAttributes", "riser_count", 0)
        else
            @riser_count       = @risers_group.get_attribute("RisersAttributes", 
                                                            "riser_count")
            @risers_group.entities.each do |e|
                if e.is_a? Sketchup::Group
                    if e.name == "riser"
                        riser =Riser.new("load", e)
                        @risers[e.guid] = riser
                    end
                end
            end
        end
    end

    def Risers.search_for_face(ph)
        #puts "Risers.search_for_face"
        pkn = ph.count
        instance = nil
        face     = nil
        pkn.times{ |n|
            looking_for_face = false
            path = ph.path_at(n)
            path.each_with_index{ |e,i| 
                if e.is_a? Sketchup::ComponentInstance
                    puts "Risers.search_for_face #{i}, name = #{e.name}, ComponentInstance"
                    instance = e
                elsif (e.is_a? Sketchup::Face) && instance
                    puts "Risers.search_for_face #{i}, Face"
                    e.vertices.each{ |v,i| puts "             #{i}, #{v.position}" }
                    puts "Risers.search_for_face, normal = #{e.normal}"
                    face = e
                end
            }
        }
        return face
    end

    def create_new_riser(risertab)
        riser_group      = @risers_group.entities.add_group
        riser_group.name = "riser"
        riser_group.set_attribute("RiserBaseAttributes", "complete", false)
        riser = Riser.new("build", riser_group, risertab)
        @risers[riser_group.guid] = riser
        return riser
    end
end

class AddRiser
    def initialize
        puts "AddRiser.initialize"
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
        @cursor_id = @cursor_looking
        @state     = "begin"
        @on_target = false
        make_context_menu
    end

    def onSetCursor
        if @cursor_id
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "############################# activate AddRiser #{Time.now.ctime}"
        puts          "############################# activate AddRiser #{Time.now.ctime}"
        @ip_xform = $zones.zones_group.transformation.clone
        @ip_xform.invert!
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        @ptLast = Geom::Point3d.new 1000, 1000, 1000
        save_layer_state

        #rstatus = AddRiser.member_defined?("onRButtonDown")
        #puts "addriser.activate, onRButtonDown = ${rstatus}"
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate AddRiser #{Time.now.ctime}"
        puts          "############################ deactivate AddRiser #{Time.now.ctime}"
        $logfile.flush
        restore_layer_state
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        if npick > 0
            if @state == "begin"
                risertab = Base.risertab_path?(@ph)
                if risertab
                    @risertab = risertab
                    @cursor_id = @cursor_on_target
                    @on_target = true
                    #test_for_onRButtonDown
                    make_context_menu
                    #AddRiser.member_defined?(:onRButtonDown)
                end
            end
        end
    end

    #def test_for_onRButtonDown
    #    status = AddRiser.member_defined?(:onRButtonDown)
    #    puts "addriser.test_for_onRButtonDown, defined = #{status}"
    #end
    
    def onLButtonDown(flags, x, y, view)
        puts "AddRiser, onLButtonDown"
        if @state == "begin" && @on_target
            if @risertab
                begin
                    @riser = $risers.create_new_riser(@risertab)
                    @cursor_id = @cursor_looking
                    @state     = "riser_created"
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
            end
        end
    end

    def make_context_menu
        def getMenu(menu)
            create_riser_id = menu.add_item("Creater Riser") {
                @mouse_mode = "looking_for_risertab"
            }
            edit_base_def_id = menu.add_item("Edit Base Def") {
                @mouse_mode = "not_looking"
                @riser.edit_base_def
            }
            add_riserbase_id = menu.add_item("Add RiserBase") {
                @mouse_mode = "not_looking" 
                @riser.create_riserbase_instance
            }
            finish_id = menu.add_item("Finish") {
                @mouse_mode = "not_looking" 
                @riser.create_insert
                @riser.move_to_risertab
            }
            if @state == "begin"
                menu.set_validation_proc(create_riser_id) {MF_ENABLED}
                menu.set_validation_proc(edit_base_def_id) {MF_ENABLED}
                menu.set_validation_proc(add_riserbase_id) {MF_GRAYED}
                menu.set_validation_proc(finish_id) {MF_GRAYED}
            elsif @state == "riser_created"
                menu.set_validation_proc(create_riser_id) {MF_GRAYED}
                menu.set_validation_proc(edit_base_def_id) {MF_ENABLED}
                menu.set_validation_proc(add_riserbase_id) {MF_ENABLED}
                menu.set_validation_proc(finish_id) {MF_GRAYED}
            elsif @state == "adding_bases"
                menu.set_validation_proc(create_riser_id) {MF_GRAYED}
                menu.set_validation_proc(edit_base_def_id) {MF_GRAYED}
                menu.set_validation_proc(add_riserbase_id) {MF_ENABLED}
                menu.set_validation_proc(finish_id) {MF_GRAYED}
            elsif @state == "bases_created"
                menu.set_validation_proc(create_riser_id) {MF_GRAYED}
                menu.set_validation_proc(edit_base_def_id) {MF_GRAYED}
                menu.set_validation_proc(add_riserbase_id) {MF_ENABLED}
                menu.set_validation_proc(finish_id) {MF_ENABLED}
            end

        end
    end
end        
