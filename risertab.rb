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
require "#{$trkdir}/base.rb"

include Math

class RiserTab
    def RiserTab.init_class_variables
        puts "RiserTab.init_class_variables"
        model    = Sketchup.active_model
        rbattrs  = model.attribute_dictionary("RiserTabAttributes")
        if rbattrs
            @@point_count    = model.get_attribute("RiserTabAttributes", "point_count")
            @@template       = model.get_attribute("RiserTabAttributes", "template")
            @@notch_points   = model.get_attribute("RiserTabAttributes", "notch_points")
            @@center_point   = model.get_attribute("RiserTabAttributes", "center_point")
            @@normal         = model.get_attribute("RiserTabAttributes", "normal")
            @@risertab_count = model.get_attribute("RiserTabAttributes", "risertab_count")
        else
            rbattrs = model.attribute_dictionary("RiserTabAttributes", true)
            @@point_count = model.set_attribute("RiserTabAttributes", "point_count", 9)
            @@template    = model.set_attribute("RiserTabAttributes", "template",
                          [Geom::Point3d.new(-1.00, 0.0, 0.0),
                           Geom::Point3d.new( 1.00, 0.0, 0.0),
                           Geom::Point3d.new( 1.00, 1.5, 0.0),
                           Geom::Point3d.new( 0.50, 2.0, 0.0),
                           Geom::Point3d.new(-0.50, 2.0, 0.0),
                           Geom::Point3d.new(-1.00, 1.5, 0.0)] )
            notch_w = 0.71875
            @@notch_points = model.set_attribute("RiserTabAttributes", "notch_points",
                          [Geom::Point3d.new(-notch_w/2.0, 1.0, 0.0),
                           Geom::Point3d.new( notch_w/2.0, 1.0, 0.0),
                           Geom::Point3d.new( notch_w/2.0, 2.0, 0.0),
                           Geom::Point3d.new(-notch_w/2.0, 2.0, 0.0)])
            @@center_point = Geom::Point3d.new( 0.0, 1.0, -Base.base_thickness)
            @@normal       = Geom::Vector3d.new(0.0, 1.0, 0.0)
            model.set_attribute("RiserTabAttributes", "center_point", @@center_point)
            model.set_attribute("RiserTabAttributes", "normal",       @@normal)
            @@risertab_count = model.set_attribute("RiserTabAttributes", "risertab_count", 0)
        end
        puts "RiserTag.init_class_variables, @@template.length = #{@@template.length}"
        @@risers      = Hash.new
    end

    def initialize()
    end

    def build_new_risertab(slope, edge_location, side)
        model = Sketchup.active_model
        model.set_attribute("RiserTabAttributes", "risertab_count", @@risertab_count)
        @risertab_index = Base.risertab_count
        puts "****************************************************************************" +
             "******* risertab_index = #{risertab_index}, slope = #{slope} ***************"
        Base.increment_risertab_count
        @risertab_group.description = "group risertab risertab_count = #{@risertab_index}"
        
        @slope            = slope
        @slice_index      = edge_location[0]
        @edge_point       = edge_location[1]
        @edge_normal      = edge_location[2]
        @centerline_point = edge_location[3]
        @ss               = edge_location[4]
        @side             = side

        theta = atan2(-edge_normal.x, edge_normal.y)
        xform_rotation    = Geom::Transformation.rotation(Geom::Point3d.new(0.0, 0.0, 0.0),
                                                           Geom::Vector3d.new(0.0, 0.0, 1.0),
                                                           theta)
        xform_translation = Geom::Transformation.translation(edge_point)
        xform_alpha       = Geom::Transformation.rotation(edge_point, edge_normal, atan(slope))
        xform_risertab    = xform_alpha * xform_translation * xform_rotation


        vz = Geom::Vector3d.new(0.0, 0.0, -Base.base_thickness)
        pts = []
        qts = []
        @@template.each_with_index do |p,i|
            pts[i] = p
            qts[i] = p.offset(vz)
        end

        pts.each_with_index { |p,i| pts[i] = p.transform(xform_risertab)}
        qts.each_with_index { |p,i| qts[i] = p.transform(xform_risertab)}
        f0 = @risertab_group.entities.add_face(pts[0], pts[1], pts[2], pts[3], pts[4], pts[5])
        f1 = @risertab_group.entities.add_face(qts[5], qts[4], qts[3], qts[2], qts[1], qts[0])
        puts "build_risertab, f0 normal = #{f0.normal}"
        puts "build_risertab, f1 normal = #{f1.normal}"
        f0.material = Base.base_material
        f1.material = Base.base_material
        pts.each_with_index do |p, i|
            f = @risertab_group.entities.add_face(pts[i-1], qts[i-1], qts[i], pts[i])
            f.material = Base.base_material
        end
        cut_notch(xform_risertab, Base.base_thickness)

        @center_point     = @@center_point.transform(xform_risertab)
        @normal           = @@normal.transform(xform_risertab)
        @thickness        = Base.base_thickness
        puts "risertab.build_new_risertab, @center_point = #{@center_point}, " +
                    "@normal = #{normal}"
        rg = @risertab_group
        rg.set_attribute("RiserTabAttributes", "risertab_index",   @risertab_index)
        rg.set_attribute("RiserTabAttributes", "center_point",     @center_point)
        rg.set_attribute("RiserTabAttributes", "normal",           @normal)
        rg.set_attribute("RiserTabAttributes", "thickness",        @thickness)
        rg.set_attribute("RiserTabAttributes", "slice_index",      @slice_index)
        rg.set_attribute("RiserTabAttributes", "slope",            @slope)
        rg.set_attribute("RiserTabAttributes", "edge_point",       @edge_point)
        rg.set_attribute("RiserTabAttributes", "edge_normal",      @edge_normal)
        rg.set_attribute("RiserTabAttributes", "centerline_point", @centerline_point)
        @risertab_group.set_attribute("RiserTabAttributes", "ss",  @ss)
        rg.set_attribute("RiserTabAttributes", "side",             @side)
        
