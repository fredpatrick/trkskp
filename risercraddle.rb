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
                rotation_angle = 0.0
                thickness      = 0.21875
        @mount_point        = @definition.get_attribute(rca, "mount_point")
        @mount_crossline    = @definition.get_attribute(rca, "mount_crossline")
        @side_count         = @definition.get_attribute(rca, "side_count")
        @attach_points      = @definition.get_attribute(rca, "attach_points")
        @attach_crosslines  = @definition.get_attribute(rca, "attach_crosslines")
        @attach_normals     = @definition.get_attribute(rca, "attach_normals")
        @secondary          = @definition.get_attribute(rca, "secondary")
        @thickness          = @definition.get_attribute(rca, "thickness")
        @definition_type    = @definition.get_attribute(tda, "definition_type")
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
            #@instance.material = Sketchup::Color.new(255,255,0)
        end
        @cut_faces = []
        @attach_face = nil
        @definition.entities.each do |e|
            if e.is_a? Sketchup::Face
                i             = e.get_attribute("FaceAttributes", "cut_face")
                @cut_faces[i] = e if !i.nil?
                r             = e.get_attribute("FaceAttributes", "attach_face")
                @attach_face  = e if !r.nil?
            end
        end

        @rc_index = @instance.get_attribute("RiserConnectorAttrs", "rc_index")
        @guid                   = @instance.guid
        puts "RiserCraddle.initialize, definition name = #{@definition.name}"
        puts "RiserCraddle.initialize, instance name   = #{@instance.name}"
        puts "########################################End RiserCraddle.new ###################"
    end

    def cut_faces
        return @cut_faces
    end

    def attach_face
        return @attach_face
    end

    def guid
        return @guid
    end
############################################################### Begin RiserCraddle class defs
    def RiserCraddle.edit_risercraddle(definition) 
        definition.delete_attribute("RiserCraddleAttributes")
        definition.delete_attribute("RiserConnectorAttrs")
        text       = []
        tpoint     = []
        xform      = []
        tag_groups = []
        i = 0
        definition.insertion_point = Geom::Point3d.new(-1.0, 0.0, 0.0)
        definition.entities.each do |e| 
            if e.is_a? Sketchup::Group
                if e.name == "tag"
                    e.entities.each do |t|
                        if t.is_a? Sketchup::Text
                            text[i]       = t.text
                            tpoint[i]     = t.point
                            xform[i]      = e.transformation
                            tag_groups[i] = e
                            i += 1
                        end
                    end
                end
            end
        end
        text.each_with_index do |t,i|
            puts "edit_risercraddle, i = #{i}, #{text[i]}, #{tpoint[i].transform(xform[i])}"
        end
        mount_point       = nil
        mount_crossline   = nil
        mount_normal      = nil
        attach_points     = []
        attach_crosslines = []
        attach_normals    = []
        cut_faces         = []
        attach_face       = nil
        text.each_with_index do |t,i|
            m = 0
            definition.entities.each_with_index  do |f,k|
                if f.is_a? Sketchup::Face
                    m += 1
                    if (tpoint[i].transform(xform[i])).on_plane?(f.plane)
                        point     = tpoint[i].transform(xform[i])
                        normal    = f.normal.transform(xform[i])
                        crossline = Geom::Vector3d.new(-1.0, 0.0, 0.0).transform(xform[i])
                        if text[i] == "mount_point"
                            mount_point       = point
                            mount_crossline   = crossline
                            mount_normal      = normal
                        elsif text[i] == "riser_mount_1"
                            attach_points[0]     = point
                            attach_crosslines[0] = crossline
                            attach_normals[0]    = normal
                        elsif text[i] == "riser_mount_2"
                            attach_points[1]     = point
                            attach_crosslines[1] = crossline
                            attach_normals[1]    = normal
                        elsif text[i] == "cut_face_1"
                            cut_faces[0]         = f
                        elsif text[i] == "cut_face_2"
                            cut_faces[1]         = f
                        elsif text[i] == "attach_face"
                            attach_face          = f
                        end
                    end
                end
            end
        end
        definition.set_attribute("RiserConnectorAttrs", "mount_point",       mount_point)
        definition.set_attribute("RiserConnectorAttrs", "mount_crossline",   mount_crossline)
        definition.set_attribute("RiserConnectorAttrs", "mount_normal",      mount_normal)
        definition.set_attribute("RiserConnectorAttrs", "side_count",        2)            
        if attach_points.length > 0
            definition.set_attribute("RiserConnectorAttrs", "attach_points",     attach_points)
            definition.set_attribute("RiserConnectorAttrs", "attach_crosslines", attach_crosslines)
            definition.set_attribute("RiserConnectorAttrs", "attach_normals",    attach_normals)
        end
        if cut_faces.length > 0
            cut_faces.each_with_index { |f,i| f.set_attribute("FaceAttributes", "cut_face", i)}
        end
        if !attach_face.nil? 
            attach_face.set_attribute("FaceAttributes", "attach_face", 1)
        end
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
