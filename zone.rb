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
require "#{$trkdir}/zones.rb"
require "#{$trkdir}/section.rb"


######################################################################## class Zone
########################################################################
##
##
class Zone
    def initialize(zone_group)
        @zone_group = zone_group
        @guid       = zone_group.guid
        @zone_index = zone_group.get_attribute("ZoneAttributes", "zone_index")
        @zone_name  = zone_group.get_attribute("ZoneAttributes", "zone_name")
        puts "Zone.initialize, zone_index = #{@zone_index}, zone_name = #{@zone_name}"
        @modified = true
        @uclist   = []
        @nuc      = 0
    end

    def load_existing_zone
        @zone_type         = @zone_group.get_attribute("ZoneAttributes", "zone_type")
        @connected         = @zone_group.get_attribute("ZoneAttributes", "connected")
        @start_switch_guid = @zone_group.get_attribute("ZoneAttributes", "start_switch_guid")
        @start_switch_tag  = @zone_group.get_attribute("ZoneAttributes", "start_switch_tag")
        @end_switch_guid   = @zone_group.get_attribute("ZoneAttributes", "end_switch_guid")
        @end_switch_tag    = @zone_group.get_attribute("ZoneAttributes", "end_switch_tag")
        @closed            = @zone_group.get_attribute("ZoneAttributes", "closed", false)

        @sections      = Hash.new
        @section_count = 0
        @zone_group.entities.each do |e|
            if ( e.is_a? Sketchup::Group )
                if ( e.name == "section" )
                    puts "Zone.load_existing_zone, e.guid = #{e.guid}"
                    section = Section.factory(e)
                    @sections[section.guid] = section
                    @section_count = @sections.length
                end
            end
        end
        @zone_group.set_attribute("ZoneAttributes", "section_count",     @section_count)
    end

    def zone_name
        return @zone_name
    end
    def zone_name=(znm)
        @zone_name = znm
        @zone_group.set_attribute("ZoneAttributes", "zone_name", @zone_name)
        @sections.each_value do |s|
            s.update_zone_dependencies
        end
    end

    def zone_index
        return @zone_index
    end
    def zone_type
        return @zone_type
    end
    def closed?
        return @closed
    end
    def start_switch_guid
        return @start_switch_guid
    end
    def start_switch_tag
        return @start_switch_tag
    end
    def end_switch_guid
        return @end_switch_guid
    end
    def end_switch_tag
        return @end_switch_tag
    end
    def section_count
        return @section_count
    end
    def guid
        return @guid
    end
    def zone_group
        return @zone_group
    end

    def load_new_zone(connection_point=nil)
        if ( connection_point.nil? )
            @start_switch_guid = ""
            @start_switch_tag  = ""
        elsif ( connection_point.is_a? StartPoint )
            @start_switch_guid = ""
            @start_switch_tag  = ""
        elsif ( connection_point.is_a? Connector )
            if (connection_point.parent_section.is_a? SwitchSection )
                @zone_type         = "sidetrack"
                @start_switch_guid = connection_point.parent_section.guid
                @start_switch_tag  = connection_point.tag
                if (@start_switch_tag == "") 
                    puts "Zone.load_new_zone, problem with connection_point.tag"
                    puts connection_point.to_s
                end
            else
                puts "Zone.load_new_zone, should not get here, connection point is not switch"
            end
        end
        @valid     = true
        @sections = Hash.new
        @section_count = 0
        @zone_group.set_attribute("ZoneAttributes", "section_count",     @section_count)
        set_zone_attributes(@start_switch_guid, @start_switch_tag, "", "")
    end

    def end_zone(switch, tag)
        set_zone_attributes(@start_switch_guid, @start_switch_tag,
                            switch.guid,        tag)
    end

    def add_section(connection_point, section_type)
        puts "Zone.add_section, section_type = #{section_type}"
        section_group = @zone_group.entities.add_group
        section_group.name = "section"
        section_group.locked = true
        section_group.set_attribute("SectionAttributes", "section_type", section_type)
        section_group.set_attribute("SectionAttributes", "zone_guid",    @guid)
        section = Section.factory(section_group, connection_point)
        if ( section.nil? )
            return nil
        end
        @sections[section.guid] = section
        @section_count = @sections.length
        @zone_group.set_attribute("ZoneAttributes", "section_count",     @section_count)
        @modified = true
        return section
    end

    def erase_section( section )
        puts "Zone.erase_section"
        section_type = []
        tag          = []
        guid         = []
        n            = 0
        switch_guid  = ""
        section.connectors.each do |c|
            if ( c.connected? ) 
                linked_section = c.linked_connector.parent_section
                section_type[n] = linked_section.section_type
                guid[n]         = c.linked_connector.guid
                tag[n]          = c.linked_connector.tag
                n               += 1
                puts "Zone.erase_section, n = #{n}, type = #{section_type[n]}," +
                                 " guid = #{guid[n]}, tag = #{tag[n]}"
                if (section_type[n] == "switch")
                    switch_guid = guid[n]
                end
                c.break_connection_link
            end
        end
        if (delete_section_group(section.section_group) == 0 )
            return true
        end

        if ( n == 2 )                     # if n==0 || n==1 do nothing
            if ( section_type[0] == "switch"  &&
                 section_type[1] == "switch"    )
                #do nothing
            elsif (switch_guid == @start_switch_guid )
                set_zone_attribute(@end_switch_guid, @end_switch_tag, "", "")
            elsif (switch_guid == @end_switch_quid  )
                set_zone_attributes(@start_switch_guid, @start_switch_guid, "", "")
            elsif ( switch_guid == "" )
                split_zone( guid )
            end
        end
        return false
    end

    def look_for_connection(connector)
        if ( @modified )
            @uclist.clear
            @nuc = 0
            @sections.each_value do |s|
                s.connectors.each do |c|
                    if ( !c.connected? )
                        @uclist[@nuc] = c
                        @nuc += 1
                        puts "zone.look_for_connection, nuc = #{@nuc}, #{c.guid}, #{c.tag}"
                    end
                end
            end
            puts "Zone.look_for_connection, @nuc = #{@nuc}"
            @modified = false
            if ( @nuc == 0 )
                @closed = true
                @zone_group.set_attribute("ZoneAttributes", "closed", @closed)
            end
        end
        if ( @closed ) then return nil end

        @uclist.each_with_index do |c,j|
            if ( connector.close_enough(c) )
                puts "Zone.look_for_connection, found connection #{connector.guid}--#{c.guid}"
                connector.make_connection_link(c)
                @modified = true
                return c
            end
        end
        return nil
    end

    def merge_zone(zoneb)
        puts "Zone.merge_zone"
        puts to_s("before merge_zone")
        puts zoneb.to_s("before merge_zone")
        set_zone_attributes(@start_switch_guid,      @start_switch_tag,
                            zoneb.start_switch_guid,   zoneb.start_switch_tag  )
        $zones.remove_zone_entry(zoneb)
        zoneb_entities   = zoneb.zone_group.explode



        zoneb_entities.each do |e|
            if ( e.is_a? Sketchup::Group )
                old_guid = e.guid
                section = @sections[old_guid]           # this is Section Ruby class
                @sections.delete old_guid               # this removes only Hash entry not obj
                Section.remove_section_entry(old_guid)  # this removes global Hash entry
                copy_section_group(e)
            end
        end
        @section_count = @sections.length
        @zone_group.set_attribute("ZoneAttributes", "section_count",     @section_count)

        puts to_s("after merge_zone")
        $zones.clense_after_explode
    end

    def split_zone( guid )
        puts "Zone.spit_zone, zone_name = #{@zone_name}," +
                                     " guid[0] = #{guid[0]}, guid[1] = #{guid[1]}"
        connector_e = traverse_zone                # Zone now contains 2 groups of sections
        guid_e      = connector_e.guid             # Each group or both may be connected to
        guid_s      = guid[0]                      # switch. Use traverse_zone to select a 
        if ( guid_e == guid[1] )                   # group. Other group will be in new zone
            guid_s  = guid[1]
        end

        connector_in = Connector.connector(guid_s)
        section      = nil
        zone         = $zones.add_zone
        zone.load_new_zone
        while (true)
            if ( connector_in.nil? )
                break
            end
            section = connector_in.parent_section
            if ( section.section_type == "switch" )
                break
            end
            zone.copy_section_group(section.section_group)
            delete_section_group(section.section_group)
            if ( connector_in.tag == "B" )
                connector_out = section.connector("A")
            else
                connector_out = section.connector("B")
            end
            connector_in = connector_out.linked_connector
        end

        if ( !section.nil? )
            zone.set_zone_attributes(section.guid, connector_in.tag, "", "")
        else
            zone.set_zone_attributes("", "", "", "")
        end
        return zone
    end

    def copy_section_group(from_section_group)  #Method can be called from other zones
        section_index_g = from_section_group.get_attribute("SectionAttributes",
                                                            "section_group_g")
        puts "Zone.copy_section_group, zone_name = #{@zone_name},"
                               " section_index_g = #{section_index_g}"
        section_group = @zone_group.entities.add_instance(from_section_group.definition,
                                                          from_section_group.transformation)
        section_group.name = "section"
        ad = from_section_group.attribute_dictionary("SectionAttributes")
        ad.each_pair do |k, v|
            if ( k != "zone_guid" )
                section_group.set_attribute("SectionAttributes", k, v)
                puts "Zone.copy_section_group,\t#{k} - #{v}"
            else
                section_group.set_attribute("SectionAttributes", "zone_guid", @zone_group.guid)
                puts "Zone.copy_section_group,\t#{k} - #{@zone_group.guid}"
            end
        end
        section = Section.factory(section_group)
        @sections[section.guid] = section
        @section_count = @sections.length
        section.update_zone_dependencies
    end

    def delete_section_group(section_group)    # Method can be called from other zones
        puts "Zone,delete_section_group, group guid = #{section_group.guid}"
        @sections.delete section_group.guid
        section_group.erase!
        @section_count = @zone_group.entities.length
        @zone_group.set_attribute("ZoneAttributes", "section_count", @section_count)
        return @section_count
    end

    def set_zone_attributes(swa_guid, taga, swb_guid, tagb)
        puts "Zone.set_zone_attributes, #{swa_guid}, #{taga} #{swb_guid} #{tagb}"

        if (    swa_guid == "" && swb_guid == "")
            @start_switch_guid = ""
            @start_switch_tag  = ""
            @end_switch_guid   = ""
            @end_switch_tag    = ""
            @closed            = false
            @zone_type         = "segment"
        elsif ( swa_guid == "" && swb_guid != "" )
            @start_switch_guid = swb_guid
            @start_switch_tag  = tagb
            @end_switch_guid   = ""
            @end_switch_tag    = ""
            @closed            = false
            @zone_type         = "sidetrack"
        elsif ( swa_guid != "" && swb_guid == "" )
            @start_switch_guid = swa_guid
            @start_switch_tag  = taga
            @end_switch_guid   = ""
            @end_switch_tag    = ""
            @closed            = false
            @zone_type         = "sidetrack"
        elsif ( swa_guid != "" && swb_guid != "" )
            @start_switch_guid = swa_guid
            @start_switch_tag  = taga
            @end_switch_guid   = swb_guid
            @end_switch_tag    = tagb
            @closed            = true
            @zone_type         = "segment"
        end
        @zone_group.set_attribute("ZoneAttributes", "start_switch_guid", @start_switch_guid)
        @zone_group.set_attribute("ZoneAttributes", "start_switch_tag",  @start_switch_tag)
        @zone_group.set_attribute("ZoneAttributes", "end_switch_guid",   @end_switch_guid)
        @zone_group.set_attribute("ZoneAttributes", "end_switch_tag",    @end_switch_tag)
        @zone_group.set_attribute("ZoneAttributes", "closed",            @closed)
        @zone_group.set_attribute("ZoneAttributes", "zone_type",         @zone_type)
    end

    def traverse_zone
        puts "Zone.traverse_zone, zone_name = #{zone_name}, zone_count = #{@zone_count}"
        connector_in = find_start_connector
        puts "Zone.traverse_zone, connector_in.guid = #{connector_in.guid}"
        section_index_z = 0
        connector_out = nil
        endflg = false
        while ( !endflg )
            if ( connector_in.nil? )
                break
            end
            section = connector_in.parent_section
            if (section.section_type == "switch" )
                break
            end
            section.update_ordered_attributes( section_index_z, connector_in.tag )
            section_index_z += 1
            puts "zone.traverse_zone, section_index_z = #{section_index_z}"
            if ( connector_in.tag == "A" )
                connector_out = section.connector("B")
            else
                connector_out = section.connector("A")
            end
            connector_in = connector_out.linked_connector
        end
        nsection = section_index_z
        if ( nsection != @section_count )
            puts "Zone.traverse_zone, invalid zone, nsection = #{nsection}, "+
                                           "@section_count = #{@section_count}"
            @valid = false
            @zone_group.set_attribute("ZoneAttributes", "valid", @valid)
        end
        return connector_out
    end
    
    def export_layout_slices(vtxfile)
        vtxfile.puts sprintf("zone %-20s %s\n", "zone_name",         @zone_name)
        vtxfile.puts sprintf("zone %-20s %s\n", "zone_type",         @zone_type)
        start_switch_name = $switches.switch(@start_switch_guid).switch_name
        vtxfile.puts sprintf("zone %-20s %s\n", "start_switch_name", start_switch_name)
        vtxfile.puts sprintf("zone %-20s %s\n", "start_switch_tag",  @start_switch_tag)
        end_switch_name = $switches.switch(@end_switch_guid).switch_name
        vtxfile.puts sprintf("zone %-20s %s\n", "end_switch_name",   end_switch_name)
        vtxfile.puts sprintf("zone %-20s %s\n", "end_switch_tag",    @end_switch_tag)
        vtxfile.puts sprintf("zone %-20s %d\n", "section_count",     @section_count)
        vtxfile.puts sprintf("zone %-20s\n", "end")
        connector_in = find_start_connector
        while (true)
            if ( connector_in.nil? )
                break
            end
            section = connector_in.parent_section
            if ( section.section_type == "switch" )
                break
            end
            section.export_ordered_slices(vtxfile, connector_in.tag)
            if ( connector_in.tag == "B" )
                connector_in = section.connector("A").linked_connector
            else
                connector_in = section.connector("B").linked_connector
            end
        end
    end

    def find_start_connector
        connector_in = nil
        if ( @start_switch_guid != "")
            puts $switches.to_s
            puts "Zone.traverse_zone, @start_switch_guid = #{@start_switch_guid}" +
                                   ", @start_switch_tag = #{@start_switch_tag}"
            start_switch = $switches.switch(@start_switch_guid)
            connector_out = start_switch.connector(@start_switch_tag)
            connector_in = connector_out.linked_connector
        else
            @uclist.clear
            @nuc = 0
            @sections.each_value do |s|
                s.connectors.each do |c|
                    if ( !c.connected? )
                        @uclist[@nuc] =c
                        @nuc +=1
                    end
                end
            end
            puts "Zone.traverse_zone, nuc = #{@nuc}"
            connector_in = @uclist[0]
        end
        return connector_in
    end

    def visible( outline_visible)
        @sections.each_value do |s|
            s.outline_visible( outline_visible)
        end
    end

    def material( color)
        @sections.each_value do |s|
            s.outline_material( color )
        end
    end
    def to_s(comment = "")
        str = "\nZone attributes, name = #{@zone_name}  #{comment}\n" +
                "\t zone guid         #{@guid}\n" +
                "\t start_switch_guid #{@start_switch_guid}\n" +
                "\t start_switch_tag  #{@start_switch_tag}\n" +
                "\t end_switch_guid   #{@end_switch_guid}\n" +
                "\t end_switch_tag    #{@end_switch_tag}\n" +
                "\t zone_type         #{@zone_type}\n" +
                "\t closed            #{@closed}\n" +
                "\t valid             #{@valid}\n" +
                "\t section_count     #{@section_count}\n"
        return str
    end

    def report_sections
        #           012345678901234567890123456789012345678901234567890123456789
        hdr_txt2 = "   Name          Type       Code        Slope-fwd   Index     Tag      Height    Height"
        hdr_txt1 = "   Zone                                             Entry    Entry      Entry     Exit "
        if $rptfile.nil?
            puts "\n\n Zone #{@zone_name} by section"
            puts hdr_txt1
  e         puts hdr_txt2
        else
            $rptfile.puts "\n\n Zone #{@zone_name} by section"
            $rptfile.puts hdr_txt1
            $rptfile.puts hdr_txt2
        end
        puts hdr_txt1
        puts hdr_txt2
        @sections.each_value do |s|
            slope = s.slope
            if s.entry_tag != "A"
                slope = -slope
            end
            ha = s.connector(s.entry_tag).position(true).z
            hb = s.connector(s.exit_tag).position(true).z
            str = sprintf("%-15s %-8s  %-10s %10.5f %7d %8s  %10s %10s",
                   s.zone.zone_name, s.section_type, s.code, slope, 
                                   s.section_index_z, s.entry_tag, ha.to_s, hb.to_s)
            puts str
            $rptfile.puts str
        end
    end

    def Zone.init_class_variables
        model = Sketchup.active_model
        @@zone_material = model.materials["zone"]
        if @@zone_material.nil?
            @@zone_material = model.materials.add("zone")
        end
        color = Sketchup::Color.new("red")
        color.alpha=  0.1
        $logfile.puts "zone color = #{color.to_s}"
        @@zone_material = "wheat"
        @@zone_style    = "edges"
        @@zone_switch_material = "wheat"
        @@zone_switch_style    = "edges"
        $logfile.puts "model.layers.length #{model.layers.length}"
        model.layers.add("zones")
    end
    def Zone.material
        return @@zone_material
    end
    def Zone.style
        return @@zone_style
    end
    def Zone.switch_material
        return @@zone_switch_material
    end
    def Zone.switch_style
        return @@zone_switch_style
    end
    def Zone.zone_group? (e)
        if ( e.is_a? Sketchup::Group )
            if (e.name == "zone" )
                return true
            end
        end
        return false
    end
end
