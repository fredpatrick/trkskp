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
require "#{$trkdir}/section.rb"

$exStrings = LanguageHandler.new("track.strings")

include Math

class AddSections

    def initialize
        TrackTools.tracktools_init("AddSections")
        $logfile.flush

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
        @ip_xform = Sections.sections_group.transformation.clone
        @ip_xform.invert!

        @cursor_id = @cursor_looking
        @istate = 0 
    end

    def onSetCursor
        if @cursor_id
            
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "############################# activate AddSections #{Time.now.ctime}"
        puts          "############################# activate AddSections #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        @ptLast = Geom::Point3d.new 1000, 1000, 1000

        @drawn = false
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate AddSections #{Time.now.ctime}"
        puts          "############################ deactivate AddSections #{Time.now.ctime}"
        TrackTools.model_summary
        $logfile.flush
        view.invalidate if @drawn
        Section.set_class_defaults
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        if npick > 0 
            path = @ph.path_at(0)
            section = Section.section_path?(path)
            cpt = nil
            if section
                tposition = @ip_xform * @ip.position
                cpt = section.closest_point(tposition)
            else
                cpt = look_for_intersection(@ph)
            end
            if  cpt.nil?
                if @menu_flg == true
                    undef getMenu
                    @cursor_id = @cursor_looking
                    @menu_flg = false
                end
            else
                $current_connection_point = cpt
                @cursor_id = @cursor_on_target
                if @menu_flg == false
                    make_context_menu
                    @menu_flg = true
                end
            end
        else
            if @menu_flg == true
                undef getMenu
                @cursor_id = @cursor_looking
                @menu_flg = false
            end
        end
    end # end onMouseMove

    def look_for_intersection (ph)
        edge1 = nil
        edge2 = nil
        cline = nil
        entities = ph.all_picked
        is = 0
        entities.each do |x|
            if x.is_a? Sketchup::ConstructionLine
                if cline.nil? 
                    cline = [x.position, x.direction]
                    is += 1
                end
            elsif x.is_a? Sketchup::Edge
                if edge1.nil?
                    edge1 = x
                else
                    edge2 = x
                end
                is += 1
            end
        end
        if is == 2 || is == 3
            ve = edge1.line[1]
            normal = ve.normalize
            pt = Geom.intersect_line_line( cline, edge1.line)
            if !pt.nil?
                cpt = StartPoint.new(pt, normal)
                return cpt
            end
        end
        return nil
    end # end of look_for_intersection

    def make_context_menu
        def getMenu(menu)
            menu.add_item("Add Curved") {
                build_section("curved")
            }
            menu.add_item("Add Straight") {
                build_section("straight")
            }
            menu.add_item("Add Switch") {
                build_section("switch")
            }
            menu.add_item("Close") {
                puts "onMouseMove-Close, deactivating conext menu"
                undef getMenu
                @cursor_id = @cursor_looking
                @menu_flg = false
            }
        end
    end

    def build_section(type)
        $repeat = -1
        while $repeat != 0
            $logfile.puts "tracktool.build_section, type = #{type}"
            TrackTools.model_summary
            s = Section.factory($current_connection_point, 
                            type)
            if s.nil?
                break
            end
            if $current_connection_point.guid != ""
                @info_data = s.info($current_connection_point)
                @info_flg  = true
            else
                @info_flg = false
            end
            $repeat = $repeat - 1
            @ph.view.refresh
        end
        @istate = 0
        @cursor_id = @cursor_looking
        undef getMenu
        @menu_flg = false
    end
end #end of Class AddSections
######################################################################### class Inventory
class Inventory

    def initialize

        puts "############################################################"

        Sections.load_sections

    end

    def activate
        puts "activate Inventory"
        Section.report_sections
    end

    def deactivate(view)
        puts "deactivate Inventory"
    end

end
