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
class SectionShell

    def initialize(slices_group, section)
        @slices_group = slices_group
        @shell_type  = slices_group.get_attribute("SectionShellAttributes", "shell_type")
        @slice_count  = slices_group.get_attribute("SectionShellAttributes", "slice_count")
        @inline_length = slices_group.get_attribute("SectionShellAttributes", "inline_length")
        @section      = section

        @slice_list = []
        @slices_group.entities.each { |e|
            if ( e.is_a? Sketchup::Face )
                slice_index = e.get_attribute("SliceAttributes", "slice_index")
                @slice_list[slice_index] = e
            end
        }
    end

    def write_ordered_slices(vtxfile, tag)
        vtxfile.puts sprintf("shell %-20s %-s\n", "shell_type",    @shell_type)
        vtxfile.puts sprintf("shell %-20s %-12.6f\n", "inline_length", @inline_length)
        vtxfile.puts sprintf("shell %-20s %-d\n", "slice_count",   @slice_count)
        vtxfile.puts sprintf("shell %-20s\n", "end")
        t = @section.section_group.transformation
        @slice_list.each_with_index do |s,i|
            slice_index_z = i
            if ( tag != "A" )
                slice_index_z = @slice_count - i - 1
            end
            slice = @slice_list[slice_index_z]
            if ( !slice.nil? )
                slice.vertices.each_with_index do |v,i|
                    p0 = v.position
                    pt = v.position.transform(t)
                    px = pt.x
                    py = pt.y
                    pz = pt.z
                    str = sprintf("slice %6d%6d%12.6f%12.6f%12.6f\n", 
                                                 slice_index_z, i, px, py, pz)
                    vtxfile.puts str
                end
            else
                puts "SectionShell.write_ordered_slices, slice is nil," +
                                 " slice_index_z = #(slice_index_z}"
            end
        end
    end

    def guid
        return @slices_group.guid
    end

    def type
        return @shell_type
    end

    def slices_group 
        return @slices_group
    end
end
