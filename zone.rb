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
require "#{$trkdir}/sectionlist.rb"

class Zones

    def Zones.load_zones                         #load_zones is class method
        @@zones = Hash.new
        Zone.init_class_variables
        $logfile.puts "Begin load_zones"
        @@zones_group = nil
        entities = Sketchup.active_model.entities
        entities.each do |e|
            if e.is_a? Sketchup::Group 
                if e.name == "zones"
                    @@zones_group = e
                    break
                end
            end
        end

        if @@zones_group.nil?
            $logfile.puts "Creating new zones_group"
            @@zones_group = Sketchup.active_model.entities.add_group
            @@zones_group.name = "zones"
        else
            $logfile.puts "Loading zones"
            @@zones_group.entities.each do |z|
                 if Zone.zone_group? z
                     zone = Zones.factory(z)
                     $logfile.puts zone.to_s
                 end
            end
        end
        $logfile.puts "End load_zones, # of zones #{Zones.zones.length}"
    end
    def Zones.factory(arg, view = nil)
        $logfile.puts "Zones.factory arg = #{arg.class}"
        zone = nil
        zone_group    = nil
        start_section = nil
        if Zone.zone_group? arg
            zone_group = arg 
        else
            start_section = arg
            zone_group = Zones.zones_group.entities.add_group
            zone_group.name = "zone"
        end
        begin
            zone = Zone.new(zone_group, start_section)
            @@zones[zone.zone_name] = zone
            zone.visible=true
            $logfile.puts "Zones.factory #{zone.to_s}"
        rescue => ex
            puts "#{ex.class} #{ex.message}\n"
            if !ex.is_a? RuntimeError
                ex.backtrace.each { |l| puts l }
                $logfile.puts "Zones.factory, #{ex.class} #{ex.message}\n"
                ex.backtrace.each { |l| $logfile.puts l }
                $logfile.puts "Zones.factory, erasing zone"
            end
            zone_group.erase!
            zone = nil
        end
        $logfile.flush
        if !view.nil? 
            view.refresh
        end
        return zone
    end


    def Zones.zones_group
        return @@zones_group
    end

    def Zones.toggle_visibility
        if @@zones_group.nil? 
            return
        end

        if (!@@zones_group.visible? )
            vmenu = UI.menu("View")
            vmenu.set_validation_proc($view_zones_id) { MF_CHECKED }
            @@zones_group.visible = true
        else
            vmenu = UI.menu("View")
            vmenu.set_validation_proc($view_zones_id) { MF_UNCHECKED }
            @@zones_group.visible = false
        end
    end
    def Zones.zones
        #@@zones.each_pair { |k, v| $logfile.puts "   key #{k}        #{v}" }
        return @@zones.values
    end

    def Zones.zone(zone_name)
        return @@zones[zone_name]
    end

    def Zones.delete_zone(zone_name)
        zone = @@zones[zone_name]
        zone.erase
        @@zones.delete zone_name
    end

    def Zones.list
        $logfile.puts "Zone.list"
        @@zones.keys.each {|k| $logfile.puts "    #{k}"  }
    end

    def Zones.add_vertex_data

        @@zones.values.each { |z| z.add_vertex_data }
    end

    def Zones.export_vertex_data
        model_path = Sketchup.active_model.path
        if model_path == ""
            return nil
        end
        vtxdir = File.dirname(model_path) + '/'
        model_basename = File.basename(model_path, '.skp')
        filename = UI.savepanel("Save Vertex File", vtxdir, model_basename + '.vtx')
        if filename.nil?
            return nil
        end
        vtxfile = File.open(filename, "w")
        @@zones.values.each { |z| 
            puts "Zones.export_vertex_data, zone_name = #{z.zone_name}"
            z.export_vertices(vtxfile) 
        }
    end

    def Zones.delete_vertex_data
        @@zones.values.each { |z| 
            z.delete_vertices
        }
    end

    def Zones.report_file
        puts "Zones.report_file"
        model_path = Sketchup.active_model.path
        if model_path == ""
            return nil
        end
        rptdir = File.dirname(model_path) + '/'
        model_basename = File.basename(model_path, '.skp')
        filename = UI.savepanel("Save Report File", rptdir, model_basename + '.rpt')
        puts rptdir

        if filename.nil?
            return nil
        end
        puts filename
        return File.open(filename, "w")
    end

    def Zones.report_by_zone
        @@zones.values.each { |z| z.report_sections }
    end

    def Zones.report_switches
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
        Section.switches.each do |sw|
            if $rptfile.nil?
                printf(" %-9s  %3s        %-5s\n", sw.label, sw.code, sw.direction)
            else
                $rptfile.printf(" %-9s  %3s        %-5s\n", sw.label, sw.code, sw.direction)
            end
        end
    end

    def Zones.report_summary
  #                 0123456789012345678901234567890123456789012345678901234567890123456789
        hdr_txt1 = " zone_name           connected?   zone_type     # of   " + 
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
        @@zones.values.each do |z|
            if $rptfile.nil?
                printf(" %-19s %5s      %10s      %4d        %4s    %4s\n",
                            z.zone_name, z.connected?, z.type, z.count,
                                                     z.start_switch_label, z.end_switch_label)
            else
                $rptfile.printf(" %-19s %5s      %10s      %4d        %4s    %4s\n",
                            z.zone_name, z.connected?, z.type, z.count,
                                                     z.start_switch_label, z.end_switch_label)
            end
        end
    end
