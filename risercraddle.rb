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
        @attach_face_pid    = @definition.get_attribute(rca, "attach_face_pid")
        @definition.entities.each do |e|
            if e.is_a? Sketchup::Face
                if e.persistent_id == @attach_face_pid
                    @attach_face = e
                    puts "risercraddle.initialize, found attach_face"
                    break
                end
            end
        end
        @definition_type    = @definition.get_attribute(tda, "definition_type")
        if @definition_type == "risercraddle_p"
            @attach_rt_points   = @definition.get_attribute(rca, "attach_rt_points")
            @attach_rt_normals  = @definition.get_attribute(rca, "attach_rt_normals")
            @attach_rt_xlines   = @definition.get_attribute(rca, "attach_rt_xlines")
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
            puts "risercraddle.initialize, rotation_angle = #{rotation_angle}"
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
    end

    def attach_face
        return @attach_face
    end

    def guid
        return @guid
    end

    def attach_rt_point(side)
        i = 1
        if side == "left"
            i = 0
        end
        return @attach_rt_points[i].transform(@instance.transformation)
    end

    def attach_rt_xline(side)
        i = 1
        if side == "left"
            i = 0
        end
        return @attach_rt_xlines[i].transform(@instance.transformation)
    end

    def set_risertext(riser, side)
        riser_index      = riser.riser_index
        parent_group     = riser.riser_group
        target_point     = attach_rt_point(side)
        target_xline     = attach_rt_xline(side)
        puts "risercraddle.set_risertext target_point    = #{target_point}"
        puts "risercraddle.set_risertext target_xline    = #{target_xline}"
        risertext        = RiserText.new(parent_group, 0.6, riser_index, side)
        rt_point  = risertext.point
        rt_xline  = risertext.crossline
        rt_normal = risertext.normal
        puts "risercraddle.set_risertext source_point    = #{rt_point}"
        puts "risercraddle.set_risertext source_xline    = #{rt_xline}"
        puts "risercraddle.set_risertext source_normal   = #{rt_normal}"
        puts "risercraddle.set_risertext slope           = #{@slope}"
        rt_slope = @slope
        if side == "left" 
            rt_slope = -@slope
        end
        xform_rt = Trk.build_transformation(rt_point,     rt_xline,     rt_normal,
                                            target_point, target_xline, rt_slope)
       #p0   = risertext.center
       #uz   = Geom::Vector3d.new(0.0, 0.0, 1.0)
       #xform_r = Geom::Transformation.new
       #if side == "right"
       #    xform_r = Geom::Transformation.rotation(source_point, source_normal, Math::PI)
       #end
                                      
        risertext.set_transformation( xform_rt )
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
        ret = UI.messagebox("Define RCA attribute secondary as false?", MB_YESNO)
        secondary = true
        if ret == IDYES
            secondary = false
        end
        definition.set_attribute("RiserConnectorAttrs", "secondary", secondary)
        mount_point       = nil
        mount_crossline   = nil
        mount_normal      = nil
        attach_points     = []
        attach_crosslines = []
        attach_normals    = []
        attach_rt_points  = []
        attach_rt_normals = []
        attach_rt_xlines  = []
        attach_face       = nil
       
        ttag = tags["mount_point"]
        raise RuntimeError, "edit_risercraddle, no mount_face tag_group" if ttag.nil?
        definition.set_attribute("RiserConnectorAttrs", "mount_point",       ttag.point)
        definition.set_attribute("RiserConnectorAttrs", "mount_crossline",   ttag.crossline)
        definition.set_attribute("RiserConnectorAttrs", "mount_normal",      ttag.normal)
        mount_point          = tags["mount_point"].point

        ttag = tags["attach_face"]
        raise RuntimeError, "edit_risercraddle, no attach_face tag_group" if ttag.nil?
        attach_face = ttag.face
        attach_face_pid = attach_face.persistent_id
        definition.set_attribute("RiserConnectorAttrs", "attach_face_pid",   attach_face_pid)
        definition.set_attribute("RiserConnectorAttrs", "side_count",        2)            
        definition.set_attribute("RiserConnectorAttrs", "thickness",         0.21875)
        return if secondary

        ttag = tags["risertext_face_1"]
        raise RuntimeError, "edit_risercraddle, no risertext_face_1 tag_group" if ttag.nil?
        attach_rt_points[0]  = ttag.face.bounds.center
        attach_rt_normals[0] = ttag.normal
        v                    = mount_point - attach_rt_points[0]
        v.z                  = 0.0
        attach_rt_xlines[0]  = v.normalize!
        ttag = tags["risertext_face_2"]
        raise RuntimeError, "edit_risercraddle, no attach_rt_face_2 tag_group" if ttag.nil?
        attach_rt_points[1]  = ttag.face.bounds.center
        attach_rt_normals[1] = ttag.normal
        v                    = mount_point - attach_rt_points[1]
        v.z                  = 0.0
        attach_rt_xlines[1]  = v.normalize!
        definition.set_attribute("RiserConnectorAttrs", "attach_rt_points",  attach_rt_points)
        definition.set_attribute("RiserConnectorAttrs", "attach_rt_normals", attach_rt_normals)
        definition.set_attribute("RiserConnectorAttrs", "attach_rt_xlines", attach_rt_xlines)

        2.times do |k|
            attach_points[k]     = attach_rt_points[k].project_to_plane(attach_face.plane)
            attach_crosslines[k] = ttag.crossline
            attach_normals[k]    = ttag.normal
        end
        definition.set_attribute("RiserConnectorAttrs", "attach_points",     attach_points)
        definition.set_attribute("RiserConnectorAttrs", "attach_crosslines", attach_crosslines)
        definition.set_attribute("RiserConnectorAttrs", "attach_normals",    attach_normals)
    end
########################################################## end RiserCraddle class defs
end
