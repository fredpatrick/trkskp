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
require "#{$trkdir}/zone.rb"
require "#{$trkdir}/switches.rb"

$exStrings = LanguageHandler.new("track.strings")

include Math

class AddSections

    def initialize
        puts "AddSections.initialize"
        TrackTools.tracktools_init("AddSections")

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
#       if !TrackTools.tracktools_init("AddSections")
#           puts "tracktools_init failed"
#           return
#       end
        $logfile.puts "############################# activate AddSections #{Time.now.ctime}"
        $logfile.flush
        puts          "############################# activate AddSections #{Time.now.ctime}"
        @ip_xform = $zones.zones_group.transformation.clone
        @ip_xform.invert!
        Section.get_class_defaults
        puts "AddSections.activate, SectionBuildDefaults"
        track_attributes = Sketchup.active_model.attribute_dictionary("SectionBuildDefaults")
        track_attributes.each_pair { |k, v| puts "\t #{k}    #{v}" }
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
        track_attributes = Sketchup.active_model.attribute_dictionary("SectionBuildDefaults")
        track_attributes.each_pair { |k, v| puts "\t #{k}    #{v}" }
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        if npick > 0 
#           allp = @ph.all_picked
#           puts "npick = #{npick}"
#           allp.each do |e|
#               puts e.typename
#           end
            
            path = @ph.path_at(0)
            section = Section.section_path?(path)
            cpt = nil
            if section
                tposition = @ip_xform * @ip.position
                #puts "AddSection.onMouseMove, tposition = #{tposition.to_s}"
                cpt = section.closest_point(tposition)
                if cpt.nil?
                    #puts "AddSections.onMouseMove, closest_point returned nil"
                else
                    #puts cpt.to_s
                end
            else
                cpt = look_for_intersection(@ph)
            end
            if  cpt.nil?
                if @menu_flg == true
                    undef getMenu
                    @cursor_id = @cursor_looking
                    @menu_flg = false
                    define_onRButtonDown
                end
            else
                @section = section
                $current_connection_point = cpt
                #puts "AddSections.onMouseMove, current_connection_point,menuflg = #{@menu_flg}"
                @cursor_id = @cursor_on_target
                if @menu_flg == false
                    undef onRButtonDown
                    make_context_menu
                    @menu_flg = true
                end
            end
        else
            if @menu_flg == true
                undef getMenu
                @cursor_id = @cursor_looking
                define_onRButtonDown
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
            menu.add_item("Erase Selection") {
                erase_section
            }
            menu.add_item("Close") {
                puts "onMouseMove-Close, deactivating conext menu"
                undef getMenu
                @cursor_id = @cursor_looking
                define_onRButtonDown
                @menu_flg = false
            }
        end
    end

    def build_section(new_section_type)
        ccpt = $current_connection_point
        puts "AddSections.build_section,####################################################" +
                       "#  #{new_section_type}"
        $logfile.puts "AddSections.build_section,##########################################" +
                       "###########  #{new_section_type}"
        current_zone = $zones.get_zone($current_connection_point, new_section_type)
        if ( new_section_type == "switch" )
            parent = $switches
        else
            parent = current_zone
        end
        $repeat = -1
        new_section = nil
        while $repeat != 0
            puts "tracktool.build_section, new_section_type = #{new_section_type}"
            $logfile.puts "tracktool.build_section, new_section_type = #{new_section_type}"
            TrackTools.model_summary
            new_section = parent.add_section($current_connection_point, new_section_type)
            if new_section.nil?
                break
            end
            if $current_connection_point.guid != ""
                @info_data = new_section.info($current_connection_point)
                @info_flg  = true
            else
                @info_flg = false
            end
            $repeat = $repeat - 1
            @ph.view.refresh
        end
        if ( new_section.nil? )
            if ( current_zone.section_count == 0 ) 
                $zones.delete_zone(current_zone.guid)
            end
            return nil               
        end
        puts "AddSections.build_section #################### #{new_section_type}"
        $logfile.puts "AddSections.build_section #################### #{new_section_type}"
        if ( new_section_type == "switch" && !current_zone.nil? )
            puts "Addsections.build_section, $current_connection_point.guid = "+
               "#{ccpt.guid}, #{ccpt.tag}"
            $logfile.puts "Addsections.build_section, $current_connection_point.guid = "+
               "#{ccpt.guid}, #{ccpt.tag}"
            current_zone.end_zone(new_section, 
                                  ccpt.linked_connector.tag)
            puts current_zone.to_s("after end_zone-1")
            $logfile.puts current_zone.to_s("after end_zone-1")
        end
        new_section.connectors.each do |c|
            if ( !c.connected? )
                found_connector = $zones.look_for_connection(c)
                if ( !found_connector.nil? )
                    found_section = found_connector.parent_section
                    found_tag     = found_connector.tag
                    puts "Addsections.build_section, found connected section," +
                                 "type = #{found_connector.parent_section.section_type}"
                    $logfile.puts "Addsections.build_section, found connected section," +
                                 "type = #{found_connector.parent_section.section_type}"
                    if ( new_section.section_type == "switch" )
                        if ( found_section.section_type != "switch" )
                            found_zone = found_section.zone
                            found_zone.end_zone(new_section, found_connector.tag)
                            puts found_zone.to_s("after_end_zone-3")
                        end
                    else
                        if ( found_connector.parent_section.section_type == "switch" )
                            current_zone.end_zone(found_connector.parent_section, 
                                                  found_connector.tag)
                            puts current_zone.to_s("after end_zone-2")
                            $logfile.puts current_zone.to_s("after end_zone-2")
                        else
                            zoneb = found_connector.parent_section.zone
                            if ( current_zone.guid != zoneb.guid)
                                current_zone.merge_zone(zoneb)
                            end
                        end
                    end
                end
            end
        end
        if ( !current_zone.nil? )
            current_zone.traverse_zone
        end
            
        @istate = 0
        @cursor_id = @cursor_looking
        if @menu_flg
            undef getMenu
            @menu_flg = false
            define_onRButtonDown
        end
    end

    def erase_section
        if ( @section.nil? )
            return
        end
        if ( @section.section_type == "switch" )
            $switches.erase_switch(@section)
            @section = nil
            return
        end

        zone = @section.zone
        if ( zone.erase_section(@section) )    #erase_section returns true no sections remain
            $zones.delete_zone(zone.guid)
            Sketchup.active_model.selection.clear
            @section = nil
        end
    end

    def create_start_point
        prompts = [$exStrings.GetString("X"),
                   $exStrings.GetString("Y"),
                   $exStrings.GetString("Z"),
                   $exStrings.GetString("Azimuth"),
                   $exStrings.GetString("section_type")]
        values = [0.0, 0.0, 0.0, 0.0, ""]
        tlist  = ["",  "",  "",  "",  "curved|straight|switch"]
        title  = "StartPoint"
        results = inputbox(prompts, values, tlist, title)
        if ( not results ) then return end 
        x, y, z, azimuth, new_section_type = results
        pt     = Geom::Point3d.new(x, y, z)
        theta  = azimuth * PI / 180.0
        normal = Geom::Point3d.new(cos(theta), sin(theta), 0.0 )
        $current_connection_point = StartPoint.new(pt, normal)
        build_section(new_section_type)
        @cursor_id = @cursor_looking
    end

    def define_onRButtonDown
        #puts "define_onRButtonDown"
        def onRButtonDown(flags, x, y, view)
            create_start_point
        end
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
