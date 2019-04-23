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

class RiserColumn
    def initialize(arg, riserconnector=nil, side=nil, bottom_riserbase=nil, top_riserbase=nil)
        puts "###########################################################################"
        puts "##################################RiserColumn.initialize ##################"
        if arg.is_a? Sketchup::Group
            @risercolumn_group = arg
            @side = @risercolumn_group.get_attribute("RiserColumnAttributes", "side")
            return
        end

        riser_group             = arg.riser_group
        @risercolumn_group      = riser_group.entities.add_group
        @risercolumn_group.name = "risercolumn"
        @primary_riserconnector = riserconnector
        @bottom_riserbase       = bottom_riserbase
        @top_riserbase          = top_riserbase

        @pb, @inside_pts_b, @outside_pts_b = bottom_riserbase.insert_points
        @qt, @inside_pts_t, @outside_pts_t = top_riserbase.insert_points
        insert_point = @bottom_riserbase.insert_point
        mount_point  = @bottom_riserbase.mount_point
        @faces = Hash.new
        top_pts = []
        bot_pts = []
        bz      = @bottom_riserbase.insert_point.z
        @qt.each_with_index do |q,i|
            top_pts[i] = q
            bot_pts[i] = Geom::Point3d.new(q.x, q.y, bz)
        end

        @inside_face_pts = nil
        @outside_face_pts = []
        top_pts.each_with_index do |p,i|
            f = @risercolumn_group.entities.add_face(bot_pts[i-1], top_pts[i-1], 
                                                     top_pts[i  ], bot_pts[i  ])
            pts = outside_face_pts?(f)
            if !pts.nil? 
                pts.each_with_index do |q,i|
                    @outside_face_pts[i] = q
                end
            end
            pts = inside_face_pts?(f)
            @inside_face_pts = pts if !pts.nil?
            @risercolumn_group.entities.add_edges(bot_pts[i  ], top_pts[i  ])
        end
        f = @risercolumn_group.entities.add_face(top_pts)
        @faces[f.persistent_id] = f
        f = @risercolumn_group.entities.add_face(bot_pts)
        @faces[f.persistent_id] = f
        puts "risercolumn.initialize, add top bottom, persistent id = #{f.persistent_id}"
        @risercolumn_group.material = "DarkGoldenrod"
        
        key_group  = bottom_riserbase.key_group
        key_bbx    = key_group.bounds
        key_depth  = key_bbx.depth
        key_width  = key_bbx.width
        key_height = key_bbx.height
        xc = (@outside_pts_t[0].x + @outside_pts_t[1].x ) * 0.5
        yc = @outside_pts_t[0].y
        z0 = insert_point.z
        z1 = key_depth + mount_point.z
        p0 = Geom::Point3d.new(xc - key_width/2.0, yc, z0)
        p1 = Geom::Point3d.new(xc + key_width/2.0, yc, z0)
        p2 = Geom::Point3d.new(xc + key_width/2.0, yc, z1)
        p3 = Geom::Point3d.new(xc - key_width/2.0, yc, z1)
        f     = @risercolumn_group.entities.add_face(p0, p1,p2,p3)
        if !f.nil?
            f.pushpull( -key_height * 0.5)
        else
            puts "risercolumn.initialize, f is nil"
        end
    end

    def point3d_to_s(p)
        return sprintf("%10.6f %10.6f %10.6f", p.x, p.y, p.z)
    end

    def outside_face_pts?(f)
        it = 0
        f.vertices.each do |v|
            if v.position == @outside_pts_t[0]
                it += 1
            elsif v.position == @outside_pts_t[1]
                it += 2
            end
            if it == 3
                pts = []
                f.vertices.each { |v| pts << v.position }
                return pts
            end
        end
        return nil
    end

    def inside_face_pts?(f)
        it = 0
        f.vertices.each do |v|
            if v.position == @inside_pts_t[0]
                it += 1
            elsif v.position == @inside_pts_t[1]
                it += 2
            end
            if it == 3
                pts = []
                f.vertices.each { |v| pts << v.position }
                return pts
            end
        end
        return nil
    end

    def match_pts_to_face(f, pts)
        pts.each do |q|
            found_q = false
            f.vertices.each do |v|
                if v.position == q
                    found_q = true
                    break
                end
            end
            if !found_q
                return false        # Could not find this q
            end
        end
        return true
    end

    def outside_face
        oface = nil
        @risercolumn_group.entities.each do |e|
            if e.is_a? Sketchup::Face
                if match_pts_to_face(e, @outside_face_pts)
                    oface = e
                    break
                end
            end
        end
        return oface
    end

    def cut_riserconnector_notch(secondary_riserconnector)
        z = secondary_riserconnector.attach_height
        slope  = secondary_riserconnector.slope
        vthick = Geom::Vector3d.new(0.0, 0.0, +secondary_riserconnector.thickness)
        q3   = @inside_pts_t[0]
        q2   = @inside_pts_t[1]
        q3p  = Geom::Point3d.new(q3.x, q3.y, z + q3.x * slope)
        q2p  = Geom::Point3d.new(q2.x, q2.y, z + q2.x * slope)
        q3pp = q3p.offset(vthick)
        q2pp = q2p.offset(vthick)

        f = @risercolumn_group.entities.add_face( q3p, q2p, q2pp, q3pp)
        f.pushpull( -0.375)
    end

    def side
        return @side
    end

    def group
        return @risercolumn_group
    end

    def set_risertext(outside_face, side, risertext)
        bb_text = risertext.bounds
        text_width = bb_text.max.x - bb_text.min.x
        p0 = Geom::Point3d.new(0.0, 0.0, 0.0)
        ux = Geom::Vector3d.new(1.0, 0.0, 0.0)
        uy = Geom::Vector3d.new(0.0, 1.0, 0.0)
        uz = Geom::Vector3d.new(0.0, 0.0, 1.0)
        xform_r1 = Geom::Transformation.rotation(p0, ux,  0.5 * Math::PI)
        xform_r2 = Geom::Transformation.rotation(p0, uy, -0.5 * Math::PI)
        if side == "left"
            xform_r3 = Geom::Transformation.rotation(p0, uz, Math::PI)
        else
            xform_r3 = Geom::Transformation.rotation(p0, uy, Math::PI)
        end
        offset_text = 1.5 + 0.5 * text_width
        bb          = outside_face.bounds
        xt = 0.5 * (bb.max.x + bb.min.x)
        yt = bb.min.y
        zt = bb.max.z - 0.375 - 0.5 * text_width
        target_point = Geom::Point3d.new(xt, yt, zt)

        vt = target_point - p0
        xform_t = Geom::Transformation.translation(vt)
        xform = xform_t * xform_r3 *xform_r2 * xform_r1
        risertext.set_transformation(xform)
    end

end
