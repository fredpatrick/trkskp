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


class Gates
    def Gates.load_gates
        $logfile.puts "Gates.load_gates --  begin"
        @@switch_material = "steelblue"
        @@switch_style    = "edges"
        @@gates = Hash.new
        @@gates_group = nil
        Sketchup.active_model.entities.each do |e|
            if e.is_a? Sketchup::Group 
                if e.name == "gates"
                    @@gates_group = e
                    break
                end
            end
        end
        if @@gates_group.nil?
            @@gates_group = Sketchup.active_model.entities.add_group
            @@gates_group.name = "gates"
        else                                     # populate @@gates list of current gates
            @@gates_group.entities.each do |g|
                section_guid = g.get_attribute("OutlineAttributes","section_guid")
                section = Section.section(section_guid)
                if section.nil?
                    g.erase!
                else
                    @@gates[section_guid] = g
                end
            end
        end
        #         look for Section entities that are switches and do not have outlines
        $logfile.puts "Gates.load_gates process switches"
        Section.switches.each do |sw|
            $logfile.puts "load_gates switch #{sw.label} #{sw.guid}"
            section_guid = sw.guid
            if @@gates[section_guid].nil?
                outline_group = sw.outline_group_factory(@@gates_group)
                $logfile.puts "Gates.load_gates outline_group #{outline_group.class}"
                @@gates[section_guid] = outline_group
                Gates.gate_material(section_guid, @@switch_material)
            end
        end
    end

    def Gates.gate(section_guid)
        return @@gates[section_guid]
    end

    def Gates.gate_visible(section_guid, visible)
        outline_group = Gates.gate(section_guid)
        if !outline_group.nil? 
            outline_group.visible = visible
        end
    end

    def Gates.gate_material(section_guid, material)
        outline_group = Gates.gate(section_guid)
        if !outline_group.nil? 
            outline_group.material = material
        end
    end

    def Gates.switch_material
        return @@switch_material
    end

    def Gates.switch_style
        return @@switch_style
    end
end
 

