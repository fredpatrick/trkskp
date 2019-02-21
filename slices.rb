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
require "#{$trkdir}/trk.rb"

class Slices
include Trk
    def initialize(slices_group)
        @slices_group = slices_group
        @slices_data = []
        @slice_faces = []
        @slice_index_bgn = []
        @slice_index_end = []
        @sections        = []               #   section = @sections[slice_index]
        @dt              = []
        @ds              = []
        @slope           = []
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

        section_index_z = 9999
        slice_count     = @slice_faces.length 
        @section_guids = @slices_group.get_attribute("SlicesAttributes", "section_guids")
        if @section_guids.nil?
            puts "load_existing_slice, @section_guids is ni;"
            @section_guids =[]
        end

        (@section_guids.length - 1).times do |j|
            guid          = @section_guids[j][1]
            section       = Section.section(guid)
            sg            = section.section_group
            nslice        = section.segment_count + 1
            slice_index_0 = @section_guids[j  ][0]
            slice_index_1 = @section_guids[j+1][0]
            i             = slice_index_0
            while i < slice_index_1
                @slice_index_bgn[i] = slice_index_0
                @slice_index_end[i] = slice_index_1
                @sections[i]        = Section.section(@section_guids[j][1])
                i += 1
            end
        end
        @slices_sections = []
        @section_guids.each_with_index do |sg, i|
            section = Section.section(sg[1])
            if section.nil?
                puts "load_existing_slices, i = #{i}, section nil for #{sg[1]}"
            end
            @slices_sections << [sg[0], section]
        end
    end

    def make_slice_faces(slice_profile, slice_index, section_group, last)
        section         = Section.section(section_group.guid)
        xform_bed_a     = section_group.get_attribute("SectionAttributes", "xform_bed")
        xform_bed       = Geom::Transformation.new(xform_bed_a)
        xform_alpha_a   = section_group.get_attribute("SectionAttributes", "xform_alpha")
        xform_alpha     = Geom::Transformation.new(xform_alpha_a)
        xform_group     = section_group.transformation
        segment_count   = section_group.get_attribute("SectionAttributes", "segment_count")

        pts = []
        slice_profile.each_with_index{ |p,i| pts[i] = p.transform(xform_alpha)}

        slice_pts = []
        (segment_count+1).times do |j|
            slice_pts[j] = Array.new(pts)
            if j == segment_count then break end
            pts.each_with_index { |p,i| pts[i] = p.transform(xform_bed)}
        end
        slice_pts.length.times do |j|
            slice_pts[j].each_with_index{ |p,i| slice_pts[j][i] = p.transform(xform_group)}
        end

        nslice = slice_pts.length - 1
        if last                          # if on last segment terminate with slice
            nslice = slice_pts.length
        end
        
        nslice.times do |n|
            m = n
            if section.slice_ordered_z == "reversed" then m = slice_pts.length - n - 1 end
            slice_edges = []
            l = slice_profile.length
            slice_pts[m].each_with_index do |p,i| 
                es = @slices_group.entities.add_edges(slice_pts[m][i], slice_pts[m][(i+1)%l ] )
                slice_edges[i] = es[0]
                slice_edges[i].hidden = true
            end
            f = @slices_group.entities.add_face(slice_edges)
            f.set_attribute("SliceAttributes", "slice_index", slice_index)
            f.set_attribute("SliceAttributes", "section_guid", section_group.guid)
            slice_index += 1
        end
        @slices_group.set_attribute("SlicesAttributes", "slice_count", slice_index)
        return slice_index
    end

    def make_switch_geometry(switchsection_group)

        sname            = "SectionAttributes"
        slope            = switchsection_group.get_attribute(sname, "slope")
        radius           = switchsection_group.get_attribute(sname, "radius")
        delta            = switchsection_group.get_attribute(sname, "delta")
        arc_degrees      = switchsection_group.get_attribute(sname, "arc_degrees")
        arc_origin       = switchsection_group.get_attribute(sname, "origin")
        arc_count        = switchsection_group.get_attribute(sname, "arc_count")
        ab_length        = switchsection_group.get_attribute(sname, "ab_length")
        a                = switchsection_group.get_attribute(sname, "a")
        direction        = switchsection_group.get_attribute(sname, "direction")
        xform_bed_arc_a  = switchsection_group.get_attribute(sname, "xform_bed_arc")
        xform_bed_arc    = Geom::Transformation.new(xform_bed_arc_a)
        xform_alpha_a    = switchsection_group.get_attribute("SectionAttributes", "xform_alpha")
        xform_alpha      = Geom::Transformation.new(xform_alpha_a)
        xform_group      = switchsection_group.transformation
        base_width       = Base.base_width
        base_thickness   = Base.base_thickness
        base_profile     = Base.base_profile

        l      = ab_length - a
        r      = radius
        rp2    = r +  0.5 * base_width
        rm2    = r -  0.5 * base_width
        theta1 = atan( l / rp2 )
        theta2 = asin( l / rp2 )
        theta3 = arc_degrees * Math::PI / 180.0

        $logfile.puts "base.make_switch_geometry, slope = #{slope}, radius = #{radius}, delta = #{delta}"
        $logfile.puts "base.make_switch_geometry, arc_degrees = #{arc_degrees}, arc_count = #{arc_count}"
        $logfile.puts "base.make_switch_geometry, arc_origin = #{arc_origin}, ab_length = #{ab_length}"
        $logfile.puts "base.make_switch_geometry, a = #{a}, direction = #{direction}"
        $logfile.puts "base.make_switch_geometry, theta1 = #{theta1}, theta2" +
                                                " = #{theta2}, theta3 = #{theta3}"
        $logfile.puts Section.dump_transformation(xform_group, 1)

        lpts        = []
        pts         = []
        slice_index = 0
        base_profile.each_with_index{ |p,i| lpts[i] = p}
        lpts.each_with_index{ |p,i| pts[i] = p.transform xform_group}
        f = @slices_group.entities.add_face(pts)
        f.set_attribute("SliceAttributes", "slice_index", slice_index)
        puts "make_switch_geometry, " + Section.face_to_a(f)
        slice_index += 1

        if  a != 0 
            va = Geom::Vector3d.new(0.0, a, 0.0)
            lpts.each_with_index { |p,i| pts[i] = p + va}
            f = @slices_group.entities.add_face(pts)
            f.set_attribute("SliceAttributes", "slice_index", slice_index)
            slice_index += 1
        end
        
        #set ranges of theta so that slices always hit corners of base
        if direction == "Right"
            delta = -delta
        end
        is0    =slice_index
        n1     = ((theta1)/delta).floor
        is1    = is0 + n1
        delta1 = theta1 / n1
        n2     = ((theta2 - theta1)/delta).floor
        is2    = is1 + n2
        delta2 = (theta2 - theta1) / n2
        n3     = ((theta3 - theta2)/delta).floor
        is3    = is2 + n3
        delta3 = (theta3 - theta2)/ n3
        $logfile.puts "make_switch_geometry, n1 = #{n1}, delta1 = #{delta1}"
        $logfile.puts "make_switch_geometry, n2 = #{n2}, delta2 = #{delta2}"
        $logfile.puts "make_switch_geometry, n3 = #{n3}, delta3 = #{delta3}"

        theta  = 0.0
        ns     = 0
        thetab = 0.0
        deltab = 100.0
        while slice_index >= is0 && slice_index < is3
            if slice_index < is1 
                ns     = n1
                deltab = delta1
                thetab = 0.0
            elsif slice_index >= is1 && slice_index < is2
                ns     = n2
                thetab = theta1
                deltab = delta2
            elsif slice_index >= is2 && slice_index <= is3
                ns     = n3
                deltab = delta3
                thetab = theta2
            end
            ns.times { |n|
                theta = thetab + (n + 1) * deltab
                
                $logfile.puts "base.make_switch_geometry, slice_index = #{slice_index}, "+
                                  "theta = #{theta}"
                $logfile.flush
                                  "theta = #{theta}"
                if direction == "Right"
                    lpts[2] = Geom::Point3d.new(r - rm2*cos(theta), a + rm2*sin(theta), 0.0)
                    lpts[1] = Geom::Point3d.new(r - r*cos(theta), a + r*sin(theta), 0.0)
                    if theta <= theta1
                        lpts[0] = Geom::Point3d.new( -0.5 * base_width, a + rp2*tan(theta), 0.0)
                    elsif theta > theta1 && theta <= theta2
                        lpts[0] = Geom::Point3d.new(r - l / tan(theta), a + l, 0.0)
                    elsif theta > theta2 && theta <= theta3
                        lpts[0] = Geom::Point3d.new(r - rp2*cos(theta), a + rp2*sin(theta), 0.0)
                    end
                else
                    lpts[0] = Geom::Point3d.new(-r + rm2*cos(theta), a + rm2*sin(theta), 0.0)
                    lpts[1] = Geom::Point3d.new(-r + r*cos(theta), a + r*sin(theta), 0.0)
                    if theta <= theta1
                        lpts[2] = Geom::Point3d.new(  0.5 * base_width, a + rp2*tan(theta), 0.0)
                    elsif theta > theta1 && theta <= theta2
                        lpts[2] = Geom::Point3d.new(-r + l / tan(theta), a + l, 0.0)
                    elsif theta > theta2 && theta <= theta3
                        lpts[2] = Geom::Point3d.new(-r + rp2*cos(theta), a + rp2*sin(theta), 0.0)
                    end
                end
                lpts[3] = lpts[2] + Geom::Vector3d.new(0.0, 0.0, -base_thickness)
                lpts[4] = lpts[0] + Geom::Vector3d.new(0.0, 0.0, -base_thickness)
                lpts.each_with_index { |p,i| pts[i] = p.transform xform_group}
                f = @slices_group.entities.add_face(pts)
                f.set_attribute("SliceAttributes", "slice_index", slice_index)
                f.edges.each{ |e| e.hidden = true }
                slice_index += 1
            }
        end
        @slices_group.set_attribute("SlicesAttributes", "slice_count", slice_index)
        @slices_group.set_attribute("SlicesAttributes", "section_guids", [])
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

    def section_pts(section_index_z, last = false)
        
        slice_data  = @slices_sections[section_index_z]
        slice_index = slice_data[0]
        section     = slice_data[1]
        slice       = @slices_data[slice_index]
        return [slice[0], slice[1], slice[2]]
    end

    def section(slice_index)
        return @sections[slice_index]
    end

    def section_count
        return @slices_sections.length
    end
    def inline_point(slice_index)
        return @slices_data[slice_index][1]
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

    def slice_points(slice_index)
        pts = []
        5.times { |j| pts[j] = @slices_data[slice_index][j] }
        return pts
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

    def centerline_distance(slice_index)
        return @ss[slice_index]
    end

    def slope(slice_index)
        section_guid = @slice_faces[slice_index].get_attribute("SliceAttributes", 
                                                               "section_guid")
        section_group = Section.section(section_guid).section_group
        slope         = section_group.get_attribute("SectionAttributes", "slope")
        return slope
    end

