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
require "#{$trkdir}/skins.rb"
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
            @@riserconnector_count = model.get_attribute("BaseAttributes", 
                                                         "riserconnector_count")
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
        end
        layers = model.layers
        layers.add "base"
        @@bases = Hash.new
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
    def Base.risertab_path?(ph)
        ans = search_paths_for_face(ph, "risertab")
        if ans
            risertab_group = ans[0]
            risertab       = @@risertabs[risertab_group.guid]
            #puts "Base.risertab_path?, found risertab, " +
            #                       "risertab_index = #{risertab.risertab_index}"
            return risertab
        end
        return nil
    end

    def Base.base(base_guid)
        return @@bases[base_guid]
    end

    def Base.factory(base_group, parent=nil, switchsection=nil)
        base = Base.new(base_group, parent,switchsection)
        @@bases[base.guid] = base
        return base
    end

    def Base.erase_base(base)
        puts "Base.erase_base"
        @@bases.delete base.guid
        base.erase_base
    end

    def initialize(base_group, parent = nil, switchsection = nil)
        @base_group         = base_group
        @base_group.layer   = "base"
        @risers             = Hash.new
        @spiral             = nil
        if !parent.nil?
            @slices_group       = @base_group.entities.add_group
            @slices_group.name  = "slices"
            @skins_group        = @base_group.entities.add_group
            @skins_group.name   = "skins"
            @slices             = Slices.new(@slices_group)
            @skins              = Skins.new(@skins_group)

            if parent.is_a? Zone
                @zone       = parent
                @base_group.set_attribute("BaseAttributes", "zone_guid", @zone.guid)

                slice_index = 0
                section_guids = []
                last        = false
                @zone.traverse_zone { |s, last|
                   section_guids << [slice_index, s.guid]
                    slice_index = @slices.make_slice_faces(@@base_profile, slice_index, s, last)
                    if last then section_guids << [slice_index - 1, s.guid] end
                    puts "base.initialize, slice_index = #{slice_index}"
                }
                @slices_group.set_attribute("SlicesAttributes", "section_guids", section_guids)
                puts count_faces(@slices_group.entities,1)
                @skins.make_skins_faces(@slices_group, @@base_material)
                puts "Base.initialize, calling test_for_spiral"
                test_for_spiral
            else
                @slices.make_switch_geometry(switchsection.section_group)
                @skins.make_skins_faces(@slices_group, @@base_material)
            end
        end
    end
    def load_existing_base
        puts "base.load_existing_base"
        zone_guid = @base_group.get_attribute("BaseAttributes", "zone_guid")
        @zone     = $zones.zone(zone_guid)
        @base_group.entities.each do |e|
            if e.is_a? Sketchup::Group
                if e.name == "slices"
                    @slices_group = e
                    @slices       = Slices.new(@slices_group)
                    @slices.load_existing_slices
                    @slices.distance
                   # @slices.test_continuous_slope
                elsif e.name == "skins"
                    @skins_group  = e
                    @skins        = Skins.new(@skins_group)
                    @skins.load_existing_skins
                elsif e.name == "spiral"
                    @spiral       = Spiral.new(e, @base_group)
                    puts "base.load_existing_base, found a spiral"
                end
            end
        end
        if !@spiral.nil?
            puts @spiral.to_s
        end
    end

    def erase_base
        puts "base.erase_base"
        @base_group.erase!
        @risers.each_pair do |key,value|    # Note: This only erases those risers
            puts "base.erase_base, key = #{key}"
            riser = value                   #       associated with this base
            riser.erase
        end
        @risers.clear
    end

    def register_riser(riser)
        @risers[riser.guid] = riser
    end

    def unregister_riser(riser)
        @risers.delete riser.guid
    end

    def section_count
        return @slices.section_count
    end
    def guid
        return @base_group.guid
    end
    def slices
        return @slices
    end

    def skins
        return @skins
    end

    def spiral
        return @spiral
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
    
    def analysis
        @zone.traverse_zone { |sg,last|
            section = Section.section(sg.guid)
            section_index_z = section.section_index_z
            entry_tag       = section.entry_tag
            connector       = section.connector(entry_tag)
            p0              = connector.position
            normal          = connector.normal
            puts "base.analysis, section_index_z = #{section_index_z}, p0 = #{p0}, " +
                                     "normal = #{normal}"
            next if section.section_type != "curved"
            radius          = section.radius
            arclen          = section.arclen_degrees
            direction       = section.direction
            puts "base.analysis, radius = #{radius}, arclen = #{arclen}, " +
                                  "direction = #{direction}"
            slope           = section.slope
            inline          = Geom::Vector3d.new(-normal.x, -normal.y, 0.0).normalize
            uz              = Geom::Vector3d.new(0.0, 0.0, 1.0)
            u0              = uz.cross(inline)
            pa              = Geom::Point3d.new(p0.x + radius*u0.x, p0.y + radius*u0.y, 0.0)
            puts "base.analysis, slope           = #{slope}"
            puts "base.analysis, entry_tag       = #{entry_tag}"
            puts "base.analysis, arc origin      = #{pa}"
        }
        puts "base.analysis, calling test_for_spiral"
        test_for_spiral
    end

    def test_for_spiral
        @state = "looking_for_spiral_start"
        @spiral     = nil
        @zone.traverse_zone { |sg,last|
            section = Section.section(sg.guid)
            if @state == "looking_for_spiral_start"
                if section.section_type == "curved"
                    @spiral       = Spiral.new(section, @base_group)
                    @state        = "looking_for_spiral_end"
                end
            elsif @state == "looking_for_spiral_end"
                if !@spiral.update_parms(section)
                    if @spiral.total_arclen > 360.0
                        @spiral.create_spiral
                    end
                    @spiral = nil
                    @state        = "looking_for_spiral_start"
                end
            end
            if last && !@spiral.nil?
                if @spiral.total_arclen > 360.0
                    @spiral.create_spiral
                end
            end
        }
    end

    def section_in_spiral?(section)
        if @spiral.nil?
            puts "base.section_in_spiral?, @spiral is nil"
            return false
        end
        return @spiral.section_in_spiral?(section)
    end

    class Spiral
        def initialize(arg, base_group)
            @tolerance = 0.05
            if arg.is_a? Sketchup::Group
                if arg.name == "spiral"
                    @spiral_group = arg
                    @start_index  = arg.get_attribute("SpiralAttributes", "start_index")
                    @end_index    = arg.get_attribute("SpiralAttributes", "end_index")
                    @radius       = arg.get_attribute("SpiralAttributes", "radius")
                    @origin       = arg.get_attribute("SpiralAttributes", "origin")
                    @total_arclen = arg.get_attribute("SpiralAttributes", "total_arclen")
                end
                return
            elsif arg.is_a? CurvedSection
                section = arg
                @start_index  = section.section_index_z
                @end_index    = @start_index + 1
                @radius       = section.radius
                @origin       = calculate_spiral_origin(section)
                @total_arclen = section.arclen_degrees
                @base_group   = base_group
            end
        end

        def update_parms(section)
            return false if section.section_type != "curved"
            this_origin = calculate_spiral_origin(section)
            delta       = (this_origin - @origin).length.to_f
            if delta > @tolerance
                return false
            end
            @end_index    = section.section_index_z + 1
            @total_arclen = @total_arclen + section.arclen_degrees
            return true
        end

        def create_spiral
            puts "Spiral.create_spiral, Tentative Spiral"
            puts "Spiral.create_spiral, start_index  = #{@start_index}"
            puts "Spiral.create_spiral, end_index    = #{@end_index}"
            puts "Spiral.create_spiral, radius       = #{@radius}"
            puts "Spiral.create_spiral, origin       = #{@origin}"
            puts "Spiral.create_spiral, total_arclen = #{@total_arclen}"
            ret = UI.messagebox("Do you want to create spiral?", MB_YESNO)
            return if ret == IDNO

            @spiral_group      = @base_group.entities.add_group
            @spiral_group.name = "spiral"
            puts "spiral.create_spiral, guid = #{@spiral_group.guid}"
            p1 = Geom::Point3d.new(@origin.x - 1.0, @origin.y, 0.0)
            p2 = Geom::Point3d.new(@origin.x + 1.0, @origin.y, 0.0)
            p3 = Geom::Point3d.new(@origin.x, @origin.y - 1.0, 0.0)
            p4 = Geom::Point3d.new(@origin.x, @origin.y + 1.0, 0.0)
            edgeh = @spiral_group.entities.add_line(p1, p2)
            edgev = @spiral_group.entities.add_line(p3, p4)
            structure_h = Trk.find_structure_top(Geom::Point3d.new(@origin.x, @origin.y, 100.0))
            p1 = Geom::Point3d.new(@origin.x - 1.0, @origin.y, structure_h)
            p2 = Geom::Point3d.new(@origin.x + 1.0, @origin.y, structure_h)
            p3 = Geom::Point3d.new(@origin.x, @origin.y - 1.0, structure_h)
            p4 = Geom::Point3d.new(@origin.x, @origin.y + 1.0, structure_h)
            edgeh = @spiral_group.entities.add_line(p1, p2)
            edgev = @spiral_group.entities.add_line(p3, p4)
            puts "base.spiral.create_spiral"
            @spiral_group.set_attribute("SpiralAttributes", "start_index",  @start_index)
            @spiral_group.set_attribute("SpiralAttributes", "end_index",    @end_index)
            @spiral_group.set_attribute("SpiralAttributes", "radius",       @radius)
            @spiral_group.set_attribute("SpiralAttributes", "origin",       @origin)
            @spiral_group.set_attribute("SpiralAttributes", "total_arclen", @total_arclen)
        end

        def calculate_spiral_origin(section)
            section_index_z = section.section_index_z
            entry_tag       = section.entry_tag
            connector       = section.connector(entry_tag)
            p0              = connector.position
            normal          = connector.normal
            radius          = section.radius
            direction       = section.direction
            inline          = Geom::Vector3d.new(-normal.x, -normal.y, 0.0).normalize
            uz              = Geom::Vector3d.new(0.0, 0.0, 1.0)
            u0              = nil
            if direction == "Left"
                u0 = uz.cross(inline)
            else
                u0 = inline.cross(uz)
            end
            origin          = Geom::Point3d.new(p0.x + radius*u0.x, p0.y + radius*u0.y, 0.0)
            return origin
        end
        
        def start_index 
            return @start_index
        end

        def end_index
            return @end_index
        end

        def radius
            return @radius
        end

        def origin
            return @origin
        end

        def total_arclen
            return @total_arclen
        end
        
        def section_in_spiral?(section)
            if section.section_index_z >= @start_index &&
               section.section_index_z <= @end_index
               return true
            end
            return false
        end

        def to_s
            str = "##################################### Spiral ##########################\n"
            str += " radius       = #{@radius}\n"
            str += " origin       = #{@origin}\n"
            str += " start_index  = #{@start_index}\n"
            str += " end_index    = #{@end_index}\n"
            str += " total_arclen = #{@total_arclen}\n"
            str += "######################################################################\n"
            return str
        end
    end

    def basedata_to_s(basedata, level=1)
        str =  "######################################### Basedata ########################\n"
        basedata.each_pair do |k,v|
            str += sprintf("%30s - %-60s \n", k, "#{v}")
        end
        str += "###########################################################################\n"
        return str
    end

    def print_section_pts(view)
        n = @slices.section_count
        n.times do |i|
            pts = @slices.section_pts(i)
            q0 = view.screen_coords(pts[0])
            q1 = view.screen_coords(pts[1])
            q2 = view.screen_coords(pts[2])
            puts " i =  #{i} - (#{q0.x.to_f}, #{q0.y.to_f})  (#{q1.x.to_f}, #{q1.y.to_f}) " +
                              "(#{q2.x.to_f}, #{q2.y.to_f}) "
        end
    end    
    
    def create_scan(i)
        pts = @slices.section_pts(i)
        sp0 = "(#{pts[0].x}, #{pts[0].y})"
        sp1 = "(#{pts[1].x}, #{pts[1].y})"
        sp2 = "(#{pts[2].x}, #{pts[2].y})"
        str = sprintf("%6s, %-26s %-26s %-26s", @zone.zone_name, sp0, sp1, sp2)
        return str
    end

    def report_slice_data
        @slices.report_slice_data
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
