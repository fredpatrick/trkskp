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

$exStrings = LanguageHandler.new("track.strings")

include Math
class ZoneTool
    def initialize
        TrackTools.tracktools_init("ZoneTool")
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
        $logfile.puts "################################### activate ZoneTool #{Time.now.ctime}"
        puts          "################################### activate ZoneTool #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @drawn = false
        @menu_flg = false
    end

    def deactivate(view)
        TrackTools.model_summary
        $logfile.puts "################################ deactivate ZoneTool #{Time.now.ctime}"
        puts          "################################ deactivate ZoneTool #{Time.now.ctime}"
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)
        if npick > 0
            path = @ph.path_at(0)
            section = Section.section_path?(path)
            if section.nil? 
                return
            end
            @section = section
            if @section.type != "switch"
                zone_name = @section.zone_name
                @zone_found = Zones.zone(zone_name)
                if !@zone_found.nil?
                    @zone_found.visible = true
                end
                if @menu_flg == false
                    make_context_menu
                end
                if !@zone_found.nil?
                    @zone_state = 0
                else
                    @zone_state = 1
                
                end
            end
        else
            @section = nil
            @zone_found = nil
            remove_context_menu
        end
    end

    def remove_context_menu
        if @menu_flg
            undef getMenu
            @menu_flg = false
            @item_new_id    = nil
            @item_report_id = nil
            @item_erase_id  = nil
            @cursor_id = @cursor_looking
        end
    end

    def make_context_menu
        def getMenu(menu, flags, x, y, view)
            @current_menu = menu
            @item_new_id = menu.add_item("New Zone") {
                if !@section.nil?
                   zone = Zones.factory(@section, view)
                end
                view.refresh
            }
            @item_delete_id = menu.add_item("Delete Zone") {
                if !@section.nil?
                    zone_name = @section.zone_name
                    if zone_name != "unassigned"
                        zone = Zones.zone(zone_name)
                        Zones.delete_zone(zone_name)
                        view.refresh
                    end
                end
                $logfile.flush
            }
            @item_report_id = menu.add_item("Report") {
            }
            if @zone_state == 0
                menu.set_validation_proc(@item_new_id) { MF_GRAYED} 
                menu.set_validation_proc(@item_report_id) { MF_ENABLED} 
                menu.set_validation_proc(@item_delete_id) { MF_ENABLED} 
            elsif @zone_state == 1
                menu.set_validation_proc(@item_new_id) { MF_ENABLED} 
                menu.set_validation_proc(@item_report_id) { MF_GRAYED} 
                menu.set_validation_proc(@item_delete_id) { MF_GRAYED} 
            end
        end
        @menu_flg = true
        @cursor_id = @cursor_on_target
    end

    def ZoneTool.testreport 
        Zones.report_summary
    end
end

################################################################# ExportZoneReport

class ExportZoneReport
    def initialize
        TrackTools.tracktools_init("ExportZoneReport")
    end


    def activate
        $logfile.puts "########################### activate ExportZoneReport #{Time.now.ctime}"
        puts          "########################### activate ExportZoneReport #{Time.now.ctime}"
        puts "Mode = Report"
        $rptfile = Zones.report_file
        Zones.report_summary
        Zones.report_switches
        Zones.report_by_zone
        if !$rptfile.nil?
            $rptfile.flush
        end
    end

    def deactivate(view)
        $logfile.puts "######################### deactivate ExportZoneReport #{Time.now.ctime}"
        puts          "######################### deactivate ExportZoneReport #{Time.now.ctime}"
        $logfile.flush
    end
end

################################################################### AddVertexData

class AddVertexData
    def initialize
        TrackTools.tracktools_init("AddVertexData")
    end

    def activate
        $logfile.puts "########################### activate AddVertexData #{Time.now.ctime}"
        puts          "########################### activate AddVertexData #{Time.now.ctime}"
        Zones.add_vertex_data
    end

    def deactivate(view)
        $logfile.puts "########################### deactivate AddVertexData #{Time.now.ctime}"
        puts          "########################### deactivate AddVertexData #{Time.now.ctime}"
    end
end

################################################################### ExportVertexData

class ExportVertexData
    def initialize
        TrackTools.tracktools_init("ExportVertexData")
    end

    def activate
        $logfile.puts "########################### activate ExportVertexData #{Time.now.ctime}"
        puts          "########################### activate ExportVertexData #{Time.now.ctime}"
        Zones.export_vertex_data
    end

    def deactivate(view)
        $logfile.puts "########################## deactivate ExportVertexData #{Time.now.ctime}"
        puts          "########################## deactivate ExportVertexData #{Time.now.ctime}"
    end
end

################################################################### DeleteVertexData

class DeleteVertexData
    def initialize
        TrackTools.tracktools_init("DeleteVertexData")
    end

    def activate
        $logfile.puts "########################### activate DeleteVertexData #{Time.now.ctime}"
        puts          "########################### activate DeleteVertexData #{Time.now.ctime}"
        Zones.delete_vertex_data
    end

    def deactivate(view)
        $logfile.puts "########################## deactivate DeleteVertexData #{Time.now.ctime}"
        puts          "########################## deactivate DeleteVertexData #{Time.now.ctime}"
    end
end
