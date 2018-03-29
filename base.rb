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
require 'langhandler.rb'
require "#{$trkdir}/section.rb"
require "#{$trkdir}/zone.rb"
require "#{$trkdir}/risertab.rb"
require "#{$trkdir}/slices.rb"
require "#{$trkdir}/trk.rb"

$exStrings = LanguageHandler.new("track.strings")

include Math
include Trk

class Base 

    def Base.init_class_variables
        model  = Sketchup.active_model
        mattrs = model.attribute_dictionary( "BaseAttributes" )
        if mattrs
            puts "Base.init_class_variables, found attribute dictionary"
            @@base_width     = model.get_attribute("BaseAttributes", "base_width")
            @@base_thickness = model.get_attribute("BaseAttributes", "base_thickness")
            @@base_material  = model.get_attribute("BaseAttributes", "base_material")
            @@base_profile   = model.get_attribute("BaseAttributes", "base_profile")
            @@risertab_count = model.get_attribute("BaseAttributes", "risertab_count")
        else
            puts "Base.init_class_variables, didnt find attribute dictionary"
            mattrs           = model.attribute_dictionary( "BaseAttributes", true)
            @@base_width     = model.set_attribute("BaseAttributes", "base_width",    4.0)
            @@base_thickness = model.set_attribute("BaseAttributes", "base_thickness", 0.21875)
            @@base_material  = model.set_attribute("BaseAttributes", "base_material",
                                                                           "DarkGoldenrod")
            @@base_profile   = model.set_attribute("BaseAttributes", "base_profile",
                                [Geom::Point3d.new(-@@base_width * 0.5, 0.0, 0.0),
                                 Geom::Point3d.new( 0.0,                0.0, 0.0),
                                 Geom::Point3d.new( @@base_width * 0.5, 0.0, 0.0),
                                 Geom::Point3d.new( @@base_width * 0.5, 0.0, -@@base_thickness),
                                 Geom::Point3d.new(-@@base_width * 0.5, 0.0, -@@base_thickness)])
            @@risertab_count = model.set_attribute("BaseAttributes", "risertab_count", 0)
        end
        @@risertabs = Hash.new
        layers = model.layers
        layers.add "base"
    end
    def Base.base_width
        return @@base_width
    end
    def Base.base_thickness
        return @@base_thickness
    end
    def Base.base_profile 
        return @@base_profile
    end
    def Base.base_material
        return @@base_material
    end
    def Base.risertab_count
        return @@risertab_count
    end
    def Base.increment_risertab_count
        @@risertab_count += 1
        Sketchup.active_model.set_attribute("BaseAttributes","risertab_count", @@risertab_count)
        return @@risertab_count
    end
    def Base.risertab_path?(ph)
        #puts "Base.risertab_path?, searching for risertab"
        ans = search_paths(ph, "risertab")
        if ans
            #puts "Base.risertab_path?, found risertab"
            risertab_group = ans[0]
            risertab       = @@risertabs[risertab_group.guid]
            return risertab
        end
        return nil
    end
    def Base.risertab(guid)
        return @@risertabs[guid]
    end

    def initialize(base_group, parent=nil, switchsection=nil)
        @base_group         = base_group
        if parent
            @slices_group       = @base_group.entities.add_group
            @slices_group.name  = "slices"
            @skins_group        = @base_group.entities.add_group
            @skins_group.name   = "skins"

            if parent.is_a? Zone
                @zone       = parent
                slice_index = 0
                last        = false
                @zone.traverse_zone { |s, last|
                    slice_index = make_build_geometry(@slices_group, @@base_profile, 
                                                      slice_index, s, last)
                    puts "base.initialize, slice_index = #{slice_index}"
                }
                puts count_faces(@slices_group.entities,1)
                @slices = Slices.new(@slices_group)
                @slices.load_existing_slices
                @slices.distance
                @slices.print_faces

                @slices_group.entities.each { |e|
                    if e.is_a? Sketchup::Face
                        ix = e.get_attribute("SliceAttributes", "slice_index")
                        vtxs = e.vertices
                        puts " slice_index = #{ix} - #{vtxs[0].position} " + 
                                              " #{vtxs[1].position} #{vtxs[2].position}"
                    end
                }
                puts "base.initialize, geometry made, slices in slices_group"
                make_skins(@slices_group, @skins_group, @@base_material)
            else
                make_switch_geometry(@slices_group, switchsection.section_group)
                make_skins(@slices_group, @skins_group, @@base_material)
            end
        else
            load_existing_base
        end
    end
    def load_existing_base
        puts "base.load_existing_base"
        @base_group.entities.each { |e|
            if e.is_a? Sketchup::Group
                if e.name == "slices"
                    puts "base.load_existing_base, found slices_group, guid = #{e.guid}"
                    @slices_group = e
                    @slices       = Slices.new(@slices_group)
                    @slices.load_existing_slices
                    @slices.distance
                elsif e.name == "skins"
                    @skins_group  = e
                elsif e.name == "risertab"
                    risertab = RiserTab.new("load", e)
                    @@risertabs[risertab.guid] = risertab
                end
            end
        }
        #print_skins(@skins_group)
    end
    def guid
        return @base_group.guid
    end
    def make_build_geometry( slices_group, profile, slice_index, section_group, last)

        section         = Section.section(section_group.guid)
        sname           = "SectionAttributes"
        xform_bed_a     = section_group.get_attribute("SectionAttributes", "xform_bed")
        xform_bed       = Geom::Transformation.new(xform_bed_a)
        xform_alpha_a   = section_group.get_attribute("SectionAttributes", "xform_alpha")
        xform_alpha     = Geom::Transformation.new(xform_alpha_a)
        xform_group     = section_group.transformation
        segment_count   = section_group.get_attribute("SectionAttributes", "segment_count")
        slice_ordered_z = section.slice_ordered_z

        section_guid    = section_group.guid
        section_index_g = section.section_index_g
        section_index_z = section.section_index_z
        puts "base.make_build_geometry ################# Begin section ixg = " +
               " #{section_index_g} ################" 
        puts "    section_index_g = #{section_index_g}"
        puts "    section_index_z = #{section_index_z}"
        puts "    last            = #{last}"
        puts "    slice_ordered_z = #{slice_ordered_z}"
        puts "    segment_count   = #{segment_count}"
        puts "    slice_index     = #{slice_index}"
        puts "    xform_group     = }"
        puts Section.dump_transformation(xform_group, 1)

        slices = []
        lpts = []
        rpts = []
        profile.each_with_index{ |p,i| lpts[i] = p.transform xform_alpha}
        
        ns = segment_count + 1
        ns.times { |j|
            slices[j] = Array.new(lpts)
            slices[j].each_with_index { |p,i| slices[j][i] = p.transform xform_group }
            puts "slice[j], j = #{j} - #{slices[j][0]} #{slices[j][1]} #{slices[j][2]} "
            if j == ns -1
                break
            end

            lpts.each_with_index { |p,i| rpts[i] = p.transform xform_bed}
            rpts.each_with_index { |p,i| lpts[i] = p }
        }
        nt = slices.length - 1
        if last 
            nt = slices.length
        end
        nt.times { |n|
            m = n
            if slice_ordered_z == "reversed"
                m = slices.length - n - 1
            end
            f = slices_group.entities.add_face(slices[m])
            f.set_attribute("SliceAttributes", "slice_index",  slice_index)
            f.set_attribute("SliceAttributes", "section_guid", section_guid)
            puts "add_face, slice_index = #{slice_index}, m = #{m}"
            slice_index += 1
        }
        slices_group.set_attribute("SlicesAttributes", "slice_count", slice_index)
        return slice_index
    end
    def make_switch_geometry(slices_group, switchsection_group)

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

        puts "base.make_switch_geometry, slope = #{slope}, radius = #{radius}, delta = #{delta}"
        puts "base.make_switch_geometry, arc_degrees = #{arc_degrees}, arc_count = #{arc_count}"
        puts "base.make_switch_geometry, arc_origin = #{arc_origin}, ab_length = #{ab_length}"
        puts "base.make_switch_geometry, a = #{a}, direction = #{direction}"
        puts "base.make_switch_geometry, theta1 = #{theta1}, theta2" +
                                                " = #{theta2}, theta3 = #{theta3}"
        puts Section.dump_transformation(xform_group, 1)
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
        f = slices_group.entities.add_face(pts)
        f.set_attribute("SliceAttributes", "slice_index", slice_index)
        puts "make_switch_geometry, " + Section.face_to_a(f)
        slice_index += 1

        if  a != 0 
            va = Geom::Vector3d.new(0.0, a, 0.0)
            lpts.each_with_index { |p,i| pts[i] = p + va}
            f = slices_group.entities.add_face(pts)
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
        puts "make_switch_geometry, n1 = #{n1}, delta1 = #{delta1}"
        puts "make_switch_geometry, n2 = #{n2}, delta2 = #{delta2}"
        puts "make_switch_geometry, n3 = #{n3}, delta3 = #{delta3}"
        $logfile.puts "make_switch_geometry, n1 = #{n1}, delta1 = #{delta1}"
        $logfile.puts "make_switch_geometry, n2 = #{n2}, delta2 = #{delta2}"
        $logfile.puts "make_switch_geometry, n3 = #{n3}, delta3 = #{delta3}"

        theta  = 0.0
        ns     = 0
        thetab = 0.0
        deltab = 100.0
        while slice_index >= is0 && slice_index < is3
            if slice_index < is1 
                puts "base.make_switch_geometry, in range1"
                ns     = n1
                deltab = delta1
                thetab = 0.0
            elsif slice_index >= is1 && slice_index < is2
                puts "base.make_switch_geometry, in range2"
                ns     = n2
                thetab = theta1
                deltab = delta2
            elsif slice_index >= is2 && slice_index <= is3
                puts "base.make_switch_geometry, in range3"
                ns     = n3
                deltab = delta3
                thetab = theta2
            end
            ns.times { |n|
                puts "base.make_switch_geometry, n = #{n}, ns = #{ns}, thetab = #{thetab}, " +
                                      "deltab = #{deltab}"
                theta = thetab + (n + 1) * deltab
                
                $logfile.puts "base.make_switch_geometry, slice_index = #{slice_index}, "+
                                  "theta = #{theta}"
                $logfile.flush
                puts "base.make_switch_geometry, theta = #{theta}"
                puts "base.make_switch_geometry, slice_index = #{slice_index}, "+
                                  "theta = #{theta}"
                if direction == "Right"
                    puts "base.make_switch_geometry, making Right switch base"
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
                puts "pts, n = #{n} - #{lpts[0]} #{lpts[1]} #{lpts[2]}  #{lpts[3]} #{lpts[4]} "
                lpts.each_with_index { |p,i| pts[i] = p.transform xform_group}
                puts "pts, n = #{n} - #{pts[0]} #{pts[1]} #{pts[2]}  #{pts[3]} #{pts[4]} "
                f = slices_group.entities.add_face(pts)
                f.set_attribute("SliceAttributes", "slice_index", slice_index)
                slice_index += 1
            }
        end
        slices_group.set_attribute("SlicesAttributes", "slice_count", slice_index)
    end

    def make_skins( slices_group, skins_group, face_mat)
        slice_list = []
        slices_group.entities.each { |e|
            if ( e.is_a? Sketchup::Face )
                slice_index = e.get_attribute("SliceAttributes", "slice_index")
                puts "zone.make_skins, slice_index = #{slice_index}"
                puts Section.face_to_a(e)
                slice_list[slice_index] = e
                puts "zone.make_skins, slice_list.length = #{slice_list.length}"
            end
        }
        ns = slice_list.length
        puts "zone.make_skins, ns = #{ns}"
        n  = 0
        lpts = []
        rpts = []
        while n < ns - 1
            puts "zone.make_skins, n = #{n}"
            slice = slice_list[n]
            slice.vertices.each_with_index { |v,i| lpts[i] = v.position}
            slice = slice_list[n + 1]
            slice.vertices.each_with_index { |v,i| rpts[i] = v.position}
        
            nr   = lpts.length
            i = 0
            while i < nr
                skins_group.entities.add_edges( lpts[i], rpts[i])
                edges = skins_group.entities.add_edges(rpts[i - 1], rpts[i])
                edges[0].hidden = true
                puts "zone.make_skins, n = #{n}, i = #{i}, lpts[i-1] = #{lpts[i-1]}," +
                           " lpts[i] = #{lpts[i]}, rpts[i] = #{rpts[i]}"
                face_1 = skins_group.entities.add_face(lpts[i-1], lpts[i], rpts[i])
                face_1.material = face_mat
                face_1.back_material = face_mat
                face_2 = skins_group.entities.add_face(lpts[i-1], rpts[i], rpts[i-1])
                face_2.material = face_mat
                face_2.back_material = face_mat
                face_1.set_attribute("FaceAttributes", "face_code", n*100 + i*2)
                face_2.set_attribute("FaceAttributes", "face_code", n*100 + i*2 +1)
                edges = skins_group.entities.add_edges(lpts[i-1], rpts[i])
                edges[0].hidden = true
                i  += 1
            end
            n += 1
        end
    end 

    def print_skins(skins_group)
        skins_group.entities.each { |f|
            if f.is_a? Sketchup::Face
                face_code = f.get_attribute("FaceAttributes", "face_code")
                str = "skins face, face_code = #{face_code}, pts = "
                f.vertices.each_with_index{ |v,i| str += "i = #{i}, #{v.position}, " }
                puts str
            end
        }
    end
                
    def apply_layout_transformation(slices, 
                                    slices_group, slice_ordered_z) # updates slices_group

        puts "zone.apply_layout_transformation, apply xform_group to slices and create faces"
        ns = slices.length
        ns.times { |n|
            slice_index_z = n
            if slice_ordered_z == "reversed"
                slice_index_z = ns - n - 1
            end
            lpts = Array.new(slices[slice_index_z])
            lpts.each_with_index { |p,i| lpts[i] = p.transform xform_group }
            lpts.each_with_index { |p,n| 
                puts "slice_index = #{ix0} #{n} - #{p[0]} #{p[1]} #{p[2]} " 
            }
            f = slices_group.entities.add_face([lpts])
            f.set_attribute("SliceAttributes", "slice_index", slice_index_z)
        }
            
        puts count_faces(slices_group.entities,1)
        return 
    end

    def create_risertab(pick_location, face_code)
        edge_location = @slices.edge_location(pick_location, face_code)
        puts edge_location_to_s(edge_location, 1)
        slice_index         = edge_location[0]
        edge_point          = edge_location[1]
        edge_normal         = edge_location[2]
        s_point             = edge_location[3]
        slope               = @slices.slope(slice_index)
        risertab_group      = @base_group.entities.add_group
        risertab_group.name = "risertab"
        risertab            = RiserTab.new("build", risertab_group, 
                                           slope,   edge_point,    edge_normal)
        @@risertabs[risertab.guid] = risertab
        puts "base.create_risertab, risertab = #{risertab}"
        return risertab
    end

    def edge_location_to_s(edge_location, level)
        str =  "######################## EdgeLocation ########################\n"
        str += Trk.tabs(level) + "slice_index = #{edge_location[0]}\n"
        str += Trk.tabs(level) + "edge_point  = #{edge_location[1]}\n"
        str += Trk.tabs(level) + "edge_normal = #{edge_location[2]}\n"
        s= edge_location[3]
        str += Trk.tabs(level) + "s_point     = (#{s.x.to_l}, #{s.y.to_l}, #{s.z.to_l})\n"
        str += Trk.tabs(level) + "ss distance = #{edge_location[4].to_l}\n"
        str += "#############################################################\n"
        return str
    end
end

class CreateBase
    def initialize
        SKETCHUP_CONSOLE.show
        TrackTools.tracktools_init("CreateBase")
        puts "####################################### CreateBase ###########################"
        puts "##############################################################################"

        $zones.create_bases
    end
end
            
            