#       make_pts(xform_risertab)

#       entities = @risertab_group.entities
#       (@@point_count-1).times{ |i|
#           f1 = entities.add_face(pt(i  ,0,0), pt(i+1,0,0), pt(i+1,1,0), pt(i  ,1,0))
#           if i == 0 
#               vt = Geom::Vector3d::new(0.0,0.0,1.0)
#               vn = f1.normal
#               phi = vt.angle_between vn
#               if phi.abs > Math::PI * 0.5
#                   f1.reverse!
#               end
#           end
#           f2 = entities.add_face(pt(i  ,1,0), pt(i+1,1,0), pt(i+1,1,1), pt(i  ,1,1))
#           f3 = entities.add_face(pt(i  ,0,1), pt(i  ,1,1), pt(i+1,1,1), pt(i+1,0,1))
#           f4 = entities.add_face(pt(i  ,0,0), pt(i  ,0,1), pt(i+1,0,1), pt(i+1,0,0))
#           entities.add_edges(pt(i,0,0),pt(i+1,0,0))
#           entities.add_edges(pt(i,1,0),pt(i+1,1,0))
#           entities.add_edges(pt(i,1,1),pt(i+1,1,1))
#           entities.add_edges(pt(i,0,1),pt(i+1,0,1))
#           f1.material = Base.base_material
#           f2.material = Base.base_material
#           f3.material = Base.base_material
#           f4.material = Base.base_material
#           if i == 0 
#               f0 = entities.add_face( pt(i  ,0,0), pt(i  ,1,0), pt(i  ,1,1), pt(i  ,0,1))
#               f0.material = Base.base_material
#               entities.add_edges(     pt(i  ,0,0), pt(i  ,1,0), pt(i  ,1,1), pt(i  ,0,1))
#           elsif i == @@point_count - 2
#               fI = entities.add_face( pt(i+1,0,0), pt(i+1,0,1), pt(i+1,1,1), pt(i+1,1,0))
#               fI.material = Base.base_material
#               entities.add_edges(     pt(i+1,0,0), pt(i+1,0,1), pt(i+1,1,1), pt(i+1,0,0))
#           end 
#       }
        risertab_text_group = make_risertab_text(@risertab_group, @risertab_index, theta)
        risertab_text_group.transformation = xform_risertab
    end            

    def load_risertab
        puts "load_existing_risertab, #{@risertab_group.guid}"
        rg = @risertab_group
        @risertab_index   = rg.get_attribute("RiserTabAttributes", "risertab_index")
        @center_point     = rg.get_attribute("RiserTabAttributes", "center_point")
        @normal           = rg.get_attribute("RiserTabAttributes", "normal")
        @thickness        = rg.get_attribute("RiserTabAttributes", "thickness")
        @slice_index      = rg.get_attribute("RiserTabAttributes", "slice_index")
        @slope            = rg.get_attribute("RiserTabAttributes", "slope")
        @edge_point       = rg.get_attribute("RiserTabAttributes", "edge_point")
        @edge_normal      = rg.get_attribute("RiserTabAttributes", "edge_normal")
        @centerline_point = rg.get_attribute("RiserTabAttributes", "centerline_point")
        @ss               = rg.get_attribute("RiserTabAttributes", "ss")
        @side             = rg.get_attribute("RiserTabAttributes", "side")
    end

    def make_pts(xform_risertab)
        @@pts = []
        ptz = Geom::Point3d.new(0.0, 0.0, -Base.base_thickness)
        nt = @@template.length
        nt.times{ |m|
            $logfile.puts "risertab.make_pts, m = #{m}, @@template[m] = #{@@template[m]}"
            @@pts[m]       = (@@template[m]      ).transform(xform_risertab)
            pt0 = Geom::Point3d.linear_combination(1.0, @@template[m], 1.0, ptz)
            @@pts[m + nt]  = pt0.transform(xform_risertab)
        }
        mt = @@pts.length
        $logfile.puts "risertasb.make_pts, @@pts , mt = #{mt}"
        mt.times{ |m|
            $logfile.puts "risertab.make_pts, m = #{m}, @@pts[m] = #{@@pts[m]}"
        }
    end
    
    def pt(i, j, k)
        m = i + @@point_count * j + @@point_count * 2 * k
        $logfile.puts "risertab.pt, i = #{i}. j = #{j}, k = #{k}, m = #{m}, pt = #{@@pts[m]}"
        return @@pts[m]
    end

    def risertab_index
        return @risertab_index
    end
    def center_point
        return @center_point
    end
    def normal
        return @normal
    end
    def thickness
        return @thickness
    end
    def slice_index
        return @sice_index
    end
    def slope
        return @slope
    end
    def edge_point
        return @edge_point
    end
    def edge_normal
        return @edge_normal
    end
    def centerline_point
        return @centerline_point
    end
    def ss
        return @ss
    end
    def side
        return @side
    end
    def guid
        return @risertab_group.guid
    end
    def to_s(level=1)
        str = "############################ RiserTab ################################\n"
        str += Trk.tabs(level) + "risertab_index       = #{@risertab_index}\n"
        str += Trk.tabs(level) + "center_point         = #{@center_point}\n"
        str += Trk.tabs(level) + "normal               = #{@normal}\n"
        str += Trk.tabs(level) + "thickness            = #{@thickness}\n"
        str += Trk.tabs(level) + "slice_index          = #{@slice_index}\n"
        str += Trk.tabs(level) + "slope                = #{@slope}\n"
        str += Trk.tabs(level) + "edge_point           = #{@edge_point}\n"
        str += Trk.tabs(level) + "edge_normal          = #{@edge_normal}\n"
        str += Trk.tabs(level) + "centerline_point     = #{@centerline_point}\n"
        str += Trk.tabs(level) + "ss                   = #{@ss}\n"
        str += Trk.tabs(level) + "side                 = #{@side}\n"
        str += "#####################################################################\n"
        return str
    end


    def  make_risertab_text(risertab_group, risertab_index, theta)
        risertab_text_group = risertab_group.entities.add_group
        risertab_text_group.name = "risertab_text"
        risertab_text_group.layer = "base"
        puts "risertab_index = #{risertab_index}"

        otxt_h = 0.6
        ofont  = "Courier"
        obold  = false
        ofill  = false
        otxt_w = 0.7865 + otxt_h
        char_group = risertab_text_group.entities.add_group
        char_group.entities.add_3d_text("#{risertab_index}", TextAlignLeft, 
                     ofont, obold, false, otxt_h, 0.6, 0.0, ofill)
        char_group.name = "char_group"
        bx = char_group.bounds
        bkgrnd_w = bx.width + 0.2
        bkgrnd_h = otxt_h * 1.25
        len_s    = 2.0
        puts "make_riserttab.text, bkgrnd_w = #{bkgrnd_w}"
        #if bkgrnd_w > len_s
        #    char_group.entities.clear!
        #    outline_text_group.erase!
        #    outline_text_group = nil
        #    return outline_text_group
        #end
        xmn      = -0.5 * bkgrnd_h 
        xmx      = +0.5 * bkgrnd_h 
        ymn      = 0.5 *len_s - 0.5 * bkgrnd_w
        ymx      = 0.5 *len_s + 0.5 * bkgrnd_w
        trkh     = 0.0
        bkz      = trkh + 0.01
        p0   = Geom::Point3d.new(xmn, ymn, bkz)
        p1   = Geom::Point3d.new(xmn, ymx, bkz)
        p2   = Geom::Point3d.new(xmx, ymx, bkz)
        p3   = Geom::Point3d.new(xmx, ymn, bkz)
        face = risertab_text_group.entities.add_face(p0, p1, p2, p3)
        face.back_material= "white"
        face.material = "white"
        face.edges.each {|e| e.hidden=true}

        orgx  = 0.5 * bx.height
        orgy  = 0.5 * len_s - 0.5 * bx.width
        orgz  = trkh + 0.02
        vt    = Geom::Vector3d.new( orgx, orgy, orgz)
        p0    = Geom::Point3d.new(0.0, 0.0, 0.0)
        uz    = Geom::Vector3d.new(0.0, 0.0, 1.0)
        t1    = Geom::Transformation.rotation(p0, uz, 0.5 * Math::PI)
        if theta.radians >= 0.0 && theta.radians < 180.0
            orgx  = -0.5 *bx.height
            orgy  = 0.5 * len_s +0.5 * bx.width
            vt    = Geom::Vector3d.new(orgx, orgy, orgz)
            t1    = Geom::Transformation.rotation(p0, uz, -0.5 * Math::PI)
        end
        xform = Geom::Transformation.translation( vt) * t1
        char_group.transform! xform
        char_entities = char_group.explode
        ux    = Geom::Vector3d.new(1.0, 0.0, 0.0)
        
        xforms = Geom::Transformation.rotation(p0, ux, atan(slope) )
        risertab_text_group.transform!  xforms
        return risertab_text_group
    end
