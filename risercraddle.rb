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
require "#{$trkdir}/trk.rb"
require "#{$trkdir}/riserconnector.rb"
require "#{$trkdir}/texttag.rb"

include Math

class RiserCraddle < RiserConnector
    def initialize(entity, rc_index=nil, riser_group=nil, riser_index=nil, basedata=nil)
        puts "  "
        puts "##################################### Start RiserCraddle ##################"

        if entity.is_a? Sketchup::ComponentDefinition   # this is new risercraddle instance
            @definition         = entity
            @instance           = nil
        elsif 
            @instance           = entity
            if @instance.name != "risercraddle"
                raise RuntimeError "instance name != risercraddle"
            end
            @definition         = @instance.definition
        end
        rca                 = "RiserConnectorAttrs"
        tda                 = "TrkDefinitionAttrs"
        @mount_point        = @definition.get_attribute(rca, "mount_point")
        @mount_crossline    = @definition.get_attribute(rca, "mount_crossline")
        @side_count         = @definition.get_attribute(rca, "side_count")
        @attach_points      = @definition.get_attribute(rca, "attach_points")
        @attach_crosslines  = @definition.get_attribute(rca, "attach_crosslines")
        @attach_normals     = @definition.get_attribute(rca, "attach_normals")
        @secondary          = @definition.get_attribute(rca, "secondary")
        @thickness          = @definition.get_attribute(rca, "thickness")
        @definition_type    = @definition.get_attribute(tda, "definition_type")
        if @definition_type == "risercraddle_p"
            @risertext_points   = @definition.get_attribute(rca, "risertext_points")
            @risertext_normals  = @definition.get_attribute(rca, "risertext_normals")
            @attach_face_pid    = @definition.get_attribute(rca, "attach_face_pid")
            @definition.entities.each do |e|
                if e.is_a? Sketchup::Face
                    if e.persistent == @attach_face_pid
                        @attach_face = e
                        break
                    end
                end
            end
        end
        @definition.material = Sketchup::Color.new(255, 255, 0)
        if @instance.nil?                           # creating new instance of risercraddle
            @basedata        = basedata
            zt               = @basedata["attach_point"].z
            @target_point     = Geom::Point3d.new(0.0, 0.0, zt)
            target_crossline = Geom::Vector3d.new(0.0, 1.0, 0.0)
            @slope           = @basedata["slope"]
            #s                = @basedata["inline_coord"]
            #@slope           = continuous_slope(s)
            cos              = @mount_crossline.dot(target_crossline)
            sin              = @mount_crossline.cross(target_crossline).z
            rotation_angle   = Math.atan2(sin,cos)
            shift            = @target_point - @mount_point
            alpha = -Math.atan(@slope)
            xform_slope    = Geom::Transformation.rotation(@mount_point, 
                                                           @mount_crossline, 
                                                           alpha)
            xform_rotation = Geom::Transformation.rotation(@mount_point, 
                                                           Geom::Vector3d.new(0.0, 0.0, 1.0), 
                                                           rotation_angle)
            xform_translation = Geom::Transformation.translation(shift)
            xform =  xform_translation * xform_rotation * xform_slope
            @instance           = riser_group.entities.add_instance(@definition, xform)
            @instance.name      = "risercraddle"
            @instance.set_attribute("RiserConnectorAttrs", "rc_index", rc_index)
            @instance.material = "PaleGoldenrod"

            if @definition_type == "risercraddle_p"
            end
                
        end

        @rc_index = @instance.get_attribute("RiserConnectorAttrs", "rc_index")
        @guid                   = @instance.guid
        puts "RiserCraddle.initialize, definition name = #{@definition.name}"
        puts "RiserCraddle.initialize, instance name   = #{@instance.name}"
        puts "########################################End RiserCraddle.new ###################"
    end

    def attach_face
        return @attach_face
    end

    def guid
        return @guid
    end

    def set_risertext(riser, side)
        riser_index = riser.riser_index
        parent_group = riser.riser_group
        target_point = risertext_point(side)
        risertext = RiserText.new(parent_group, 0.8, riser_index, side)
        p0   = risertext.center
        xform_r = Geom::Transformation.new
        if side == "right"
            xform_r = Geom::Transformation.rotation(p0, uz, Math::PI)
        end
        vt  = target_point - p0
        xform_t = Geom::Transformation.translation(vt)
        risertext.set_transformation( xform_t * xform_r)
    end

