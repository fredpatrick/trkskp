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
        puts "risercolumn.initialize, outside_pts"
        puts "risercolumn.initialize, top    #{@outside_pts_t[0]} -- #{@outside_pts_t[1]} "
        puts "risercolumn.initialize, bottom #{@outside_pts_b[0]} -- #{@outside_pts_b[1]} "
        puts "risercolumn.initialize, inside_pts"
        puts "risercolumn.initialize, top    #{@inside_pts_t[0]} -- #{@inside_pts_t[1]} "
        puts "risercolumn.initialize, bottom #{@inside_pts_b[0]} -- #{@inside_pts_b[1]} "
        insert_point = @bottom_riserbase.insert_point
        mount_point  = @bottom_riserbase.mount_point
        @faces = Hash.new
        top_pts = []
        bot_pts = []
        bz      = @bottom_riserbase.insert_point.z
        puts "risercolumn.initialize top_pts bot_pts"
        @qt.each_with_index do |q,i|
            top_pts[i] = q
            bot_pts[i] = Geom::Point3d.new(q.x, q.y, bz)
            puts "   #{i} #{point3d_to_s(top_pts[i])} #{point3d_to_s(bot_pts[i])}"
        end
        puts "risercolumn.initialize, outside_pts_t[0] = #{@outside_pts_t[0]}, " +
                        "outside_pts_t[1] = #{@outside_pts_t[1]}"

        @inside_face_pts = nil
        @outside_face_pts = []
        puts "printing object_id for @outside_face_ptsi-0"
        puts @outside_face_pts.object_id
        top_pts.each_with_index do |p,i|
            f = @risercolumn_group.entities.add_face(bot_pts[i-1], top_pts[i-1], 
                                                     top_pts[i  ], bot_pts[i  ])
            pts = outside_face_pts?(f)
            if !pts.nil? 
                puts "risercolumn.initialize, outside_face_pts found #{@outside_face_pts}"
                puts @outside_face_pts
                pts.each_with_index do |q,i|
                    @outside_face_pts[i] = q
                    puts "risercolumn.initialize, #{i} #{q}"
                end
                puts "printing object_id for @outside_face_pts-1"
                puts @outside_face_pts.object_id
            end
            pts = inside_face_pts?(f)
            @inside_face_pts = pts if !pts.nil?
            @risercolumn_group.entities.add_edges(bot_pts[i  ], top_pts[i  ])
        end
        puts "printing object_id for @outside_face_pts-2"
        puts @outside_face_pts.object_id
        puts "#{@outside_face_pts}"
        f = @risercolumn_group.entities.add_face(top_pts)
        @faces[f.persistent_id] = f
        puts "risercolumn.initialize, add top face, persistent id = #{f.persistent_id}"
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
        puts "risercolumn.initialize, key_depth  = #{key_depth}"
        puts "risercolumn.initialize, key_width  = #{key_width}"
        puts "risercolumn.initialize, key_height = #{key_height}"
        puts "risercolumn.initialize, xc         = #{xc}"
        puts "risercolumn.initialize, yc         = #{yc}"
        puts "risercolumn.initialize, z0         = #{z0}"
        puts "risercolumn.initialize, z1         = #{z1}"
        puts "risercolumn.initialize, p0         = #{point3d_to_s(p0)}"
        puts "risercolumn.initialize, p1         = #{point3d_to_s(p1)}"
        puts "risercolumn.initialize, p2         = #{point3d_to_s(p2)}"
        puts "risercolumn.initialize, p3         = #{point3d_to_s(p3)}"
        f     = @risercolumn_group.entities.add_face(p0, p1,p2,p3)
        if !f.nil?
            puts "risercolumn.initilize. normal = #{f.normal}"
            f.vertices.each_with_index do |v,i|
                puts "risercolumn.initialize #{i} #{point3d_to_s(v.position)}"
            end
            f.pushpull( -key_height * 0.5)
        else
            puts "risercolumn.initialize, f is nil"
        end


        puts "risercolumn.initialize, after pushpull @faces.length = #{@faces.length}"
        @faces.each_pair do |k,v|
            puts "    #{k}  --  #{v}" 
        end
        @risercolumn_group.entities.each_with_index do |e,i|
            if e.is_a? Sketchup::Face
                puts "risercolumn.initialize, i = #{i}, id = #{e.persistent_id} "
                level = 1
                str = ""
                attrdicts = e.attribute_dictionaries
                if !attrdicts.nil?
                    attrdicts.each do |ad|
                        str +=  Trk.tabs(level+1) + "#{ad.name}"
                        ad.each_pair do  |k,v| 
                            str +=  Trk.tabs(level+2) + " #{k}    #{v}"
                        end
                    end
                    puts str
                end
            end
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
                f.vertices.each { |v| puts "riser.outside_face? #{v.position}" }
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
        puts "risercolumn.outside_face, outside_face_pts #{@outside_face_pts}"
        puts self
        puts "printing object_id for @outside_face_pts-3"
        puts @outside_face_pts.object_id
        @outside_face_pts.each_with_index { |p,i| puts "  #{i}  --  #{p}" }
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
        puts "risercolumn.inititiaize, before pushpull"
        f.vertices.each_with_index { |q,i| puts "cut_riserconnector_notch, #{i}, " +
                            "q = #{q.position}" }
        f.pushpull( -0.375)
    end

    def side
        return @side
    end
end