end

class Zone
    def Zone.init_class_variables
        model = Sketchup.active_model
        @@zone_material = model.materials["zone"]
        if @@zone_material.nil?
            @@zone_material = model.materials.add("zone")
        end
        color = Sketchup::Color.new("red")
        color.alpha=  0.1
        $logfile.puts "zone color = #{color.to_s}"
        @@zone_material = color
        @@zone_style    = "edges"
        @@zone_switch_material = "steelblue"
        @@zone_switch_style    = "edges"
        $logfile.puts "model.layers.length #{model.layers.length}"
        model.layers.add("zones")
    end

    def initialize(zone_group, start_section = nil)
        @zone_group = zone_group
        if start_section
            $logfile.puts "Zone.initialize, start_section #{start_section.guid} "
            section_list_group = @zone_group.entities.add_group
            section_list_group.name = "section_list"
            @section_list = SectionList.new(section_list_group, start_section)
            $logfile.puts @section_list.to_s
            if @section_list.start_connector.connected?
                @start_switch = @section_list.start_connector.linked_connector.parent_section
            else
                @start_switch = nil
            end
            if @section_list.end_connector.connected?
                @end_switch = @section_list.end_connector.linked_connector.parent_section
            else
                @end_switch = nil
            end
            @section_list.outlines_visible(true)
            @section_list.outlines_material("red")

            prompts = []
            values  = []
            tlist   = []
            prompts[0] = $exStrings.GetString("Zone name")
            values[0]  = $exStrings.GetString("unassigned")
            tlist[0]   = ""
            if !@start_switch.nil? && !@end_switch.nil?
                prompts[1] = "Start Switch"
                values [1] = "#{@start_switch.label}"
                tlist[1]   = "#{@start_switch.label}|#{@end_switch.label}"
            end
            results    = UI.inputbox(prompts, values, tlist, "Create Zone")
            if !results
                raise RuntimeError, "User chose not to create zone"
            end
            @zone_name = results[0]
            begin_connector  = @section_list.start_connector
            if prompts.length == 2
                sw_label         = results[1]
                if @start_switch.label != sw_label
                    old_start_switch = @start_switch
                    @start_switch    = @end_switch
                    @end_switch      = old_start_switch
                    begin_connector  = @section_list.end_connector
                end
            end
            $logfile.puts "Zone.initialize, zone_name #{@zone_name}"

            nsw           = 0
            if @start_switch.nil? && @end_switch.nil?
                @connected = false
                @type      = "segment"
            elsif @start_switch.equal? @section_list.sections[-1]
                @connected = false
                @type      = "loop"
                @start_switch = nil
            elsif @start_switch.equal? @end_switch
                @connected = true
                @type      = "loop"
            elsif @start_switch.nil?
                @start_switch = @end_switch        # sidetracks always begin with @start_switch
                begin_connector = @section_list.end_connector
                @end_switch   = nil
                @connected = true
                @type      = "sidetrack"
            elsif @end_switch.nil?
                @connected = true
                @type      = "sidetrack"
            else
                @connected = true
                @type      = "segment"
            end
            @section_list.rationalize_sections(begin_connector, @zone_name)
            zname = "ZoneAttributes"
            zattrs = @zone_group.attribute_dictionary(zname, true)
            @zone_group.set_attribute(zname, "zone_name", @zone_name)
            @zone_group.set_attribute(zname, "connected", @connected)
            @zone_group.set_attribute(zname, "type",      @type)
            if !@start_switch.nil? 
                @zone_group.set_attribute(zname, "start_switch_guid", @start_switch.guid)
            else
                @zone_group.set_attribute(zname, "start_switch_guid", "")
            end
            if !@end_switch.nil? 
                @zone_group.set_attribute(zname, "end_switch_guid", @end_switch.guid)
            else
                @zone_group.set_attribute(zname, "end_switch_guid", "")
            end
            @section_list.rebuild_outlines
            @section_list.outlines_material("green")
            visible= true
        else
            $logfile.puts "zone.initialize, existing zone -  begin"
            zname =  "ZoneAttributes"
            @zone_name = @zone_group.get_attribute(zname,"zone_name")
            @connected = @zone_group.get_attribute(zname,"connected")
            @type      = @zone_group.get_attribute(zname, "type")
            $logfile.puts "                 zone_name = #{@zone_name}"
            begin
                @zone_group.entities.each do |e|
                    $logfile.puts "zone.initialize, #{e.typename}"
                    if e.is_a? Sketchup::Group
                        $logfile.puts "zone.initialize, #{e.typename} #{e.name}" 
                    else
                        $logfile.puts "zone.initialize, #{e.typename}"
                    end
                    if SectionList.section_list_group? e
                        @section_list = SectionList.new(e)
                        break
                    end
                end
                if @section_list.nil?
                    $logfile.puts "zone.initialize, section_list_group not found"
                    raise RuntimeError, "section_list_group not found"
                end
            rescue => ex
                puts "#{ex.class} #{ex.message}\n"
                ex.backtrace.each { |l| puts l }
                $logfile.puts "Zones.factory, #{ex.class} #{ex.message}\n"
                ex.backtrace.each { |l| $logfile.puts l }
                dump_group(@zone_group, 1) 
                @zone_group.entities.each do |e|
                    if SectionList.section_list_group? e
                        $logfile.puts "found a section_list_group"
                        section_guids = e.get_attribute("SectionListAttributes","section_guids")
                        if !section_guids.nil?
                            section_guids.each do |guid|
                                section = Section.section(guid)
                                if !section.nil?
                                    $logfile.puts "found a non nil section"
                                    section.reset_zone_parms
                                end
                            end
                        end
                        break
                    end
                end
                raise RuntimeError,"zone = #{@zone_name}, #{ex.message}"
            end

            start_switch_guid = @zone_group.get_attribute(zname, "start_switch_guid")
            if start_switch_guid != ""
                @start_switch = Section.section(start_switch_guid)
                if @start_switch.nil?
                    raise RuntimeError,"zone = #{@zone_name}, start_switch is nil"
                end
            end
            end_switch_guid = @zone_group.get_attribute(zname, "end_switch_guid")
            if end_switch_guid != ""
                @end_switch = Section.section(end_switch_guid)
                if @end_switch.nil?
                    raise RuntimeError,"zone = #{@zone_name}, end_switch is nil"
                end
            end
        end
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


    def Zone.zone_group?(arg)
        if arg.nil?
            return false
        elsif !arg.is_a? Sketchup::Group
            return false
        elsif arg.name != "zone"
            return false
        else
            return true
        end
    end

    def zone_name
        return @zone_name
    end

    def export_vertices(vtxfile)
        @zone_group.entities.each { |e|
            next if !e.is_a? Sketchup::Group
            next if e.name != "slices"

            slices_group = e
            zone_index = slices_group.get_attribute("SlicesAttrs", "zone_index")
            t          = slices_group.transformation
            slice_index = 0
            slices_group.entities.each { |s|
                if s.is_a? Sketchup::Face
                    slice = s
                    str_l = sprintf("%6s%6d%6d", @zone_name, zone_index, slice_index)
                    slice.vertices.each_with_index{ |v,i|
                        
                        p0 = v.position
                        pt = v.position.transform(t)
                        px = pt.x
                        py = pt.y
                        pz = pt.z
                        str = str_l + sprintf("%6d%12.6f%12.6f%12.6f\n", i, px, py, pz)
                        vtxfile.puts str
                    }
                    slice_index += 1
                end
            }
        }
        vtxfile.flush
    end

    def delete_vertices
        @zone_group.entities.each { |e|
            next if !e.is_a? Sketchup::Group
            next if e.name != "slices"
            e.erase!
        }
    end

    def erase
        $logfile.puts "zone.erase, zone_name = #{@zone_name}"
        if !@section_list.nil?
            @section_list.sections.each { |s| s.reset_zone_parms }
        end
        @zone_group.erase!
    end

    def section_list
        return @section_list
    end

    def connected?
        return @connected
    end

    def type
        return @type
    end

    def count
        return @section_list.sections.length
    end

    def start_switch
        return @start_switch
    end

    def start_switch_label
        if !@start_switch.nil?
            tag = @section_list.start_connector.linked_connector.tag
            return @start_switch.label + tag
        else
            return ""
        end
    end

    def end_switch
        return @end_switch
    end

    def end_switch_label
        if !@end_switch.nil?
            tag = @section_list.end_connector.linked_connector.tag
            return @end_switch.label + tag
        else
            return ""
        end
    end

    def visible=arg
        $logfile.puts "zone.visible #{arg} #{@zone_name}"
        if !@start_switch.nil? 
            Gates.gate_visible(@start_switch.guid, arg)
        end
        if !@end_switch.nil?  
            Gates.gate_visible(@end_switch.guid, arg)
        end
        @section_list.outlines_visible(arg)
    end

    def to_s(ntab=1)
        stab = ""
        1.upto(ntab) {|i| stab = stab + "\t"}
        stab + "Zone - zone_name #{@zone_name} connected? #{@connected} type #{@type}\n" +
        stab + "       start_switch #{start_switch_label} end_switch #{end_switch_label}" +
                                       " count #{count}"
