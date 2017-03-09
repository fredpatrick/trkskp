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
require "#{$trkdir}/zone.rb"
require "#{$trkdir}/section.rb"

########################################################################## class Zones
##########################################################################
#
#

class Zones
    def initialize 
        @zones       = Hash.new
        Zone.init_class_variables
        Switches.init_class_variables
        Section.init_class_variables
        Connector.init_class_variables
        @zones_group = nil
        Sketchup.active_model.entities.each do |e|
            if ( e.is_a? Sketchup::Group )
                if ( e.name == "zones" )
                    @zones_group = e
                end
            end
        end
        if ( @zones_group.nil? )
            @zones_group = Sketchup.active_model.entities.add_group
            @zones_group.name = "zones"
            @zones_group.locked = true
            @zones_group.set_attribute("ZonesAttributes", "zone_count", 0)
            @zone_count = 0
            @outline_visible = true
            @zones_group.set_attribute("ZonesAttributes", "outline_visible", @outline_visible)
        else
            @zone_count = @zones_group.get_attribute("ZonesAttributes", "zone_count")
            @outline_visible = @zones_group.get_attribute("ZonesAttribute", "outline_visible")
        end

        @zones_group.entities.each do |e|
            if ( Zone.zone_group? e )
                zone = Zone.new(e)
                @zones[e.guid] = zone
            end
        end
        puts "Zones.initialize, @zone_count = #{@zone_count}"
    end

    def load_existing_zones       #this is separate from intialize because 
        @zones.each_value do |z|  #      section initializations may reference $zones
            z.load_existing_zone
            puts z.to_s("load_existing_zone")
        end
        set_outline_visibility
    end

    def get_zone(connection_point, new_section_type)
        if ( connection_point.is_a? StartPoint )
            if ( new_section_type == "switch" )
                return nil
            else
                zone = add_zone
                zone.load_new_zone(connection_point)
                puts zone.to_s("load_new_zone")
                return zone
            end
        else                                    # Connector
            parent_section = connection_point.parent_section
            if ( parent_section.section_type == "switch" )
                if ( new_section_type    == "switch" )
                    return nil
                else
                    puts "Zone.get_zone, adding zone"
                    zone = add_zone
                    zone.load_new_zone(connection_point)
                    puts zone.to_s("load_new_zone")
                    return zone
                end
            else
                return parent_section.zone
            end
        end
    end

    def add_zone
        puts "Zones.add_zone, @zone_count = #{@zone_count}"
        zone_group        = @zones_group.entities.add_group
        zone_group.name   = "zone"
        zone_group.locked = true
        zone_index        = @zone_count
        zone_name = sprintf("Z%05d", zone_index)
        zone_group.set_attribute("ZoneAttributes", "zone_index", zone_index)
        zone_group.set_attribute("ZoneAttributes", "zone_name", zone_name)

        zone            = Zone.new(zone_group)
        @zones[zone_group.guid] = zone
        @zone_count += 1
        @zones_group.set_attribute("ZonesAttributes", "zone_count", @zone_count)
        return zone
    end

    def look_for_connection( connector )
        parent_section = connector.parent_section
        guid = ""
        if ( parent_section.section_type != "switch" )
            guid = connector.parent_section.zone.guid
        end
        @zones.each_value do |z|
            if ( z.guid != guid )
                found_connector = z.look_for_connection(connector)
                if ( !found_connector.nil? )
                    return found_connector
                end
            end
        end
        found_connector = $switches.look_for_connected( connector)
        if ( !found_connector.nil? )
            return found_connector
        end
        return nil
    end

    def zones_group
        return @zones_group
    end

    def zone( zone_guid )
        return @zones[zone_guid]
    end

    def delete_zone (guid)
        zone = @zones[guid]
        zone.zone_group.erase!
        @zones.delete guid
    end
    
    def remove_zone_entry(zone)
        @zones.delete zone.guid
    end

    def clense_after_explode                  # Assumes that zones_group.entities should only
                                              # contain zone groups
        @zones_group.entities.each do |e|
            if (!Zone.zone_group?(e) )
                e.erase!
            end
        end
    end
                
    def toggle_visibility
        vmenu = UI.menu("view")
        if ( @outline_visible )
            @outline_visible = false
            vmenu.set_validation_proc($view_zones_id) { MF_UNCHECKED }
        else
            @outline_visible = true
            vmenu.set_validation_proc($view_zones_id) { MF_CHECKED }
        end
        @zones.each_value do |z|
            z.visible (@outline_visible)
        end
        @zones_group.set_attribute("ZonesAttributes", "outline_visible", @outline_visible)
    end
    
    def set_outline_visibility
        vmenu = UI.menu("View")
        vmenu.set_validation_proc($view_zones_id) { MF_ENABLED }

        if ( !@outline_visible )
            vmenu.set_validation_proc($view_zones_id) { MF_UNCHECKED }
        else
            vmenu.set_validation_proc($view_zones_id) { MF_CHECKED }
        end
        @zones.each_value do |z|
            z.visible (@outline_visible)
        end
    end

    def export_layout_data
        model_path = Sketchup.active_model.path
        if model_path == ""
            return nil
        end
        #vtxdir = File.dirname(model_path) + '/'
        vtxdir = "/Users/fredpatrick/wrk/cfg/"
        model_basename = File.basename(model_path, '.skp')
        #filename = UI.savepanel("Save Vertex File", vtxdir, model_basename + '.vtx')
        filename = vtxdir + model_basename + '.vtx'
        if filename.nil?
            return nil
        end
        vtxfile = File.open(filename, "w")
        @zones.values.each { |z| 
            puts "Zones.export_layout_data, zone_name = #{z.zone_name}"
            z.export_layout_slices(vtxfile) 
        }
        $switches.export_layout_slices(vtxfile)
    end