#   def test_continuous_slope
#       @ss.each_with_index { |s,i| puts "test_continuous_slope,  #{i} - #{s} - slope = #{continuous_slope(s)}" }
#   end

#   def continuous_slope(s)
#       if @dt.length == 0
#           section_count = @section_guids.length - 2
#           puts "continuous_slope, section_count = #{section_count}"
#           @section_guids.each_with_index do |sg,j|
#               break if j == @section_guids.length - 1
#               guid          = sg[1]
#               slice_index   = sg[0]
#               section       = Section.section(guid)
#               @slope[j+1]   = section.slope
#               @ds[j]        = centerline_distance(slice_index)
#               puts "continuous_slope, #{j} - ds = #{@ds[j]}, slope = #{@slope[j]}"
#           end
#           puts "continuous_slope, @ ds length = #{@ds.length}"
#           @dt[0]    = 0.0
#           @slope[0] = 0.0
#           @ds.each_with_index do |s,l|
#               break if l == @ds.length - 1
#               @dt[l+1] = 0.5 * ( @ds[l] +@ds[l+1] )
#           end
#           @dt[section_count + 1]    = @ds[section_count]
#           @slope[section_count + 1] = 0.0
#           @dt.each_with_index { |t,l| puts " #{l} - dt = #{t}" }
#       end

