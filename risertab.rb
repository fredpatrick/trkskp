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
            @@center_point   = model.get_attribute("RiserTabAttributes", "center_point")
            @@normal         = model.get_attribute("RiserTabAttributes", "normal")
            @@risertab_count = model.get_attribute("RiserTabAttributes", "risertab_count")
        else
            rbattrs = model.attribute_dictionary("RiserTabAttributes", true)
            @@point_count = model.set_attribute("RiserTabAttributes", "point_count", 9)
            @@template    = model.set_attribute("RiserTabAttributes", "template",
                          [Geom::Point3d.new(-1.00, 0.0, 0.0),
                           Geom::Point3d.new(-0.75, 0.0, 0.0),
                           Geom::Point3d.new(-0.50, 0.0, 0.0),
                           Geom::Point3d.new(-0.25, 0.0, 0.0),
                           Geom::Point3d.new(-0.00, 0.0, 0.0),
                           Geom::Point3d.new( 0.25, 0.0, 0.0),
                           Geom::Point3d.new( 0.50, 0.0, 0.0),
                           Geom::Point3d.new( 0.75, 0.0, 0.0),
                           Geom::Point3d.new( 1.00, 0.0, 0.0),
                           Geom::Point3d.new(-1.00, 1.5000, 0.0),
                           Geom::Point3d.new(-0.75, 1.7071, 0.0),
                           Geom::Point3d.new(-0.50, 2.0000, 0.0),
                           Geom::Point3d.new(-0.25, 2.0000, 0.0),
                           Geom::Point3d.new(-0.00, 2.0000, 0.0),
                           Geom::Point3d.new( 0.25, 2.0000, 0.0),
                           Geom::Point3d.new( 0.50, 2.0000, 0.0),
                           Geom::Point3d.new( 0.75, 1.7071, 0.0),
                           Geom::Point3d.new( 1.00, 1.5000, 0.0)] )
            @@center_point = Geom::Point3d.new( 0.0, 1.0, -Base.base_thickness)
            @@normal       = Geom::Vector3d.new(0.0, 1.0, 0.0)
            model.set_attribute("RiserTabAttributes", "center_point", @@center_point)
            model.set_attribute("RiserTabAttributes", "normal",       @@normal)
            @@risertab_count = model.set_attribute("RiserTabAttributes", "risertab_count", 0)
        end
        puts "RiserTag.init_class_variables, @@template.length = #{@@template.length}"
        @@risers      = Hash.new
    end

    def initialize(mode, risertab_group, slope = nil, edge_point = nil, edge_normal = nil)
        puts "risertab.initialize, mode = #{mode}, slope = #{slope}, " +
                          "edge_point = #{edge_point}, edge_normal = #{edge_normal}"
        @risertab_group = risertab_group
        if mode == "build"
            @risertab_index = Base.risertab_count
            @risertab_group.set_attribute("RiserTabAttributes", 
                                          "risertab_index", @risertab_index)
            Base.increment_risertab_count
            build_new_risertab(slope, edge_point, edge_normal)
        else
            load_existing_risertab
        end
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

    def build_new_risertab(slope, edge_point, edge_normal)
        model = Sketchup.active_model
        model.set_attribute("RiserTabAttributes", "risertab_count", @@risertab_count)
        @risertab_number = @@risertab_count
        @risertab_group.description = "group risertab risertab_count = #{@risertab_number}"
        
        @@risertab_count += 1
        @slope            = slope
        puts "risertab.build_new_risertab, slope = #{slope}, edge_point = #{edge_point}, " +
                 "edge_normal = #{edge_normal}"

        #theta = Geom::Vector3d.new(0.0, 1.0, 0.0).angle_between(edge_normal)
        theta = atan2(-edge_normal.x, edge_normal.y)
        puts "build_new_risertab, theta #{theta.radians}"
        puts "build_new_risertab, theta #{theta.degrees}"
        puts "build_new_risertab, theta #{theta}"
        xform_rotation    = Geom::Transformation.rotation(Geom::Point3d.new(0.0, 0.0, 0.0),
                                                           Geom::Vector3d.new(0.0, 0.0, 1.0),
                                                           theta)
        xform_translation = Geom::Transformation.translation(edge_point)
        xform_alpha       = Geom::Transformation.rotation(edge_point, edge_normal, atan(slope))
        xform_risertab    = xform_alpha * xform_translation * xform_rotation

        @center_point     = @@center_point.transform(xform_risertab)
        @normal           = @@normal.transform(xform_risertab)
        puts "risertab.build_new_risertab, @center_point = #{@center_point}, " +
                    "@normal = #{normal}"
        @risertab_group.set_attribute("RiserTabAttributes", "center_point", @center_point)
        @risertab_group.set_attribute("RiserTabAttributes", "normal",       @normal)
        @risertab_group.set_attribute("RiserTabAttributes", "slope",        @slope)

        make_pts(xform_risertab)

        entities = @risertab_group.entities
        (@@point_count-1).times{ |i|
            f1 = entities.add_face(pt(i  ,0,0), pt(i+1,0,0), pt(i+1,1,0), pt(i  ,1,0))
            if i == 0 
                vt = Geom::Vector3d::new(0.0,0.0,1.0)
                vn = f1.normal
                phi = vt.angle_between vn
                if phi.abs > Math::PI * 0.5
                    f1.reverse!
                end
            end
            f2 = entities.add_face(pt(i  ,1,0), pt(i+1,1,0), pt(i+1,1,1), pt(i  ,1,1))
            f3 = entities.add_face(pt(i  ,0,1), pt(i  ,1,1), pt(i+1,1,1), pt(i+1,0,1))
            f4 = entities.add_face(pt(i  ,0,0), pt(i  ,0,1), pt(i+1,0,1), pt(i+1,0,0))
            entities.add_edges(pt(i,0,0),pt(i+1,0,0))
            entities.add_edges(pt(i,1,0),pt(i+1,1,0))
            entities.add_edges(pt(i,1,1),pt(i+1,1,1))
            entities.add_edges(pt(i,0,1),pt(i+1,0,1))
            f1.material = Base.base_material
            f2.material = Base.base_material
            f3.material = Base.base_material
            f4.material = Base.base_material
            if i == 0 
                f0 = entities.add_face( pt(i  ,0,0), pt(i  ,1,0), pt(i  ,1,1), pt(i  ,0,1))
                f0.material = Base.base_material
                entities.add_edges(     pt(i  ,0,0), pt(i  ,1,0), pt(i  ,1,1), pt(i  ,0,1))
            elsif i == @@point_count - 2
                fI = entities.add_face( pt(i+1,0,0), pt(i+1,0,1), pt(i+1,1,1), pt(i+1,1,0))
                fI.material = Base.base_material
                entities.add_edges(     pt(i+1,0,0), pt(i+1,0,1), pt(i+1,1,1), pt(i+1,0,0))
            end 
        }
        risertab_text_group = make_risertab_text(@risertab_group, @risertab_index, theta)
        risertab_text_group.transformation = xform_risertab
    end            

    def load_existing_risertab
        @risertab_index = @risertab_group.get_attribute("RiserTabAttributes", "risertab_index")
        @center_point   = @risertab_group.get_attribute("RiserTabAttributes", "center_point")
        @normal         = @risertab_group.get_attribute("RiserTabAttributes", "normal")
        @slope          = @risertab_group.get_attribute("RiserTabAttributes", "slope")
    end

    def center_point
        return @center_point
    end
    def normal
        return @normal
    end
    def slope
        return @slope
    end
    def risertab_index
        return @risertab_index
    end
    def guid
        return @risertab_group.guid
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
end
