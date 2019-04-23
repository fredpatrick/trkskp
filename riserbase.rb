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

include Math
include Trk

class RiserBase
    def initialize(arg, riserbase_definition = nil, riserbase_kind = "",
                   attach_point=nil, structure_h=nil, attach_crossline=nil, side=nil)
        if arg.is_a? Sketchup::ComponentInstance
            @instance = arg
            @name     = @instance.name
            definition = @instance.definition
            @mount_point  = definition.get_attribute("RiserBaseAttributes", 
                                                     "mount_point")
            @insert_point = definition.get_attribute("RiserBaseAttributes", 
                                                     "insert_point")
            @side         = @instance.get_attribute("RiserBaseAttributes", "side")
            @kind         = @instance.get_attribute("RiserBaseAttributes", "kind")
            @structure_h  = @instance.get_attribute("RiserBaseAttributes", "structure_h")
            return
        end
        riser                = arg
        riser_group          = riser.riser_group
        
        definition = riserbase_definition
        @mount_point     = definition.get_attribute("RiserBaseAttributes", "mount_point")
        @mount_crossline = definition.get_attribute("RiserBaseAttributes", "mount_crossline")
        @insert_point    = definition.get_attribute("RiserBaseAttributes", "insert_point")
        @side            = side
        @kind            = riserbase_kind
        @structure_h     = structure_h
        @attach_point    = attach_point
        @target_point    = attach_point
        slope            = riser.slope
        @structure_h     = structure_h
        xform_flip       = Geom::Transformation.new
        if @side == "right"
            xform_flip = Geom::Transformation.rotation(@mount_point, 
                                                       Geom::Vector3d.new(0.0, 0.0, 1.0),
                                                       180.degrees)
        end
        target_crossline = attach_crossline
        cos              = @mount_crossline.dot(target_crossline)
        sin              = @mount_crossline.cross(target_crossline).z
        rotation_angle   = Math.atan2(sin,cos)
        xform_rotate     = Geom::Transformation.rotation(@mount_point,
                                                       Geom::Vector3d.new(0.0, 0.0, 1.0),
                                                       rotation_angle)
        if    riserbase_kind == "top"
            slope           = riser.slope
            alpha           =  -atan( slope)
            xform_slope     = Geom::Transformation.rotation(@mount_point,
                                                            @mount_crossline,
                                                            alpha)
            shift           =  @target_point - @mount_point
            xform_shift     = Geom::Transformation.translation(shift)
            xform_top       = xform_shift * xform_rotate * xform_slope * xform_flip
            @instance       = riser_group.entities.add_instance(definition, xform_top)
            @instance.name  = "riserbase"
        elsif riserbase_kind == "bottom"
            top_riserbase      = riser.top_riserbase(@side)
            top_pt             = top_riserbase.insert_point
            m                  = top_riserbase.projected_mount_point
            @target_point         = Geom::Point3d.new(m.x, m.y, @structure_h)
            shift              = @target_point - @mount_point
            xform_shift        = Geom::Transformation.translation(shift)
            xform_bottom       = xform_shift * xform_rotate * xform_flip
            @instance          = riser_group.entities.add_instance(definition, xform_bottom)
            @instance.name     = "riserbase"
        else 
            raise RuntimeError "Unknown riserbase_kind = #{riserbase_kind}"
        end
        @instance.material = "Goldenrod"
        @instance.set_attribute("RiserBaseAttributes", "side", @side)
        @instance.set_attribute("RiserBaseAttributes", "kind", riserbase_kind)
        @instance.set_attribute("RiserBaseAttributes", "structure_h", @structure_h)
    end