#################################################################Zones.reports
    def report_file
        puts "Zones.report_file"
        model_path = Sketchup.active_model.path
        if model_path == ""
            return nil
        end
        #rptdir = File.dirname(model_path) + '/'
        rptdir = "/Users/fredpatrick/wrk/cfg/"
        model_basename = File.basename(model_path, '.skp')
        #filename = UI.savepanel("Save Report File", rptdir, model_basename + '.rpt')
        filename = rptdir + model_basename + '.rpt'

        if filename.nil?
            return nil
        end
        puts filename
        return File.open(filename, "w")
    end

    def report_by_zone
        @zones.values.each { |z| z.report_sections }
    end

    def report_summary
  #                 0123456789012345678901234567890123456789012345678901234567890123456789
        hdr_txt1 = " zone_name           closed?   zone_type     # of   " + 
                                                                        "     Start    End"
        hdr_txt2 = "                                              sections " +
                                                                       "     Switch   Switch"
        if $rptfile.nil?
            puts "\n\n    Report Summary Model = #{$model_basename} #{Time.now.ctime}"
            puts hdr_txt1
            puts hdr_txt2
        else
            $rptfile.puts "\n\n    Report Summary Model = #{$model_basename} #{Time.now.ctime}"
            $rptfile.puts hdr_txt1
            $rptfile.puts hdr_txt2
        end
        puts hdr_txt1
        puts hdr_txt2
        @zones.values.each do |z|
            start_switch = $switches.switch(z.start_switch_guid)
            slabel = ""
            if ( !start_switch.nil? )
                slabel = start_switch.switch_name + "-" + z.start_switch_tag
            end
            end_switch = $switches.switch(z.end_switch_guid)
            elabel = ""
            if ( !end_switch.nil? )
                elabel = end_switch.switch_name + "-" + z.end_switch_tag
            end
            str = sprintf("%-19s %5s   %10s  %4d    %10s       %10s\n",
                        z.zone_name, z.closed?, z.zone_type, z.section_count, slabel, elabel)
            puts str
            $rptfile.puts str

        end
    end
end

################################################################### ExportLayoutData

class ExportLayoutData
    def initialize
        TrackTools.tracktools_init("ExportLayoutData")
    end

    def activate
        $logfile.puts "########################### activate ExportLayoutData #{Time.now.ctime}"
        puts          "########################### activate ExportLayoutData #{Time.now.ctime}"
        $zones.export_layout_data
    end

    def deactivate(view)
        $logfile.puts "########################## deactivate ExportLayoutData #{Time.now.ctime}"
        puts          "########################## deactivate ExportLayoutData #{Time.now.ctime}"
    end
end

################################################################### UpdateLayoutData

class UpdateLayoutData
    def initialize
        TrackTools.tracktools_init("UpdateLayoutData")
    end

    def activate
        $logfile.puts "########################### activate UpdateLayoutData #{Time.now.ctime}"
        puts          "########################### activate UpdateLayoutData #{Time.now.ctime}"
        Section.update_layout_data
    end

    def deactivate(view)
        $logfile.puts "########################## deactivate UpdateLayoutData #{Time.now.ctime}"
        puts          "########################## deactivate UpdateLayoutData #{Time.now.ctime}"
    end
end

################################################################# ExportLayoutReport

class ExportLayoutReport
    def initialize
        TrackTools.tracktools_init("ExportLayoutReport")
    end


    def activate
        $logfile.puts "######################### activate ExportLayoutReport #{Time.now.ctime}"
        puts          "######################### activate ExportLayoutReport #{Time.now.ctime}"
        puts "Mode = Report"
        $rptfile = $zones.report_file
        $zones.report_summary
        $switches.report_switches
        $zones.report_by_zone
        if !$rptfile.nil?
            $rptfile.flush
        end
    end
end
