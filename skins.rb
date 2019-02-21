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

class Skins
include Trk
    def initialize(skins_group)
        @skins_group = skins_group
    end

    def load_existing_skins
        load_faces
    end

    def make_skins_faces(slices_group, skins_material)
        slice_list = []
        slices_group.entities.each do |e|
            if e.is_a? Sketchup::Face 
                slice_index = e.get_attribute("SliceAttributes", "slice_index")
                slice_list[slice_index] = e
            end
        end
        vertices      = slice_list[0].vertices
        l             = vertices.length
        p0            = []
        p1            = []
        slice_edges_0 = []
        vertices.each_with_index{ |v,i| p0[i] = v.position}
        l.times{ |i| slice_edges_0[i] = @skins_group.entities.add_edges(p0[i], p0[(i+1)%l])[0] }
        nslice = slice_list.length
        (nslice-1).times do |j|
            vertices      = slice_list[j+1].vertices
            vertices.each_with_index{ |v,i| p1[i] = v.position}
            slice_edges_1  = []
            side_edges     = []
            diagonal_edges = []
            l.times do |i|
                slice_edges_1[i]    = @skins_group.entities.add_edges(p1[i], p1[(i+1)%l])[0]
                side_edges[i]       = @skins_group.entities.add_edges(p0[i], p1[i])[0]
                diagonal_edges[i]   = @skins_group.entities.add_edges(p0[i], p1[(i+1)%l])[0]
                slice_edges_1[i].hidden  = true
                side_edges[i].hidden     = false
                diagonal_edges[i].hidden = true
            end
            l.times do |i|
                skin_face_a = @skins_group.entities.add_face(diagonal_edges[i],
                                                             slice_edges_1[i],
                                                             side_edges[i] )
                skin_face_b = @skins_group.entities.add_face(slice_edges_0[i],
                                                             side_edges[(i+1)%l],
                                                             diagonal_edges[i])
                skin_face_a.material      = skins_material
                skin_face_a.back_material = skins_material
                skin_face_a.set_attribute("FaceAttributes", "face_code", j*100 + i*2)
                skin_face_b.material      = skins_material
                skin_face_b.back_material = skins_material
                skin_face_b.set_attribute("FaceAttributes", "face_code", j*100 + i*2 + 1)
            end
            side_edges[1].set_attribute("EdgeAttributes", "centerline?", true)
            side_edges[1].set_attribute("EdgeAttribuites", "slice_index", j)
            slice_edges_0 = slice_edges_1
            p0            = Array.new(p1)
        end
    end

    def load_faces
        @faces = []
        n     = 0
        jf = nil
        @skins_group.entities.each_with_index do |e,i|
            if e.is_a? Sketchup::Face
                facecode = e.get_attribute("FaceAttributes", "face_code")
                slice_index = (facecode / 100.0).floor
                m           = facecode - slice_index*100
                jf = slice_index * 10 + m
                @faces[jf] = e
                n += 1
            end
        end
        puts "skins.load_faces # of faces = #{n}, if = #{jf}, #{@faces.length}"
    end

    def skin_face(slice_index, m)
        return @faces[slice_index*10 + m]
    end

    def search_skins_faces(base, basedata, slices)
        puts "################################################################################"
        puts "######################################search_skins_faces########################"
        q    = basedata["centerline_point"]
        sndx = basedata["slice_index"]
        puts "skins.search_skins_faces, slice_index = #{sndx},  q = #{q}"
        q = Geom::Point3d.new(q.x-0.001, q.y-0.001,q.z)
        puts "skins.search_skins_faces, slice_index = #{sndx},  q = #{q}"
        slice_index_last = -999
        n = (sndx-10)*10
        while n >= 0 do
            f = @faces[n]
            if f.is_a? Sketchup::Face
                plane = f.plane
                p     = q.project_to_plane(plane)
                ip    = f.classify_point(p)
                if ip != Sketchup::Face::PointOutside
                    facecode = f.get_attribute("FaceAttributes", "face_code")
                    tag = ""
                    if ip == Sketchup::Face::PointInside
                        tag = "PointInside"
                    elsif ip == Sketchup::Face::PointOnEdge
                        tag = "PointOnEdge"
                    elsif ip == Sketchup::Face::PointOnVertex
                        tag = "PointOnVertex"
                    end
                    slice_index = (facecode / 100.0).floor
                    m           = facecode - slice_index*100
                    if slice_index != slice_index_last
                        pts = slices.slice_points(slice_index)
                        puts "skins.search_skins_faces, slice points---- " +
                                "slice_index = #{slice_index}, " + "facecode = #{facecode}"
                        pts.each_with_index { |p,j| puts "       #{1} - #{pts[j]}" }
                        slice_index_last = slice_index
                    end
                    puts "skins.search_skins_faces slice_index = #{slice_index}, m = #{m}" +
                                   ", type = #{tag}, p = #{p}"
                    puts "skins.search_skins_faces, face points"
                    f.vertices.each_with_index { |v,j| puts "  j - #{j}, #{v.position}" }
                    basedata_1 = slices.new_basedata(p, facecode, "pick")
                    puts base.basedata_to_s(basedata_1)
                    STDOUT.flush
                end
            end
            n =  n - 1
        end
    end
end