############################################################### Begin RiserCraddle class defs
    def RiserCraddle.edit_risercraddle(definition) 
        definition.delete_attribute("RiserCraddleAttributes")
        definition.delete_attribute("RiserConnectorAttrs")
        tags = Hash.new
        definition.insertion_point = Geom::Point3d.new(-1.0, 0.0, 0.0)
        definition.entities.each do |e| 
            if e.is_a? Sketchup::Group
                if e.name == "tag"
                    texttag = TextTag.new(e, definition)
                    tags[texttag.text] = texttag
                end
            end
        end
        tags.each_pair do |k,v|
            puts "edit_risercraddle, #{k}, #{v}"
        end
        mount_point       = nil
        mount_crossline   = nil
        mount_normal      = nil
        attach_points     = []
        attach_crosslines = []
        attach_normals    = []
        risertext_points  = []
        risertext_normals = []
        attach_face       = nil
       
        ttag = tags["mount_point"]
        raise RuntimeError, "edit_risercraddle, no mount_face tag_group" if ttag.nil?
        definition.set_attribute("RiserConnectorAttrs", "mount_point",       ttag.point)
        definition.set_attribute("RiserConnectorAttrs", "mount_crossline",   ttag.crossline)
        definition.set_attribute("RiserConnectorAttrs", "mount_normal",      ttag.normal)

        ttag = tags["risertext_face_1"]
        raise RuntimeError, "edit_risercraddle, no risertext_face_1 tag_group" if ttag.nil?
        risertext_points[0]  = ttag.face.bounds.center
        risertext_normals[0] = ttag.normal
        ttag = tags["risertext_face_2"]
        raise RuntimeError, "edit_risercraddle, no risertext_face_2 tag_group" if ttag.nil?
        risertext_points[1]  = ttag.face.bounds.center
        risertext_normals[1] = ttag.normal
        definition.set_attribute("RiserConnectorAttrs", "risertext_points",  risertext_points)
        definition.set_attribute("RiserConnectorAttrs", "risertext_normals", risertext_normals)

        ttag = tags["attach_face"]
        raise RuntimeError, "edit_risercraddle, no attach_face tag_group" if ttag.nil?
        attach_face = ttag.face
        2.times do |k|
            attach_points[k]     = risertext_points[k].project_to_plane(attach_face.plane)
            attach_crosslines[k] = ttag.crossline
            attach_normals[k]    = ttag.normal
        end
        definition.set_attribute("RiserConnectorAttrs", "attach_points",     attach_points)
        definition.set_attribute("RiserConnectorAttrs", "attach_crosslines", attach_crosslines)
        definition.set_attribute("RiserConnectorAttrs", "attach_normals",    attach_normals)

        attach_face_pid = attach_face.persistent_id
        definition.set_attribute("RiserConnectorAttrs", "side_count",        2)            
        definition.set_attribute("RiserConnectorAttrs", "attach_face_pid",   attach_face_pid)
        definition.set_attribute("RiserConnectorAttrs", "thickness",         0.21875)
        ret = UI.messagebox("Define RCA attribute secondary as false?", MB_YESNO)
        if ret == IDYES
            definition.set_attribute("RiserConnectorAttrs", "secondary", false)
        else
            definition.set_attribute("RiserConnectorAttrs", "secondary", true )
        end
    end
########################################################## end RiserCraddle class defs
end
