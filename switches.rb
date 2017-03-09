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
require "#{$trkdir}/section.rb"

class Switches
    def initialize
        @switches_group = nil
        Sketchup.active_model.entities.each do |e|
            if e.is_a? Sketchup::Group
                if e.name == "switches"
                    @switches_group = e
                    break
                end
            end
        end

        if @switches_group.nil?
            @switches_group = Sketchup.active_model.entities.add_group
            @switches_group.set_attribute("SwitchesAttributes", "switch_count", 0)
            @switch_count = 0
            @switches_group.name   = "switches"
            @switches_group.locked = true
        else
            @switch_count = @switches_group.get_attribute("SwitchesAttributes", "switch_count")
        end

        puts "Switches.initialize, load existing switches"
        @switches = Hash.new
        @switches_group.entities.each do |sg|
            if ( sg.is_a? Sketchup::Group )
                if ( sg.name == "section" )
                    section_type = sg.get_attribute("SectionAttributes", "section_type")
                    if ( section_type == "switch" )
                        switchsection = Section.factory(sg)
                        @switches[switchsection.guid] = switchsection
                        switchsection.outline_visible(false)
                    end
                end
            end
        end
    end

    def add_section(connection_point, type)
        section_group = @switches_group.entities.add_group
        section_group.name   = "section"
        section_group.locked = true
        section_group.set_attribute("SectionAttributes", "section_type",  type)
        section_group.set_attribute("SectionAttributes", "switches_guid", @switches_group.guid)
        section_group.set_attribute("SectionAttributes", "switch_index",  @switch_count)
        @switch_count += 1
        @switches_group.set_attribute("SwitchesAttributes", "switch_count", @switch_count)

        section = Section.factory(section_group, connection_point)
        @switches[section.guid] = section
        puts "Switches.add_section, " + self.to_s
        return section
    end

    def erase_switch(target_switch)
        puts "Switches.erase_switch, target_switch guid = #{target_switch.guid}"
        target_switch.connectors.each do |c|
            puts "Switches.erase_switch, connector tag = #{c.tag}"
            if ( c.connected? )
                parent_section = c.linked_connector.parent_section
                if (parent_section.section_type != "switch" )
                    zone = parent_section.zone
                    puts zone.to_s("Switches.erase_switch")
                    if ( !zone.closed? )
                        zone.set_zone_attributes("", "", "", "")
                    elsif( zone.start_switch_guid == target_switch.guid )
                        zone.set_zone_attributes(zone.end_switch_guid, 
                                                 zone.end_switch_tag, 
                                                 "", "")
                    else
                        zone.set_zone_attributes(zone.start_switch_guid, 
                                                 zone.start_switch_tag, 
                                                 "", "")
                    end
                end
            end
        end
        target_switch.connectors.each  do |c| 
            if ( c.connected? )
                c.break_connection_link
            end
        end

        section_group = target_switch.section_group
        @switches.delete section_group.guid
        section_group.erase!
    end


    def look_for_connected(connector)
        uclist = []
        nuc    = 0
        @switches.each_value do |s|
            s.connectors.each do |c|
                if ( !c.connected? )
                    uclist[nuc] = c
                    nuc += 1
                    puts "Switches.look_for_connected, nuc = #{nuc}, #{c.guid}, #{c.tag}"
                end
            end
        end
        uclist.each do |c|
            if ( connector.close_enough(c) )
                connector.make_connection_link(c)
                return c
            end
        end
        return nil
    end

    def to_s
        str = "\nSwitches.@switches\n"
        @switches.each do |k,v|
            str = str + sprintf("%15s ", k, v.switch_index)
        end
        return str
    end

    def switch(guid)
        return @switches[guid];
    end

    def export_layout_slices(vtxfile)
        vtxfile.puts sprintf("switches %-20s %-s\n", "switch_count", @switch_count) 
        @switches.each_value do |s|
            s.export_ordered_slices(vtxfile, "A")
        end
    end

    def report_switches
    #               012345678901234567890123456789012345678901234567890
        hdr_txt2 = "  Label    Code      Direction"
        hdr_txt1 = "          Diameter            "
        if $rptfile.nil?
            puts "\n\n   Report Switches"
            puts hdr_txt1
            puts hdr_txt2
        else
            $rptfile.puts "\n\n Report Switches"
            $rptfile.puts hdr_txt1
            $rptfile.puts hdr_txt2
        end
        @switches.each_value do |sw|
            if $rptfile.nil?
                printf(" %-9s  %3s        %-5s\n", sw.switch_name, sw.code, sw.direction)
            else
                $rptfile.printf(" %-9s  %3s        %-5s\n", sw.switch_name, sw.code,
                                                           sw.direction)
            end
        end
    end

    def Switches.init_class_variables
        @@switch_material = "steelblue"
        @@switch_style    = "edges"
    end

    def Switches.switch_material
        return @@switch_material
    end
    def Switches.switch_style
        return @@switch_style
    end
end

