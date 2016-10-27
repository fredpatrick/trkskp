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


class SectionList

    def SectionList.section_list_group?(arg)
        if arg.nil?
            return false
        elsif !arg.is_a? Sketchup::Group
            return false
        elsif arg.name != "section_list"
            return false
        else
            return true
        end
    end

    def initialize(section_list_group, start_section = nil)
        if !start_section.nil?
            $logfile.puts "SectionList.initialize, start_section \n #{start_section.to_s}"
            $logfile.flush
        end
        @section_list_group = section_list_group
        slname = "SectionListAttributes"
        if !start_section.nil?                   # new section_list_group
            if start_section.type == "switch"
                return nil
            end
            sections_t = traverse_sections(start_section, "A")
            ns = sections_t.length
            end_connector_a = sections_t[ns-1]
            $logfile.puts "end_connector_a #{end_connector_a.to_s}"
            sections_a    = sections_t[0..ns-2]
            @sections     = []
            n             = 0
            sections_a.reverse_each{ |s| @sections[n] = s; n += 1}
            linked_connector_a = end_connector_a.linked_connector
            if !linked_connector_a.nil? && 
                linked_connector_a.parent_section.equal?(start_section)
                @start_connector = start_section
                @end_connector   = nil
            else
                sections_t = traverse_sections(start_section, "B")
                ns         = sections_t.length
                end_connector_b = sections_t[ns-1]
                $logfile.puts "end_connector_b #{end_connector_a.to_s}"
                sections_b    = sections_t[1..ns-2]
                sections_b.each { |s| @sections[n] = s; n += 1}

                @end_connector   = end_connector_b
                @start_connector = end_connector_a
                if end_connector_a.nil? && !end_connector_b.nil?
                    @start_connector = end_connector_b
                    @end_connector   = nil
                    n = 0
                    sections = []
                    @sections.reverse_each { |s| sections[n] = s; n+= 1}
                    @sections = sections
                end
            end
            sattrs = @section_list_group.attribute_dictionary(slname, true)
            if @start_connector
                @section_list_group.set_attribute(slname, "start_connector_guid", 
                                                                      @start_connector.guid)
            else
                @section_list_group.set_attribute(slname, "start_connector_guid", "")
            end
            if @end_connector
                @section_list_group.set_attribute(slname, "end_connector_guid",   
                                                         @end_connector.guid)
            else
                @section_list_group.set_attribute(slname, "end_connector_guid",   "")
            end
            section_guids = []
            @outline_groups = Hash.new
            @sections.each_with_index {|s,i| 
                section_guids[i] = s.guid 
                @outline_groups[s.guid] = s.outline_group_factory(@section_list_group)
            }
            @section_list_group.set_attribute(slname, "section_guids", section_guids)

        else                         # exiting section_list_group -- called during load_zones
            start_cpt_guid = @section_list_group.get_attribute(slname,"start_connector_guid","")
            @start_connector     = Connector.connector(start_cpt_guid)
            if @start_connector.nil?
                raise RuntimeError, "SectionList.new failed,start_connector is nil"
            end
            end_cpt_guid   = @section_list_group.get_attribute(slname,"end_connector_guid","")
            @end_connector       = Connector.connector(end_cpt_guid)
            if @end_connector.nil?
                raise RuntimeError, "SectionList.new failed,end_connector is nil"
            end
            section_guids     = @section_list_group.get_attribute(slname, "section_guids")
            @sections = []
            section_guids.each_with_index { |sg,i| @sections[i] = Section.section(sg) }
            if !verify
                @sections.each do |s|
                    if !s.nil?
                        s.reset_zone_parms
                    end
                end
                raise RuntimeError,"SectionList.new, verify failed, check logfile"
            end
            @outline_groups = Hash.new
            @section_list_group.entities.each do |o|
                if o.is_a? Sketchup::Group 
                    if o.name == "outline"
                        section_guid =  o.get_attribute("OutlineAttributes", "section_guid")
                        @outline_groups[section_guid] = o
                    end
                end
            end
        end
        return true
    end

    def to_s(ntab=1)
        stab = ""
        1.upto(ntab) {|i| stab = stab +"\t"}
        str =  stab+"SectionList: start_connector #{@start_connector}" +
                               "- end_connector #{@end_connector} \n"
        @sections.each_with_index do |s,i| 
            str = str + "#{s.to_s(ntab+1)} \n" 
        end
        return str
    end

    def traverse_sections(start_section, start_tag)
        sections = []
        sections[0] = start_section
        n           = 1
        cpt0      = start_section.connection_pt(start_tag)
        cid1      = cpt0.linked_guid
        $logfile.puts "traverse_sections, cid1 #{cid1}"
        endflg = false
        while endflg == false
            if cid1 == "UNCONNECTED"
                sections[n] = cpt0   # end_connector for section_list
                endflg = true
            else
                cpt1 = Connector.connector(cid1)
                tag1 = cpt1.tag
                linked_section = cpt1.parent_section
                $logfile.puts "traverse_sections, linked section #{linked_section.guid}"
                $logfile.puts "traverse_sections, linked section type #{linked_section.type}"
                if linked_section.equal? start_section
                    sections[n] = cpt0      # end_connector for section_list
                    endflg = true
                elsif linked_section.type == "switch"
                    $logfile.puts "traverse_sections,switch found"
                    sections[n] = cpt0      # end_connector for section_list
                    endflg = true
                else
                    sections[n] = linked_section
                    n = n + 1
                    endflg = false
                    cpt = nil
                    if tag1 == "A"
                        cpt = linked_section.connection_pt("B")
                    else
                        cpt = linked_section.connection_pt("A")
                    end
                    cpt0 = cpt
                    cid1 = cpt0.linked_guid
                    $logfile.puts "traverse_sections, cid1 #{cid1}"
                end
            end
        end
        return sections
    end

    def rationalize_sections(begin_connector, zone_name)
        $logfile.puts "rationalize_sections, begin_connector #{begin_connector.guid}" +
                      " tag #{begin_connector.tag}"
        @start_connector = begin_connector
        slname = "SectionListAttributes"
        @section_list_group.set_attribute(slname, "start_connector_guid", @start_connector.guid)
        endflg = false
        n      = 0
        entry_connector = begin_connector
        parent_section   = entry_connector.parent_section
        while endflg == false
            $logfile.puts"rationalize_sections,section= #{n} entry tag = #{entry_connector.tag}"
            $logfile.puts"rationalize_sections,section = #{n} #{parent_section.guid}"
            entry_tag = entry_connector.tag
            exit_tag  = "U"
            if entry_tag == "A"
                exit_tag = "B"
            elsif entry_tag == "B"
                exit_tag = "A"
            end
            parent_section.set_zone_parms(zone_name, n, entry_tag, exit_tag)
            exit_connector = parent_section.connection_pt(exit_tag)
            @sections[n] = parent_section
            n = n +1
            entry_connector = exit_connector.linked_connector
            if entry_connector.nil?
                endflg = true
                @end_connector = exit_connector
            else
                parent_section = entry_connector.parent_section
                if parent_section.type == "switch"
                    endflg = true
                    @end_connector = exit_connector
                else
                    endflg = false
                end
            end
        end
        @section_list_group.set_attribute(slname, "end_connector_guid", @end_connector.guid)
        section_guids = []
        @sections.each_with_index {|s,i| section_guids[i] = s.guid }
        @section_list_group.set_attribute(slname, "section_guids", section_guids)
    end

    def verify
        is = 0
        entry_connector = @start_connector
        while is < @sections.length
            if entry_connector.nil?
                $logfile.puts "section_list.verify, entry_connector is nil, #{is} "
                return false
            end
            parent_section = entry_connector.parent_section
            if !parent_section.equal? @sections[is]
                UI.messagebox("linked_section != @sections[#{is}], verify failed")
                $logfile.puts "section_list.verify,linked_section != @sections[#{is}] " +
                                   " #{is} #{linked_section.guid}"
                return false
            end
            exit_tag = parent_section.exit_tag
            exit_connector = parent_section.connection_pt(exit_tag)
            if exit_connector.nil?
                $logfile.puts "section_list.verify, exit_connector is nil, #{is} "
                return false
            end
            entry_connector = exit_connector.linked_connector
            is = is+1
        end
        if !exit_connector.equal? @end_connector
            UI.messagebox("@end_connector != last exit_connector, verify failed")
                $logfile.puts "section_list.verify,@end_connector != last exit_connector" +
                                   " #{exit_connector.guid}"
            return false
        end
        $logfile.puts "section_list.verify succeeded"
        return true
    end

    def end_connector
        return @end_connector
    end

    def start_connector
        return @start_connector
    end

    def sections
        return @sections
    end

    def outlines_visible(visible)
        @outline_groups.values.each { |o| o.visible= visible}
    end

    def outlines_material(material)
        @outline_groups.values.each { |o| o.material = material}
    end

    def rebuild_outlines
        @sections.each do |s|
            outline_group = @outline_groups[s.guid]
            if !outline_group.nil?
                outline_group.erase!
            end
            @outline_groups[s.guid] = s.outline_group_factory(@section_list_group)
        end
    end

end
