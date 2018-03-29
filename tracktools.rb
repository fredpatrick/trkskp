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
require "#{$trkdir}/addsections.rb"
require "#{$trkdir}/addrisertab.rb"
require "#{$trkdir}/erasesectionrange.rb"
require "#{$trkdir}/editsections.rb"
require "#{$trkdir}/scanlayout.rb"
require "#{$trkdir}/editnames.rb"
require "#{$trkdir}/infotool.rb"
require "#{$trkdir}/testtool.rb"
#require "#{$trkdir}/gates.rb"
require "#{$trkdir}/switches.rb"
require "#{$trkdir}/risers.rb"
require "#{$trkdir}/zone.rb"

def TrackTools.tracktools_init(tool_classname)
    model_path = Sketchup.active_model.path
    puts "Sketchup.active_model.title = #{Sketchup.active_model.title}"
    puts "Sketchup.active_model.path  = #{Sketchup.active_model.path}"
    attrdicts = Sketchup.active_model.attribute_dictionaries
    attrdicts.each do |ad|
        puts ad.name
        ad.each_pair { |k, v| puts "\t #{k}    #{v}" }
    end
    TrackTools.create_directory_attributes

    puts "################################################################"
    puts "####################################### #{tool_classname}"
    puts "####################################### #{Time.now.ctime}"
    $logfile.puts "################################################################"
    $logfile.puts "####################################### #{tool_classname}"
    $logfile.puts "####################################### #{Time.now.ctime}"
    $logfile.flush
    Sketchup.active_model.add_observer(TrackModelObserver.new)
    rendering_options = Sketchup.active_model.rendering_options
    rendering_options["EdgeColorMode"] = 0
    $logfile.puts "EdgeColorMode: #{rendering_options["EdgeColorMode"]}"
    #rendering_options.each_pair { |key, value| $logfile.puts "#{key} : #{value}" }
    TrackTools.model_summary
    $logfile.flush
    $zones    = Zones.new
    $zones.load_existing_zones
    $switches = Switches.new
    Section.connect_sections
    $track_loaded = true
    $risers = Risers.new
    vmenu = UI.menu("View")
    vmenu.set_validation_proc($view_zones_id) { MF_ENABLED }
    vmenu.set_validation_proc($view_zones_id) { MF_CHECKED }
    $zones.print_zone_labels
end  # end tracktools_init

def TrackTools.create_directory_attributes
    battrs     = Sketchup.active_model.attribute_dictionary("DirectoryAttributes")
    bname      = "DirectoryAttributes"
    model_name = Sketchup.active_model.title
    
    if !battrs
        battrs = Sketchup.active_model.attribute_dictionary("DirectoryAttributes", true)
    end
    if model_name == ""  || battrs.length == 0
        model_name = "noname"
        @@home_directory  = ENV["HOME"]
        @@work_directory  = "wrk/skp"
        @@model_directory = ""

        prompts =["Model Name", "Home Directory", "Work Directory", "Model Directory"]
        title   = "Enter Base Attribute Values"
        okflg   = false
        while !okflg
            defaults = [model_name, @@home_directory, @@work_directory, @@model_directory]

            results = UI.inputbox(prompts, defaults, title)
            puts results
            model_name, @@home_directory, @@work_directory, @@model_directory = results

            okflg = true
            if  !Dir.exists?(@@home_directory)
                @@home_directory = "Invalid"
                okflg  = false
            end
            if !Dir.exists?(File.join(@@home_directory, @@work_directory))
                @@work_directory = "Invalid"
                okflg = false
            end
            if @@model_directory == ""
                @@model_directory = model_name
            end
        end
        Sketchup.active_model.set_attribute(bname, "home_directory",  @@home_directory)
        Sketchup.active_model.set_attribute(bname, "work_directory",  @@work_directory)
        Sketchup.active_model.set_attribute(bname, "model_directory", @@model_directory)
        model_dir = File.join(@@home_directory, @@work_directory, @@model_directory)
        if !Dir.exists?(model_dir)
            Dir.mkdir(model_dir)
        end
        skpfile = File.join(@@home_directory, @@work_directory, @@model_directory, 
                            model_name + ".skp")
        puts skpfile
        if !File.exists?(skpfile)
            puts "tracktools--- saving skpfile - #{skpfile}"
            Sketchup.active_model.save(skpfile)
        end
    else
        @@home_directory  = Sketchup.active_model.get_attribute(bname, "home_directory")
        @@work_directory  = Sketchup.active_model.get_attribute(bname, "work_directory")
        @@model_directory = Sketchup.active_model.get_attribute(bname, "model_directory")
    end
    $logfile = TrackTools.open_file(".log", "a")

    puts "TrackTools.tracktools_init, home_directory = #{@@home_directory}"
    puts "TrackTools.tracktools_init, work_directory = #{@@work_directory}"
    puts "TrackTools.tracktools_init, model_directory = #{@@model_directory}"
    $logfile.puts "TrackTools.tracktools_init, home_directory  = #{@@home_directory}"
    $logfile.puts "TrackTools.tracktools_init, work_directory  = #{@@work_directory}"
    $logfile.puts "TrackTools.tracktools_init, model_directory = #{@@model_directory}"