#       "#{@section_list.to_s(ntab+1)}"
    end

    def add_vertex_data
        n = @section_list.sections.length
        last = false
        @section_list.sections.each_with_index { |s,i|
            if i == n - 1 then last = true end
            slices_group = s.make_slices(@zone_group, last)
            slices_group.hidden = true
        }
    end


    def report_sections
        #           012345678901234567890123456789012345678901234567890123456789
        hdr_txt2 = "  Index     Type       Code        Slope-fwd   Tag      Height    Height"
        hdr_txt1 = "   Zone                                       Entry      Entry     Exit "
        if $rptfile.nil?
            puts "\n\n Zone #{@zone_name} by section"
            puts hdr_txt1
            puts hdr_txt2
        else
            $rptfile.puts "\n\n Zone #{@zone_name} by section"
            $rptfile.puts hdr_txt1
            $rptfile.puts hdr_txt2
        end
        @section_list.sections.each do |s|
            slope = s.slope
            if s.entry_tag != "A"
                slope = -slope
            end
            ha = s.connection_pt(s.entry_tag).position(true).z
            hb = s.connection_pt(s.exit_tag).position(true).z
            if $rptfile.nil?
                printf("   %2d       %-8s  %-10s %10.5f %5s  %10s %10s\n",
                   s.zone_index, s.type, s.code, slope, s.entry_tag, ha.to_s, hb.to_s)
            else
                $rptfile.printf("   %2d       %-8s  %-10s %10.5f %5s  %10s %10s\n",
                   s.zone_index, s.type, s.code, slope, s.entry_tag, ha.to_s, hb.to_s)
            end
        end
    end




    def dump_group(g, level)
        $logfile.puts tabs(level) + "#{g.name}  #{g.guid}"
        attrdicts = g.attribute_dictionaries
        if !attrdicts.nil?
            attrdicts.each do |ad|
                $logfile.puts tabs(level+1) + "#{ad.name}"
                ad.each_pair do  |k,v| 
                    $logfile.puts tabs(level+2) + " #{k}    #{v}"
                end
            end
        end
        level += 1
        entities = g.entities
        entities.each do |e|
            #puts e.typename
            if e.is_a? Sketchup::Group
                dump_group(e, level)
            end
        end
    end

    def tabs(ntab = 0)
        tbs = ""
        n = 0
        while n < ntab
            tbs = tbs + "\t"
            n += 1
        end
        return tbs
    end
end