#       @dt.each_with_index do |d,l|
#           break if l == @dt.length-1
#           if s >= @dt[l] && s <= @dt[l+1]
#               slope = @slope[l] * (@dt[l+1] - s) / (@dt[l+1] -@dt[l]) +
#                       @slope[l+1] * (s - @dt[l]) / (@dt[l+1] -@dt[l])
#               return slope
#           end
#       end
#   end


    def secondary_centerline_point(q, slice_index_0, slope)
        sc =  center_line
        d  = []
        nslice = sc.length
        jj = 1
        je = nslice -1
        if slope >= 0 
            jj = -1
            je = 0
        end
        slice_index = slice_index_0 + jj * 10
        jmin        = -1
        dmin        = 0.1
        while slice_index != je do
            p = sc[slice_index]
            d[slice_index] = Math::sqrt((p.x - q.x)**2 + (p.y - q.y)**2 )
            if d[slice_index] < dmin
                dmin = d[slice_index]
                jmin = slice_index
            end
            slice_index += jj
        end
        if jmin != -1
            puts "slices.secondary_centerline_point, jmin-1 = #{jmin-1}, d = #{d[jmin-1]}"
            puts "slices.secondary_centerline_point, jmin = #{jmin},     dmin = #{dmin}"
            puts "slices.secondary_centerline_point, jmin+1 = #{jmin+1}, d = #{d[jmin+1]}"
        else
            puts "slices.secondary_centerline_point, jmin = -1 no secondary point found"
        end
        return jmin
    end


    def edge_location(pick_location, slice_index, side)
        $logfile.puts "slices.edge_location - ##############################" +
                  " begin edge_location ###################"
        $logfile.puts " slices_data"
        $logfile.puts to_s
        edge_point  = Geom::Point3d.new(0.0, 0.0, 0.0)
        edge_normal = Geom::Vector3d.new( 1.0, 0.0, 0.0)
        puts "slices.edge_location, pick_location = #{pick_location}, side = #{side}"
        $logfile.puts "slices.edge_location, pick_location = #{pick_location}, side = #{side}"
        if slice_index < @slices_data.length - 1
            ss_pt0 = @slices_data[slice_index  ][1]
            ss_pt1 = @slices_data[slice_index+1][1]
            s_point = pick_location.project_to_line( [ss_pt0, ss_pt1] )
            if side == "right"
                sr_pt0 = @slices_data[slice_index  ][2]
                sr_pt1 = @slices_data[slice_index+1][2]
                line = [sr_pt0, sr_pt1]
                edge_point = pick_location.project_to_line(line)
            elsif side == "left"
                sl_pt0 = @slices_data[slice_index  ][0]
                sl_pt1 = @slices_data[slice_index+1][0]
                line = [sl_pt0, sl_pt1]
                edge_point = pick_location.project_to_line(line)
            else
                return nil
            end
        elsif slice_index == @slices_data.length - 1
            s_point = @slices_data[slice_index][1]
            if side == "right"
                edge_point = @slices_data[slice_index][2]
            elsif side == "left"
                edge_point = @slices_data[slice_index][0]
            else
                return nil
            end
        end
        edge_normal = Geom::Vector3d.new(edge_point - s_point).normalize!
        ds = @slices_data[slice_index][1].distance(s_point)
        ss = @ss[slice_index] + @slices_data[slice_index][1].distance(s_point)
        return [slice_index, edge_point, edge_normal, s_point, ss]
    end

    def new_basedata(pick_location, facecode, pick_mode)
        basedata              = Hash.new
        basedata["pick_mode"] = pick_mode
        basedata["facecode"]  = facecode
        slice_index           = (facecode / 100.0).floor
        m                     = facecode - slice_index*100
        edge_point            = Geom::Point3d.new(0.0, 0.0, 0.0)
        pick_slice            = []
        if pick_mode == "pick"
            if slice_index < @slices_data.length - 1
                slice_a = @slices_data[slice_index  ]
                slice_a.each_with_index { |p,i| puts "new_basedata, slice_a #{i} - #{p}" }
                slice_b = @slices_data[slice_index+1]
                slice_b.each_with_index { |p,i| puts "new_basedata, slice_b #{i} - #{p}" }
                slice_a.each_with_index do |pa,i|
                    pb = slice_b[i]
                    pick_slice[i] = pick_location.project_to_line([pa,pb])
                    puts " #{i} #{pa}    #{pick_slice[i]}   #{pb} " 
                end
            elsif slice_index == @slices_data.length - 1
                pick_slice = @slices_data[slice_index]
            end
        elsif pick_mode == "nearest_section"
            slice_index = section_slice_index(pick_location, slice_index)
            pick_slice  = @slices_data[slice_index]
        else
            puts "new_basedata, unknown pick_mode = #{pick_mode}"
        end
        #pick_slice.each_with_index { |p,i| puts "new_basedata, pick_slice #{i} - #{p}" }
        basedata["attach_point"] = Geom.linear_combination(0.5, pick_slice[3], 
                                                           0.5, pick_slice[4])
        l_point          = pick_slice[0]
        centerline_point = pick_slice[1]
        r_point          = pick_slice[2]
        if m == 0 || m == 1
            basedata["side"]       = "left"
            basedata["edge_point"] = l_point
        else
            basedata["side"]       = "right"
            basedata["edge_point"] = r_point
        end
        ds = @slices_data[slice_index][1].distance(centerline_point)
        ss = @ss[slice_index] + @slices_data[slice_index][1].distance(centerline_point)
        basedata["pick_location"]    = pick_location
        basedata["slice_index"]      = slice_index
        basedata["centerline_point"] = centerline_point
        basedata["inline_coord"]     = ss
        basedata["attach_crossline"] = Geom::Vector3d.new(l_point - centerline_point).normalize!
        v0 = inline(slice_index-1)
        v1 = inline(slice_index)
        basedata["attach_inline"]    = inline(slice_index)
        basedata["slope"]            = slope(slice_index)
        return basedata
    end

    def section_slice_index(position_t, slice_index_t)
        slice_index_0      = @slice_index_bgn[slice_index_t]
        slice_index_1      = @slice_index_end[slice_index_t]
        centerline_point_0 = @slices_data[slice_index_0][1]
        centerline_point_1 = @slices_data[slice_index_1][1]
        ds0                = position_t.distance(centerline_point_0)
        ds1                = position_t.distance(centerline_point_1)
        if ds0 < ds1
            return slice_index_0
        else
            return slice_index_1
        end
    end

    def inline(slice_index)
        ia = slice_index
        if slice_index == @slices_data.length - 1
            ia  = slice_index - 1
        end
        pa = @slices_data[ia-1][1]
        pb = @slices_data[ia+1][1]
        return Geom::Vector3d.new(pb - pa).normalize
    end
    
    def report_slice_data

        guids = []
        p     = []
        q     = []
        s     = []
        @slices_group.entities.each do |e|
            if e.is_a? Sketchup::Face
                slice_index  = e.get_attribute("SliceAttributes", "slice_index")
                section_guid = e.get_attribute("SliceAttributes", "section_guid")
                pts          = []
                vertices     = e.vertices
                vertices.each_with_index { |v,i| pts[i] = v.position }
                guids[slice_index] = section_guid
                p[slice_index]     = pts[1]
                q[slice_index]     = Geom.linear_combination(0.5, pts[3], 0.5, pts[4])
            end
        end
        s[0] = 0.0
        p.each_with_index do |pt,n| 
            if n > 0
                s[n] = s[n-1] + p[n-1].distance(pt)
            end
        end

        output = []
        guid = ""
        (s.length).times  do |n|
            if guids[n] != guid || n == s.length-1

                guid = guids[n]
                section = Section.section(guid)
                output << [n, s[n], p[n], q[n], section.section_index_z ]
            end
        end

        thresholds = [0.0, 0.71875]
        slice_count = p.length
        thresholds.each_with_index do |t|
            (slice_count - 2).times do |n|
                if test_threshold( t, p[n].z, p[n+1].z)
                    r  = (t - p[n].z ) / (p[n+1].z - p[n].z )
                    sr = s[n] + r * (s[n+1] - s[n])
                    pr = p[n] + Geom::Vector3d.new(r*(p[n+1].x - p[n].x),
                                                   r*(p[n+1].y - p[n].y),
                                                   r*(p[n+1].z - p[n].z))
                    output << [ -999, sr, pr, "skip", t]
                end
            end
        end

        thresholds.each_with_index do |t|
            (slice_count - 2).times do |n|
                if test_threshold( t, q[n].z, q[n+1].z)
                    r  = (t - q[n].z ) / (q[n+1].z - q[n].z )
                    sr = s[n] + r * (s[n+1] - s[n])
                    qr = q[n] + Geom::Vector3d.new(r*(q[n+1].x - q[n].x),
                                                   r*(q[n+1].y - q[n].y),
                                                   r*(q[n+1].z - q[n].z))
                    output << [ -999, sr, "skip", qr, t]
                end
            end
        end

        section = Section.section(guids[0])
        zone    = section.zone
        start_switch = $switches.switch(zone.start_switch_guid)
        start_switch_name = start_switch.switch_name
        puts "Slices Data for zone = #{zone.zone_name}, starting at switch #{start_switch_name}"
        puts "        slice   ss            top of base            bottom of base"
        #output.each_with_index do |line, j|
        ss = output.sort_by { |x| x[1]}
        ss.each_with_index do |line, j|
            str = sprintf(" %4d", j)
            if line[0] != -999
                str += sprintf(" %4d", line[0])
            else
                str += sprintf(" %4s", "    ")
            end
            str += sprintf(" %8.3f", line[1])
            if line [2] != "skip"
                str += sprintf(" (%8.3f %8.3f %8.3f )", line[2].x, line[2].y, line[2].z)
            else 
                str += sprintf("%13s -- %13s", " ", " ")
            end
            if line [3] != "skip"
                str += sprintf(" (%8.3f %8.3f %8.3f )", line[3].x, line[3].y, line[3].z)
            else 
                str += sprintf("%13s -- %13s", " ", " ")
            end
            if line[0] != -999
                str += " section_index_z = #{line[4]}"
            else
                str += " threshold       = #{line[4]}"
            end
            puts str
        end
    end
    def test_threshold(t, z0, z1)
        found = false
        if z0 < z1
            if t > z0 && t <= z1
                found = true
            end
         else
            if t < z0 && t >= z1
                found = true
            end
        end
        return found
    end
        

end