end

def TrackTools.open_file(type, mode)
    mdlnam = Sketchup.active_model.title
    return File.open(File.join(@@home_directory, @@work_directory, @@model_directory,
                           mdlnam+type), mode)
end

def TrackTools.working_path
    return File.join(@@home_directory, @@work_directory)
end

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
if( not $draw_tracktool_erasesectionrange_loaded )
    $draw_submenu_track.add_item("Erase Section Range") {
        Sketchup.active_model.select_tool EraseSectionRange.new
    }
    $draw_tracktool_erasesectionrange_loaded = true
end

if( not $draw_tracktool_createbase_loaded )
    $draw_submenu_track.add_item("Create Base") {
        Sketchup.active_model.select_tool CreateBase.new
    }
    $draw_tracktool_createbase_loaded = true
end

if( not $draw_tracktool_addrisertab_loaded )
    $draw_submenu_track.add_item("Add RiserTab") {
        Sketchup.active_model.select_tool AddRiserTab.new
    }
    $draw_tracktool_addrisertab_loaded = true
end

if( not $draw_tracktool_mangedefinitions_loaded )
    $draw_submenu_track.add_item("Manage Definitions") {
        Sketchup.active_model.select_tool ManageDefinitions.new
    }
    $draw_tracktool_mangedefinitions_loaded = true
end

if( not $draw_tracktool_addriser_loaded )
    $draw_submenu_track.add_item("Add Riser") {
        Sketchup.active_model.select_tool AddRiser.new
    }
    $draw_tracktool_addriser_loaded = true
end

if( not $draw_tracktool_editriserbase_loaded )
    $draw_submenu_track.add_item("Edit Riser Base") {
        Sketchup.active_model.select_tool EditRiserBase.new
    }
    $draw_tracktool_editriserbase_loaded = true
end

if( not $draw_track_editsections_loaded )
    $draw_submenu_track.add_item("Edit Sections") {
        Sketchup.active_model.select_tool EditSections.new
    }
    $draw_track_editsections_loaded = true
end

if( not $draw_track_scanlayout_loaded )
    $draw_submenu_track.add_item("Scan") {
        Sketchup.active_model.select_tool ScanLayout.new
    }
    $draw_track_scanlayout_loaded = true
end

if( not $draw_track_editnames )
    $draw_submenu_track.add_item("Edit Names") {
        Sketchup.active_model.select_tool EditNames.new
    }
    $draw_track_editnames_loaded = true
end

if( not $draw_tracktool_updatelayoutdata_loaded )
    $draw_submenu_track.add_separator
    $draw_submenu_track.add_item("Update Layout Data") {
        Sketchup.active_model.select_tool UpdateLayoutData.new
    }
    $draw_tracktool_updatelayoutdata_loaded = true
end

if( not $draw_tracktool_exportlayoutdata_loaded )
    $draw_submenu_track.add_separator
    $draw_submenu_track.add_item("Export Layout Data") {
        Sketchup.active_model.select_tool ExportLayoutData.new
    }
    $draw_tracktool_exportlayoutdata_loaded = true
end

if( not $draw_tracktool_export_layout_report_loaded )
    $draw_submenu_track.add_item("Export Layout Report") {
        Sketchup.active_model.select_tool ExportLayoutReport.new
    }
    $draw_tracktool_export__layout_report_loaded = true
end

if( not $draw_tracktool_inventory_loaded)
    $draw_submenu_track.add_item("Inventory") {
        Sketchup.active_model.select_tool Inventory.new
    }
    $draw_tracktool_inventory_loaded = true
end

if ( not $view_zones_loaded )
    vmenu = UI.menu("View")
    vmenu.add_separator
    $view_zones_id = vmenu.add_item("Zones") {
        $zones.toggle_visibility
    }
    vmenu.set_validation_proc($view_zones_id) { MF_GRAYED}
    $view_zones_loaded = true
end

end    # end module Sketchup::TrackTools

class TrackModelObserver < Sketchup::ModelObserver
    def onPostSaveModel(model)
        puts "TrackModelObserver.onPostSaveModel, title = #{model.title}"
    end
end
