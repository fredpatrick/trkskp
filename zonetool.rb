
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
        SKETCHUP_CONSOLE.show
        
        TrackTools.tracktools_init("ZoneTool")
        @on_target = false
        @displayit = true if @section_list
    end

    def activate
        puts "activate ZoneTool"
        $logfile.puts "################################### activate ZonesTool #{Time.now.ctime}"
        $logfile.puts "activate ZoneTool"
        @ip = Sketchup::InputPoint.new
        @drawn = false
        @menu_def = false
    end

    def deactivate(view)
        puts "deactivate ZoneTool"
        TrackTools.model_summary
         $logfile.puts "################################ deactivate ZoneTool #{Time.now.ctime}"
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)
        if npick > 0
            path = @ph.path_at(0)
            if !path[0].is_a? Sketchup::Group
                return false
            elsif path[0].name != "sections"
                return false
            end
            puts "onMouseMove, sections, npick = #{npick}"
            if !path[1].is_a? Sketchup::Group
                 return false
            elsif path[1].name != "section"
                return false
            end
            puts "got section"
            section_group = path[1]
            @section = Section.section(section_group.guid)
            @on_target = false
            if @section.type != "switch"
                @on_target = true
                zone_name = @section.zone_name
                @zone_found = Zone.zone(zone_name)
                if !@zone_found.nil?
                    puts "zone_found"
                    @zone_found.visible = true
                end
                puts "@menu_def = #{@menu_def}"
                if @menu_def == false
                    puts "make context menu"
                    make_context_menu
                end
                if !@zone_found.nil?
                    @zone_state = 0
                else
                    @zone_state = 1
                
                end
            end
        else
            @on_target = false
            if !@section.nil?
                #@section.outline_visible = false
            end
            @section = nil
            @zone_found = nil
            remove_context_menu
        end
    end

    def onLButtonDown(fags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        @ph.do_pick(x, y)
        entities = @ph.all_picked
        puts "onLButtonDown, entities.length #{entities.length}"
        $logfile.puts "onLButtonDown, entities.length #{entities.length}"
        entities.each_with_index do |e,i| 
            puts "  #{i} #{e.typename} " 
            $logfile.puts "  #{i} #{e.typename} " 
            if e.is_a? Sketchup::Group
                $logfile.puts "    #{e.name}"
                puts "    #{e.name}"
            end
        end 
        $logfile.flush
    end

    def onRButtonDown(flags, x, y, view)
        puts "onRButtonDown: #{Time.now.ctime}"
        puts "onRButtonDown: @zone_state #{@zone_state}"
    end

    def remove_context_menu
        if @menu_def
            undef getMenu
            @menu_def = false
            @itemp_new_id    = nil
            @itemp_report_id = nil
            @itemp_erase_id  = nil
        end
    end

    def make_context_menu
        def getMenu(menu, flags, x, y, view)
            puts "onMenu: #{Time.now.ctime}"
            puts "onMenu: @zone_state #{@zone_state}"
            @current_menu = menu
            @item_new_id = menu.add_item("New") {
                puts "Mode = New"
                if !@section.nil?
                   zone = Zone.factory(@section, view)
                end
                view.refresh
            }
            @item_report_id = menu.add_item("Report") {
                puts "Mode = Report"
                $rptfile = Zone.report_file
                Zone.report_summary
                Zone.report_switches
                Zone.report_by_zone
                if !$rptfile.nil?
                    $rptfile.flush
                end
            }
            @item_show_all_id = menu.add_item("Show All") {
                $logfile.puts "Zonetool.show all"
                Zone.zones.each { |z| z.visible= true}
                view.refresh
                $logfile.flush
            }
            @item_hide_all_id = menu.add_item("Hide All") {
                $logfile.puts "Zonetool.hide all"
                Zone.zones.each { |z| z.visible= false}
                view.refresh
                $logfile.flush
            }
            @item_erase_id = menu.add_item("Erase") {
                puts "Mode = Erase, @section #{@section}"
                if !@section.nil?
                    zone_name = @section.zone_name
                    puts "zone_name #{zone_name}"
                    if zone_name != "unassigned"
                        zone = Zone.zone(zone_name)
                        zone.erase
                        view.refresh
                    end
                end
                $logfile.flush
            }
            if @zone_state == 0
                menu.set_validation_proc(@item_new_id) { MF_GRAYED} 
                menu.set_validation_proc(@item_report_id) { MF_ENABLED} 
                menu.set_validation_proc(@item_erase_id) { MF_ENABLED} 
            elsif @zone_state == 1
                menu.set_validation_proc(@item_new_id) { MF_ENABLED} 
                menu.set_validation_proc(@item_report_id) { MF_GRAYED} 
                menu.set_validation_proc(@item_erase_id) { MF_GRAYED} 
            end
        end
        @menu_def = true
    end
end
