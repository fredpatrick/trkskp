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

module TrackTools

$trkdir = "/Users/fredpatrick/wrk/trkskp"
puts $trkdir
#require "#{$trkdir}/tracktool.rb"
require "#{$trkdir}/addsections.rb"
require "#{$trkdir}/zonetool.rb"
require "#{$trkdir}/trackedittool.rb"
require "#{$trkdir}/infotool.rb"
require "#{$trkdir}/testtool.rb"
require "#{$trkdir}/gates.rb"
require "#{$trkdir}/switch.rb"

def TrackTools.tracktools_init(tool_classname)
    model = Sketchup.active_model
    model_path = model.path
    if model_path == ""
        $model_basename = "unnamed"
        logpath = Dir.getwd + '/' + 'sketchup.log'
        puts logpath
        $logfile = File.open(logpath, "a")
    else
        $model_basename = File.basename(model_path, '.skp')
        puts "model_basename #{$model_basename}"
        model_dir = File.dirname(model_path)
        puts model_dir
        logpath = model_dir + '/' + $model_basename + '.log'
        puts logpath
        $logfile = File.open(logpath, "a")
    end
    puts "################################################################"
    puts "####################################### #{tool_classname}"
    puts "####################################### #{Time.now.ctime}"
    $logfile.puts "################################################################"
    $logfile.puts "####################################### #{tool_classname}"
    $logfile.puts "####################################### #{Time.now.ctime}"

    rendering_options = Sketchup.active_model.rendering_options
    rendering_options["EdgeColorMode"] = 0
    $logfile.puts "EdgeColorMode: #{rendering_options["EdgeColorMode"]}"
    #rendering_options.each_pair { |key, value| $logfile.puts "#{key} : #{value}" }
    TrackTools.model_summary
    $logfile.flush
    Sections.load_sections       # the order of the following 4 calls is important
    Section.connect_sections
    Gates.load_gates
    Zones.load_zones
    Switches.load_switches
    $track_loaded = true
    vmenu = UI.menu("View")
    vmenu.set_validation_proc($view_zones_id) { MF_ENABLED }
    vmenu.set_validation_proc($view_zones_id) { MF_CHECKED }
    $logfile.flush
end  # end tracktools_init

def TrackTools.model_summary
    model = Sketchup.active_model
    $logfile.puts " Model Summary"
    nsection = 0
    nzone    = 0
    model.entities.each do |e|
        if e.is_a? Sketchup::Group
            if    e.name == "sections"
                e.entities.each do |s|
                    if s.is_a? Sketchup::Group
                        if s.name == "section"
                            nsection += 1
                        end
                    end
                end
            elsif e.name == "zone"
                nzone += 1
            end
        end
    end
    $logfile.puts "    nsection = #{nsection}"
    $logfile.puts "    nzone    = #{nzone}"
end
$track_loaded = false
SKETCHUP_CONSOLE.show
    puts "################################################################"
    puts "## To CREATE a New Section using TrackTools:                  ##"
    puts "##    (1) Sketchup->Draw->Track->Build                        ##"
    puts "##    (2) Left click with mouse                               ##"
    puts "##            Cursor becomes target with red center           ##"
    puts "##    (3) Move cursor over starting point (see below)         ##"
    puts "##            Cursor becomes target with green center         ##"
    puts "##    (4) Right click for context menu -> Add Curved          ##"
    puts "##                                     -> Add Straight        ##"
    puts "##                                     -> Add Switch          ##"
    puts "##                                     -> Close               ##"
    puts "##    Starting point is defined as:                           ##"
    puts "##         a) intersection of Edge with construction line     ##"
    puts "##      or b) open face of existing section or switch         ##"
    puts "################################################################"
    puts #trkdir

if( not $draw_tracktool_submenu_loaded )
    add_separator_to_menu("Draw")
    dmenu = UI.menu("Draw")
    $draw_submenu_track = dmenu.add_submenu($exStrings.GetString("Track"))
    $draw_tracktool_submenu_loaded = true
end

if( not $draw_tracktool_build_loaded )
    $draw_submenu_track.add_item("Add Sections") {
        Sketchup.active_model.select_tool AddSections.new
    }
    $draw_tracktool_build_loaded = true
end

if( not $draw_tracktool_inventory_loaded)
    $draw_submenu_track.add_item("Inventory") {
        Sketchup.active_model.select_tool Inventory.new
    }
    $draw_submenu_track.add_separator
    $draw_tracktool_inventory_loaded = true
end

if( not $draw_tracktool_zones_loaded )
    $draw_submenu_track.add_item("Zones") {
        Sketchup.active_model.select_tool ZoneTool.new
    }
    $draw_tracktool_zones_loaded = true
end

if( not $draw_tracktool_export_zones_report_loaded )
    $draw_submenu_track.add_item("ExportZoneReport") {
        Sketchup.active_model.select_tool ExportZoneReport.new
    }
    $draw_submenu_track.add_separator
    $draw_tracktool_export__zones_report_loaded = true
end

if( not $draw_tracktool_addvertexdata_loaded )
    $draw_submenu_track.add_item("AddVertexData") {
        Sketchup.active_model.select_tool AddVertexData.new
    }
    $draw_tracktool_addvertexdata_loaded = true
end

if( not $draw_tracktool_exportvertexdata_loaded )
    $draw_submenu_track.add_item("ExportVertexData") {
        Sketchup.active_model.select_tool ExportVertexData.new
    }
    $draw_tracktool_exportvertexdata_loaded = true
end

if( not $draw_tracktool_deletevertexdata_loaded )
    $draw_submenu_track.add_item("DeleteVertexData") {
        Sketchup.active_model.select_tool DeleteVertexData.new
    }
    $draw_tracktool_deletevertexdata_loaded = true
end

if( not $draw_tracktool_test_loaded )
    $draw_submenu_track.add_item("TestReport") {
        Sketchup.active_model.select_tool ZoneTool.testreport
    }
    $draw_tracktool_test_loaded = true
end


#if( not $draw_tracktool_edit_loaded)
#    $draw_submenu_track.add_item("Edit") {
#        Sketchup.active_model.select_tool TrackEditTool.new
#    }
#    $draw_tracktool_edit_loaded= true
#end
#
#if( not $draw_tracktool_info_loaded )
###    $draw_submenu_track.add_item("Info") {
#        Sketchup.active_model.select_tool InfoTool.new
#    }
#    $draw_tracktool_info_loaded = true
#end
#if( not $draw_testtool_loaded )
#    dmenu = UI.menu("Draw")
#    $draw_submenu_testtool = dmenu.add_item("TestTool") {
#        Sketchup.active_model.select_tool TestTool.new
#    }
#    $draw_testtool_loaded = true

if ( not $view_zones_loaded )
    vmenu = UI.menu("View")
    vmenu.add_separator
    $view_zones_id = vmenu.add_item("Zones") {
        Zones.toggle_visibility
    }
    vmenu.set_validation_proc($view_zones_id) { MF_GRAYED}
    $view_zones_loaded = true
end

end    # end module Sketchup::TrackTools
