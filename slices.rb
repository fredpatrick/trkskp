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
require "#{$trkdir}/trk.rb"

class Slices
include Trk
    def initialize(slices_group)
        @slices_group = slices_group
        @slices_data = []
        @slice_faces = []
    end

    def load_existing_slices
        $logfile.puts "slices.load_existing_slices, @slices_data = #{@slices_data}"
        pts          = []
        @slice_count = @slices_group.get_attribute("SlicesAttributes", "slice_count")
        $logfile.puts "slices.load_existing_slices, slice_count = #{@slice_count}"
        @slices_data = []
        @slices_group.entities.each { |e|
            if e.is_a? Sketchup::Face
                $logfile.puts "slices.load_existing_slices, #{print_face(e)}"
                slice_index  = e.get_attribute("SliceAttributes", "slice_index")
                @slice_faces[slice_index] = e
                @slices_data[slice_index] = []
                vertices    = e.vertices
                vertices.each_with_index{ |v,i| @slices_data[slice_index][i] = v.position }
            end
        }
        #puts to_s
    end
    
    def print_faces
        $logfile.puts count_faces(@slices_group.entities,1)
        @slices_group.entities.each { |e|
            if e.is_a? Sketchup::Face
                ix = e.get_attribute("SliceAttributes", "slice_index")
                vtxs = e.vertices
                $logfile.puts " slice_index = #{ix} - #{vtxs[0].position} " + 
                                      " #{vtxs[1].position} #{vtxs[2].position}"
            end
        }
    end

    def to_s
        str =  "\n\n slice_count = #@{slice_count}\n"
        @slice_count.times{ |n|
            pts = @slices_data[n]
            str = str +  " n = #{n}, #{pts[0]}, #{pts[1]}, #{pts[2]}, #{pts[3]}, #{pts[4]}\n"
        }
        return str
    end

    def center_line
        sc = []
        nt = @slices_data.length
        nt.times { |n|
            sc[n] = @slices_data[n][1]
        }
        return sc
    end

    def right_edge
        sr = []
        nt = @slices_data.length
        nt.times { |n|
            sr[n] = @slices_data[n][0]
        }
        return sr
    end

    def left_edge
        sl = []
        nt = @slices_data.length
        nt.times { |n|
            sl[n] = @slices_data[n][2]
        }
        return sl
    end

    def distance
        #puts "slices.distance"
        @ss    = []
        @ss[0] = 0.0
        nt = @slices_data.length
        (nt-1).times{ |n|
            ds = @slices_data[n][1].distance @slices_data[n+1][1]
            @ss[n+1] = @ss[n] + ds
        }
        return @ss
    end

    def slope(slice_index)
        section_guid = @slice_faces[slice_index].get_attribute("SliceAttributes", 
                                                               "section_guid")
        section_group = Section.section(section_guid).section_group
        slope         = section_group.get_attribute("SectionAttributes", "slope")
        return slope
    end

    def edge_location(pick_location, face_code)
        $logfile.puts "slices.edge_location - ##############################" +
                  " begin edge_location ###################"
        $logfile.puts " slices_data"
        $logfile.puts to_s
        puts "edge_location face_code = #{face_code}" 
        slice_index = (face_code / 100.0).floor
        m           = face_code - slice_index * 100
        edge_point  = Geom::Point3d.new(0.0, 0.0, 0.0)
        edge_normal = Geom::Vector3d.new( 1.0, 0.0, 0.0)
        puts "slices.edge_location, pick_location = #{pick_location}, m = #{m}"
        $logfile.puts "slices.edge_location, pick_location = #{pick_location}, m = #{m}"
        pts = @slices_data[slice_index]
        puts "slices.edge_location, slice_index = #{slice_index}, " +
                              "#{pts[0]}, #{pts[1]}, #{pts[2]}" 
        $logfile.puts "slices.edge_location, slice_index = #{slice_index}, " +
                              "#{pts[0]}, #{pts[1]}, #{pts[2]}" 
        ss_pt0 = @slices_data[slice_index  ][1]
        ss_pt1 = @slices_data[slice_index+1][1]
        s_point = pick_location.project_to_line( [ss_pt0, ss_pt1] )
        if m == 2 || m == 3
            sr_pt0 = @slices_data[slice_index  ][0]
            sr_pt1 = @slices_data[slice_index+1][0]
            $logfile.puts "edge_location, sr_pt0 = #{sr_pt0}, sr_pt1 = #{sr_pt1}"
            $logfile.puts "edge_location, sr_pt0 = #{sr_pt0}, sr_pt1 = #{sr_pt1}"
            line = [sr_pt0, sr_pt1]
            edge_point = pick_location.project_to_line(line)
        elsif m == 4 || m == 5
            sl_pt0 = @slices_data[slice_index  ][2]
            sl_pt1 = @slices_data[slice_index+1][2]
            line = [sl_pt0, sl_pt1]
            edge_point = pick_location.project_to_line(line)
        else
            return nil
        end
        edge_normal = Geom::Vector3d.new(edge_point - s_point).normalize!
        puts "edge_location, edge_point = #{edge_point}, edge_normal = #{edge_normal}"
        $logfile.puts "edge_location, edge_point = #{edge_point}, edge_normal = #{edge_normal}"
        puts @ss[slice_index]
        puts @slices_data[slice_index][1]
        ds = @slices_data[slice_index][1].distance(s_point)
        puts ds
        ss = @ss[slice_index] + @slices_data[slice_index][1].distance(s_point)
        return [slice_index, edge_point, edge_normal, s_point, ss]
    end
end
