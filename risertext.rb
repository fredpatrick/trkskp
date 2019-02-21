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

class RiserText
    def initialize(riser)
        riser_group            = riser.riser_group
        @riser_index           = riser.riser_index

        @risertext_group       = riser_group.entities.add_group
        @risertext_group.name  = "risertext"
        @risertext_group.layer = "base"

        otxt_h = 0.6
        z      = 0.03125
        ofont  = "Courier"
        obold  = false
        ofill  = false
        txt    = sprintf("%03d", @riser_index)
        char_group = risertext_group.entities.add_group
        char_group.entities.add_3d_text(txt, TextAlignLeft, 
                     ofont, obold, false, otxt_h, 0.6, z, ofill)
        char_group.name = "char_group"
        bb_text = char_group.bounds
        xmn      = bb_text.min.x - 0.03125
        xmx      = bb_text.max.x + 0.03125
        ymn      = bb_text.min.y - 0.03125
        ymx      = bb_text.max.y + 0.03125
        bkz      = 0.015625
        p0   = Geom::Point3d.new(xmn, ymn, bkz)
        p1   = Geom::Point3d.new(xmn, ymx, bkz)
        p2   = Geom::Point3d.new(xmx, ymx, bkz)
        p3   = Geom::Point3d.new(xmx, ymn, bkz)
        face = char_group.entities.add_face(p0, p1, p2, p3)
        face.back_material= "white"
        face.material = "white"
        face.edges.each {|e| e.hidden=true}
        bb= char_group.bounds
        
        target_point = Geom::Point3d.new(0.0, 0.0, 0.0)
        vt    = target_point - Geom::Point3d.new(bb.center.x, bb.center.y, 0.0)
        xform = Geom::Transformation.translation( vt)
        char_group.transform! xform
        char_entities = char_group.explode
        risertext_bb = @risertext_group.bounds
    end

    def risertext_group
        return @risertext_group
    end
end
