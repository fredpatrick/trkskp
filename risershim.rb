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

require 'sketchup.rb'
require 'langhandler.rb'

require "#{$trkdir}/base.rb"

include Math
include Trk

class RiserShim
    def initialize(risershim_group, riser_index=nil,
                   base=nil, basedata=nil, bottom_base_offset=nil)
        @risershim_group = risershim_group
        if base.nil?
            @riser_index = @risershim_group.get_attribute("RiserShimAttributes", "riser_index")
            @base_guid   = @risershim_group.get_attribute("RiserShimAttributes", "base_guid")
            @base        = Base.base(@base_guid)
            @base.register_riser(self)
            return
        end
        @riser_index     = riser_index
        @base            = base
        @risershim_group.set_attribute("RiserShimAttributes", "riser_index", @riser_index)
        @risershim_group.set_attribute("RiserShimAttributes", "base_guid", @base.guid)
        @base.register_riser(self)
        p     = basedata["attach_point"]
        slope = basedata["slope"]

        base_width = Base.base_width
        material   = Base.base_material
        shim_width = 2.0

        x0   =   0.5 * shim_width
        x1   = - 0.5 * shim_width
        y0   =   0.5 * base_width
        y1   = - 0.5 * base_width

        t0 = Geom::Point3d.new(x0, y0, p.z + x0 * slope)
        t1 = Geom::Point3d.new(x1, y0, p.z + x1 * slope)
        t2 = Geom::Point3d.new(x1, y1, p.z + x1 * slope)
        t3 = Geom::Point3d.new(x0, y1, p.z + x0 * slope)
        
        zb = bottom_base_offset
        b0 = Geom::Point3d.new(x0, y0, zb)
        b1 = Geom::Point3d.new(x1, y0, zb)
        b2 = Geom::Point3d.new(x1, y1, zb)
        b3 = Geom::Point3d.new(x0, y1, zb)

        f  = risershim_group.entities.add_face(t0, t1, t2, t3)
        f.material = material
        f  = risershim_group.entities.add_face(b0, b1, b2, b3)
        f.material = material
        f  = risershim_group.entities.add_face(t0, t1, b1, b0)
        f.material = material
        f  = risershim_group.entities.add_face(t3, t0, b0, b3)
        f.material = material
        f  = risershim_group.entities.add_face(t2, t3, b3, b2)
        f.material = material
        f  = risershim_group.entities.add_face(t1, t2, b2, b1)
        f.material = material

        @basedata        = basedata
        target_point     = basedata["attach_point"]
        target_crossline = basedata["attach_crossline"]
        zt               = @basedata["attach_point"].z
        source_point     = Geom::Point3d.new(0.0, 0.0, zt)
        source_crossline = Geom::Vector3d.new(0.0, 1.0, 0.0)
        cos              = source_crossline.dot(target_crossline)
        sin              = source_crossline.cross(target_crossline).z
        rotation_angle   = Math.atan2(sin,cos)
        shift            = target_point - source_point
        xform_rotate     = Geom::Transformation.rotation(Geom::Point3d.new(0.0, 0.0, 0.0),
                                                         Geom::Vector3d.new(0.0, 0.0, 1.0), 
                                                         rotation_angle)
        xform_translation = Geom::Transformation.translation(shift)
        riser_xform       = xform_translation * xform_rotate
        risershim_group.transformation = riser_xform
    end

    def erase
        puts "risershim.erase, riser_index = #{@riser_index}"
        @base.unregister_riser(self)
        @risershim_group.erase!
        @risershim_group = nil
    end

    def guid
        return @risershim_group.guid
    end
end

