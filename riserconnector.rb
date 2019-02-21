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

class RiserConnector

    def initializer
            @secondary_riserconnector = nil
            @defintion_type           = nil
    end

    def instance
        return @instance
    end

    def rc_index
        return @rc_index
    end

    def definition_type
        return @definition_type
    end

    def definition_name
        return @instance.definition.name
    end

    def basedata
        return @basedata
    end

    def closest_attach_point(p)
        p2 = Geom::Point2d.new(p.x, p.y)
        dc   = 9999.0
        apndx = 999
        @attach_points.length.times do |i|
            q  = attach_point(i)
            q2 = Geom::Point2d.new(q.x, q.y)
            d  = q2.distance(p2)
            if d < dc
                dc    = d
                apndx = i
            end
        end
        return apndx
    end

    def mount_point
        return @mount_point.transform(@instance.transformation)
    end

    def target_point
        return @target_point
    end

    def mount_crossline
        return @mount_crossline.transform(@instance.transformation)
    end
 
    def side_count
        return @side_count
    end

    def attach_count
        return @attach_points.length
    end

    def attach_point(i)
        return @attach_points[i].transform(@instance.transformation)
    end

    def attach_crossline(i)
        return @attach_crosslines[i].transform(@instance.transformation)
    end

    def attach_normal(i)
        return @attach_normals[i].transform(@instance.transformation)
    end

    def attach_side(i)
        if i == 0
            return "left"
        elsif i == 1
            return "right"
        end
    end

    def attach_height
        pt = @mount_point.project_to_plane(@attach_face.plane)
        return pt.transform(@instance.transformation).z
    end

    def slope
        return @slope
    end

    def riserconnector_list
        return @riserconnector_list
    end

    def secondary_riserconnector
        return @secondary_riserconnector
    end
    
    def thickness
        return 0.21875
    end

    def guid
        return @guid
    end

    def primary
        if @secondary
            return false
        else
            return true
        end
    end

    def to_s
        rotation_angle = @instance.get_attribute("RiserConnectorAttrs", "rotation_angle")
        shift          = @instance.get_attribute("RiserConnectorAttrs", "shift")
        str = "################################RiserConnector #########################\n"
        str += "definition_type      = #{@definition_type}\n"
        str += "definition_name      = #{definition_name}\n"
        str += "mount_point          = #{mount_point}\n"
        str += "mount_crossline      = #{mount_crossline}\n"
        str += "attach_count         = #{attach_count}\n"
        attach_count.times do |n|
            str += "attach_point[#{n}]      = #{attach_point(n)}\n"
            str += "attach_crosslines[#{n}] = #{attach_crossline(n)}\n"
        end
        str += "slope                = #{@slope}\n"
        str += "rotation_angle       = #{rotation_angle.radians}\n"
        str += "shift                = #{shift}\n"
        str += "primary              = #{primary}\n"
        str += "########################################################################\n"
        return str
    end
end

class RiserConnectorFactory
    def initialize(base, basedata, primary_riserconnector)
        secondary = false
        if primary_riserconnector 
            secondary = true
        end
        definitions_by_type = Hash.new
        puts "RiserConnectoryFactory.initialize definitions length = " +
                                    "#{Sketchup.active_model.definitions.length}"
        Sketchup.active_model.definitions.each do |d|
            if !d.group?
                puts Trk.definition_to_s(d, 2)
                type = d.get_attribute("TrkDefinitionAttrs", "definition_type")
                tmdt = d.get_attribute("TrkDefinitionAttrs", "timedate")
                puts "RiserConnecotrFactory.initialize, type = #{type}, name = #{d.name}, " +
                                                        "timedate = #{tmdt}"
                puts "                                , definition guid = #{d.guid}"
                if definitions_by_type.key? type
                    definitions_by_type[type] << d
                else
                    definitions_by_type[type] =  [d]
                end
            end
        end
        definitions_by_type.each_pair do |k,v|
            v.each { |d| puts "type = #{k} - definition name = #{d.name}" }
        end
        type        = select_type(definitions_by_type.keys)
        definitions = definitions_by_type[type]
        definition  = select_definition(definitions, secondary) 
        if type == "risercraddle"
            base.new_risercraddle(definition, basedata, primary_riserconnector)
        elsif type == "risertab"
            base.new_risertab(definition, basedata, primary_riserconnector)
        else
        end
    end

    def select_type(keys)
        puts "select_type, keys = #{keys}"
        opts     = nil
        keys.each do |k|
            if opts == nil
                opts = k
            else
                opts += ("|" + k)
            end
        end
        results = UI.inputbox ["Type"], [" "], [opts], "Select Type"
        if results
            return results[0]
        else 
            return nil
        end
    end

    def select_definition(definitions, secondary)
        puts "select_definition-0, secondary = #{secondary}"
        filtered_definitions_h = Hash.new
        opts                   = nil
        definitions.each do |d|
            s = d.get_attribute("RiserConnectorAttrs", "secondary")
            puts "select_definitions, d.name = #{d.name}, s = #{s}"
            if s == secondary
                name = d.name
                if opts.nil? 
                    opts =  name
                    filtered_definitions_h[name] = d
                else
                    opts += "|" + name
                    filtered_definitions_h[name] = d
                end
            end
        end
        title = "Select Definition"
        results = UI.inputbox ["Def Name"], [" "], [opts], title
        if results
            defname = results[0]
            return filtered_definitions_h[defname]
        else
            return nil
        end
    end
end 


class RiserConnectorList
    def initialize(primary_riserconnector)
        @primary_riserconnector   = primary_riserconnector
        @secondary_guids = []
        instance = @primary_riserconnector.instance
        ad = instance.attribute_dictionary("RiserconnectorList", false)
        if ad
            @secondary_guids = instance.get_attribute("RiserConnectorList", "secondary_guids")
        else
            instance.set_attribute("RiserConnectorList", "secondary_guids", @secondary_guids)
        end 
    end

    def add_secondary(riserconnector)
        @secondary_guids << riserconnector.guid
        @primary_instance.set_attribute("RiserConnectorList", 
                                        "secondary_guids", 
                                        @secondary_guids)
    end

    def count
        return @secondary_guids.length
    end

    def primary_riserconnector
        return @primary_riserconnector
    end

    def secondary_riserconnectors(i)
        rclist = []
        @secondary_guids.each do |guid|
            rclist << Base.riserconnector(guid)
        end
        return rclist[i]
    end
    def to_s(level =1)
        str = "############################ RiserConnectorList #############################\n"
        str = "############################ RiserConnectorList ##############################\n"
        return str
    end
end # end of class RiserConnectorList