end # end of class RiserTab

class PrimaryRiserTab < RiserTab
    def initialize(risertab_group)
        @risertab_group = risertab_group
        super()
    end
    def build_new_risertab(slope, edge_location, side)
            @risertab_group.set_attribute("RiserTabAttributes", "primary?", true)
            @risertab_list = RiserTabList.new(@risertab_group)
            @risertab_list.build_new_risertab_list(self)
            super(slope, edge_location, side)
    end
    def load_risertab
            @risertab_list = RiserTabList.new(@risertab_group)
            @risertab_list.load_existing_risertab_list(self)
            super
    end

    def risertab_list
        return @risertab_list
    end

    def cut_notch(xform, thickness)
    end
end # end of class PrimaryRiserTab

class SecondaryRiserTab < RiserTab
    def initialize(risertab_group)
        @risertab_group = risertab_group
        super()
    end
    def build_new_risertab(primary_risertab, slope, edge_location, side)
        @primary_risertab = primary_risertab
        @risertab_group.set_attribute("RiserTabAttributes", "primary?", false)
        @risertab_group.set_attribute("RiserTabAttributes", "primary_risertab_guid",
                                                             primary_risertab.guid)
        @primary_risertab.risertab_list.add_secondary_risertab(self)
        super(slope, edge_location, side)
    end
    def load_risertab
        guid = @risertab_group.get_attribute("RiserTabAttriabutes", "primary_risertab_guid")
        @primary_risertab = Base.risertab(guid)
        super
    end

    def cut_notch(xform, thickness)
        pts = []
        @@notch_points.each_with_index { |p,i| pts[i] = p.transform(xform) }
        fn = @risertab_group.entities.add_face(pts)
        fn.pushpull(-thickness)
    end
