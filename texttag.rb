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
 
require 'sketchup.rb'
require 'langhandler.rb'

include Math
include Trk

class TextTag
    def initialize(tag_group, definition)
        raise RuntimeError, "Not legit1mate tag_group" if tag_group.name != "tag" 

        @tag_group = tag_group
        @xform     = tag_group.transformation
        @tag_group.entities.each do |e|
            if e.is_a? Sketchup::Text
                @text = e.text
                @point = e.point.transform(@xform)
                break
            end
        end
        @face = find_face(definition)
        raise RuntimeError, "Couldn't match face" if @face.nil?
    end

    def xform 
        return @xform
    end

    def text 
        return @text
    end

    def point
        return @point
    end

    def crossline
        return Geom::Vector3d.new(-1.0, 0.0, 0.0).transform(@xform)
    end

    def face
        return @face
    end

    def normal
        return face.normal
    end
  
    def find_face(definition)
        f = nil
        definition.entities.each_with_index do |e,k|
            if e.is_a? Sketchup::Face
                if @point.on_plane?(e.plane)
                    f = e if e.classify_point(@point) == Sketchup::Face::PointInside
                end
            end
        end
        return f
    end

    def to_s
        str = "TextTag instance, persistent_id = #{@tag_group.persistent_id} \n"
        str += "    text      = #{@text} \n"
        str += "    point     = #{@point} \n"
        str += "    face pid  = #{@face.persistent_id} \n"
        str += "    normal    = #{normal} \n"
        str += "    crossline = #{crossline} \n"
        str += "    center    = #{@face.bounds.center} \n"
        return str
    end
        
end