#                                                     begin external interface
    def insert_points(apply_xform = true)
        points        = []
        inside_pts    = []
        outside_pts   = []
        definition    = @instance.definition
        Trk.traverse_for_entity(definition, ["Face"]) { |f,path|
            if f.is_a? Sketchup::Face
                attach_to = f.get_attribute("FaceAttributes", "attach_to")
                if attach_to == "insert"
                    f.vertices.each_with_index do |v,i| 
                        points[i] = v.position
                    end
                    outside_edge = nil
                    inside_edge  = nil
                    edges        = f.outer_loop.edges
                    edges.each do |e|
                        r = e.get_attribute("EdgeAttributes","outside_edge")
                        outside_edge = e if !r.nil?
                        r = e.get_attribute("EdgeAttributes","inside_edge")
                        inside_edge = e if !r.nil?
                    end
                    xform = @instance.transformation
                    if !inside_edge.nil?
                        inside_pts[0] = inside_edge.start.position.transform(xform)
                        inside_pts[1] = inside_edge.end.position.transform(xform)
                    end
                    if !outside_edge.nil?
                        outside_pts[0] = outside_edge.start.position.transform(xform)
                        outside_pts[1] = outside_edge.end.position.transform(xform)
                    end
                end
            end
        }
        if apply_xform
            xform = @instance.transformation
            points.each_with_index { |p,i| points[i] = p.transform(xform) }
        end
        return [points, inside_pts, outside_pts]
    end

    def projected_mount_point(apply_xform = true)
        m = nil
        definition    = @instance.definition
        definition.entities.each do |f|
            if f.is_a? Sketchup::Face
                attach_to = f.get_attribute("FaceAttributes", "attach_to")
                if attach_to == "insert"
                    m = @mount_point.project_to_plane(f.plane)
                    break
                end
            end
        end

        return if m.nil?

        return m.transform(@instance.transformation)
    end

    def name
        return @name
    end

    def mount_point(apply_xform = true)
        if apply_xform
            xform = @instance.transformation
            return @mount_point.transform(xform)
        else
            return @mount_point
        end
    end

    def target_point(apply_xform = true)
        if apply_xform
            xform = @instance.transformation
            return @target_point.transform(xform)
        else
            return @target_point
        end
    end

    def insert_point(apply_xform = true)
        if apply_xform
            xform = @instance.transformation
            return @insert_point.transform(xform)
        else
            return @insert_point
        end
    end

    def side
        return @side
    end

    def kind
        return @kind
    end

    def to_s(level=1)
        str = "############ RiserBase #{@instance.name} #{@kind} #{@side} ###################\n"
        str += Trk.tabs(level) + "kind                 = #{@kind}\n"
        str += Trk.tabs(level) + "side                 = #{@side}\n"
        str += Trk.tabs(level) + "mount_point          = #{mount_point}\n"
        str += Trk.tabs(level) + "insert_point         = #{insert_point}\n"
        str += Trk.tabs(level) + "insert_points\n"
        xform = @instance.transformation
        nsert_points, pe = self.insert_points
        nsert_points.each_with_index do |p,i|
            str += Trk.tabs(level+1) + " #{i}   - #{p} \n"
        end
        str += Trk.tabs(level) + "outside_edge        = #{pe[0]}, #{pe[1]}\n"
        str += "#####################################################################\n"
        return str
    end

    def key_group
        if @kind == "bottom"
            @instance.definition.entities.each do |e|
                if e.is_a? Sketchup::Group
                    if e.name == "RB-spline"
                        return e
                    end
                end
            end
        end
        return nil
    end

    def bounds_of_subgroups
        bs = []
        @instance.definition.entities.each do |e|
            if e.is_a? Sketchup::Group
                bbox = e.bounds
                bs << [e.name, bbox]
                puts "bounding box for subgroup name = #{e.name}"
                puts "   min   = #{bbox.min.transform(e.transformation)}, " +
                     "max  = #{bbox.max.transform(e.transformation)}" 
                puts "   depth = #{bbox.depth}, width = #{bbox.width}, height = #{bbox.height}"
            end
        end
    end


    def RiserBase.edit_riserbase(definition)
        text       = []
        point      = []
        paths      = []
        i = 0
        Trk.traverse_for_groups(definition, "tag") do |p|
            path = Array.new
            p.each_with_index { |e,i| path[i] = e }
            n = path.length-1
            e = path[n]                      # e is tag_group
            e.entities.each do |t|
                if t.is_a? Sketchup::Text
                    text[i]       = t.text
                    point[i]      = t.point
                    paths[i]      = path
                    i += 1
                end
            end
        end
        text.each_with_index do |t,i|
            path    = paths[i]
            n       = path.length-1
            xform_t = path[n].transformation
        end
        mount_point      = nil
        mount_crossline  = nil
        mount_normal     = nil
        mount_face       = nil
        insert_point     = nil
        insert_crossline = nil
        insert_normal    = nil
        insert_face      = nil
        text.each_with_index do |t,i|
            path    = paths[i]
            n       = path.length-1
            xform_t = path[n].transformation
            xform_g = xf_groups(path)
            Trk.traverse_for_entity(definition, ["Face"]) { |f|
                tpt = point[i].transform(xform_t)
                if (tpt.on_plane?(f.plane) ) && 
                   (f.classify_point(tpt) == Sketchup::Face::PointInside)
                    tpoint    = point[i].transform(xform_t)
                    normal    = f.normal.transform(xform_t)
                    crossline = Geom::Vector3d.new(0.0, 1.0, 0.0).transform(xform_t)
                    if text[i] == "mount_pt"
                        mount_point     = tpoint.transform(xform_g)
                        mount_crossline = crossline.transform(xform_g)
                        mount_normal    = normal.transform(xform_g)
                        mount_face      = f
                        mount_face.set_attribute("FaceAttributes", "attach_to", "mount")
                    elsif text[i] == "insert_pt"
                        insert_point     = tpoint.transform(xform_g)
                        insert_crossline = crossline.transform(xform_g)
                        insert_normal    = normal.transform(xform_g)
                        insert_face      = f
                        insert_face.set_attribute("FaceAttributes", "attach_to", "insert")
                    end
                end
            }
        end
        text.each_with_index do |t,i|
            path    = paths[i]
            n       = path.length-1
            xform_t = path[n].transformation
            if t == "outside_edge"
                insert_face.edges.each do |e|
                    if (point[i].transform(xform_t)).on_line?(e.line)
                        e.set_attribute("EdgeAttributes", "outside_edge", 1)
                    end
                end
            elsif t == "inside_edge"
                insert_face.edges.each do |e|
                    if (point[i].transform(xform_t)).on_line?(e.line)
                        e.set_attribute("EdgeAttributes", "inside_edge", 1)
                        puts "RiserEdit.edit_riserbase, setting inside edge attribute"
                    end
                end
            end
        end
        puts "insert_face w/o transform"
        insert_face.vertices.each_with_index { |v,i| puts " i = #{i}, p = #{v.position}" }
        puts "mount_face w/o transform"
        mount_face.vertices.each_with_index { |v,i| puts " i = #{i}, p = #{v.position}" }
        thickness = insert_point.distance_to_plane(mount_face.plane)
        insert_face.set_attribute("FaceAttributes", "attach_to", "insert") 
        mount_face.set_attribute( "FaceAttributes", "attach_to", "mount") 

        definition.set_attribute("RiserBaseAttributes", "mount_point",      mount_point)
        definition.set_attribute("RiserBaseAttributes", "mount_crossline",  mount_crossline)
        definition.set_attribute("RiserBaseAttributes", "mount_normal",     mount_normal)
        definition.set_attribute("RiserBaseAttributes", "insert_point",     insert_point)
        definition.set_attribute("RiserBaseAttributes", "insert_crossline", insert_crossline)
        definition.set_attribute("RiserBaseAttributes", "insert_normal",    insert_normal)
        definition.set_attribute("RiserBaseAttributes", "thickness",        thickness)

        p0 = insert_face.vertices[0].position
        p1 = insert_face.vertices[1].position
        p2 = insert_face.vertices[2].position
        p3 = insert_face.vertices[3].position
        q0 = Geom::Point3d.linear_combination(0.5, p0, 0.5, p1)
        q1 = Geom::Point3d.linear_combination(0.5, p3, 0.5, p2)
        rotation_axis   = q0 - q1
        rotation_origin = q1
        definition.set_attribute("RiserBaseAttributes", "rotation_origin", rotation_origin)
        definition.set_attribute("RiserBaseAttributes", "rotation_axis",   rotation_axis)
    end

    def RiserBase.xf_groups(path)
        xf       = Geom::Transformation.new
        path.each_with_index do |e,j|
            if (j != 0) && (j != path.length-1)
                xf = xf * e.transformation
            end
        end
        return xf
    end

end # end of class RiserBase