end # end of class SecondaryRiserTab

class RiserTabList
    def initialize(risertab_group)
        @risertab_group   = risertab_group
        @secondary_risertabs = []
    end
    def build_new_risertab_list(primary_risertab)
        @primary_risertab = primary_risertab
    end

    def load_existing_risertab_list(primary_risertab)
        puts "load_existing_risertab_list"
        @primary_risertab = primary_risertab
        guids = @risertab_group.get_attribute("RiserTabAttributes", "secondary_guids")
        if guids
            puts "load_existing_risertab_list, guids.length = #{guids.length}"
            if !guids.nil?
                guids.each_with_index do |sg,i|
                    @secondary_risertabs[i] = Base.risertab(sg)
                end
            end
        end
    end

    def add_secondary_risertab(risertab)
        @secondary_risertabs << risertab
        guids = []
        @secondary_risertabs.each_with_index do |sr, i| 
            guids[i] = sr.guid
        end
        @risertab_group.set_attribute("RiserTabAttributes", "secondary_guids", guids)
    end

    def count
        return @secondary_risertabs.length
    end

    def primary_risertab
        return @primary_risertab
    end

    def secondary_risertabs(i)
        return @secondary_risertabs[i]
    end
    def to_s(level =1)
        str = "############################ RiserTabList ################################\n"
        str += Trk.tabs(level)+"primary risertab_index = #{@primary_risertab.risertab_index}\n"
        str += Trk.tabs(level) + "secondary risertabs \n"
        @secondary_risertabs.each_with_index do |s,i|
            str += Trk.tabs(level) + " #{i} - #{@secondary_risertabs[i].risertab_index}\n"
        end
        str = "############################ RiserTabList ################################\n"
        return str
    end
end # end of class RiserTabList
