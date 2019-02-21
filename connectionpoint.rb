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

include Math

class ConnectionPoint
    def intialize 
        @postion = nil
        @theta   = nil
    end
    def theta
        return @theta
    end
    def position
        return @position
    end

    def tag
        return @tag
    end
end

class StartPoint < ConnectionPoint

    def initialize(position, normal)
        @position = position
        @normal   = normal
        x = @normal.x
        y = @normal.y
        @theta = atan2(y, x)
        @tag   = "S"
    end

    def theta
        return @theta
    end

    def position
        return @position
    end

    def normal
        return @normal
    end

    def check_slope(slope)
        return true
    end
end

class Connector < ConnectionPoint              #NOTE: Attributes position, normal, theta
    def Connector.init_class_variables         #      have had Section.transformation
        @@track_connectors = Hash.new          #      applied
        @@delta_max = 0.03125
        @@dot_min   = cos(atan(0.035))
        theta_max = acos(@@dot_min)
        @@slope_max = tan(theta_max)
        puts "@@delta_max = #{@@delta_max}"
        puts "@@dot_min   = #{@@dot_min}"
        puts "@@slope_max = #{@@slope_max}"
    end

    def Connector.load_connectors(section_group)
        cpts = []
        i    = 0
        section_group.entities.each do |e|
            if e.is_a? Sketchup::Group
                if e.name == "connector"
                    cpts[i] = Connector.factory(e, section_group)
                    i = i+1
                end
            end
        end
        return cpts
    end

    def Connector.factory(arg0,
                          arg1 = "notag", 
                          face = nil)
        cpt = nil
        if arg0.is_a? Sketchup::Group
            if arg0.name == "section"
                cpt = Connector.new(arg0, arg1, face)
            elsif arg0.name == "connector"
                cpt = Connector.new(arg0, arg1)
            end
            guid = cpt.guid
            @@track_connectors[guid] = cpt
        end
        return cpt
    end

    def Connector.connector(guid)
        return @@track_connectors[guid]
    end

    def Connector.connectors
        return @@track_connectors.values
    end
    ################################################ initialize Connector
    def initialize( arg0,
                    arg1, 
                    face = nil)

        if Section.section_group? arg0
            @section_group    =arg0
            @section     = Section.section(@section_group.guid)
            @tag      = arg1
            @position, @normal, @theta = face_position(face)
            @linked_guid = "UNCONNECTED"
            @label       = "S#{@section.section_index_g}_#{@tag}"
            @connector_group = @section_group.entities.add_group
            @connector_group.name = "connector"
            @connector_group.layer = "track_sections"
            cname = "ConnectorAttributes"
            @connector_group.attribute_dictionary(cname, true)
            @connector_group.set_attribute(cname, "tag",             @tag)
            @connector_group.set_attribute(cname, "linked_guid",     @linked_guid)
            @connector_group.set_attribute(cname, "label",           @label)
            @connector_group.set_attribute(cname, "section_index_g", @section.section_index_g)
            @connector_group.set_attribute(cname, "position",        @position)
            @connector_group.set_attribute(cname, "normal",          @normal)
            @connector_group.set_attribute(cname, "theta",           @theta)
            ##################### Note section_index_g is used only for info in model dumps
            pts = []
            i   = 0
            face.vertices.each do |v|
                pts[i] = v.position
                i = i + 1
            end
            @face = @connector_group.entities.add_face(pts)

        elsif (arg0.is_a? Sketchup::Group) && arg0.name == "connector"
#           arg0.entities.each do |c|
#               if c.is_a? Sketchup::Face
#                   @face = c
#                   @position, @normal, @theta = face_position(@face)
#               end
#           end
            @section_group    = arg1
            @section          = Section.section(@section_group.guid)
            @tag              = arg0.get_attribute("ConnectorAttributes", "tag")
            @linked_guid      = arg0.get_attribute("ConnectorAttributes", "linked_guid")
            @label            = arg0.get_attribute("ConnectorAttributes", "label")
            if @label.nil?
                @label        = "S#{@section.section_index_g}_#{@tag}"
                arg0.set_attribute("ConnectorAttributes", "label", @label)
            end
            @position         = arg0.get_attribute("ConnectorAttributes", "position")
            @normal           = arg0.get_attribute("ConnectorAttributes", "normal")
            @theta            = arg0.get_attribute("ConnectorAttributes", "theta")
            @connector_group  = arg0
        end

    end

    def face_position(face)
                                # Assume face contains 1 point midway 
                                # sides of bottom of faces that defines 
                                # center
        pts_a = face_points(face)
        pts   = pts_a[0]
        ic    = pts_a[1]
        xform     = @section_group.transformation
        position = pts[ic].transform(xform)
        normal   = (Geom::Vector3d.new(0,0,0) - face.normal)
        theta = atan2(normal.y, normal.x) + atan2(xform.xaxis.y, xform.xaxis.x)
        normal   = normal.transform(xform)
        return [position, normal, theta]
    end

    def face_points(face = nil)
        f = face
        if face.nil?
            f = @face
        end
        pts = []
        f.vertices.each_with_index do |v,i|
                pts[i] = v.position
        end
        i = 0
        ic = 99
        while i < pts.length
            if i+1 != pts.length
                pc = Geom::Point3d.linear_combination(0.5, pts[i+1], 0.5, pts[i-1])
            else
                pc = Geom::Point3d.linear_combination(0.5, pts[0], 0.5, pts[i-1])
            end
            if pts[i] == pc
                ic = i
            end
            i = i + 1
        end
        return [pts, ic]
    end

    def label
        return @label
    end

    def print_face(connection_group, tag)
        face = nil
        connection_group.entities.each do |e|
            if e.is_a? Sketchup::Face
                face = e
                break
            end
        end
        position = face_position(face)
        normal  = face.normal
        puts "face_position #{tag}"
        puts "position #{position.inspect}"
        puts "normal   #{normal.inspect}"
        face.vertices.each_with_index do |v,i|
            puts "point #{i} #{v.position.inspect}"
        end
    end

    def draw_face(view)
        pts_a = face_points
        ic = pts_a[1]
        pc = pts_a[0][ic]
        pts = []
        n = 0
        while n < pts_a[0].length
            if n != ic
                v = pts_a[0][n] - pc
                v.length = 0.5
                p = pts_a[0][n] + v
                pts[n] = p.transform @section_group.transformation
            end
            n = n + 1
        end
        pts[n] = pts[0]
        view.draw_polyline(pts)
    end

    def check_slope(slope)
        target_slope = @normal.z
        if  (slope - target_slope).abs > @@slope_max
            UI.messagebox("WARNING: differential slope >> slope_max = #{@@slope_max}\n" +
                          "slope = #{slope}, target_slope = #{target_slope}" )
            return false
        end
        return true
    end
     
    def close_enough(connector_2)
        position_1 = @position
        position_2 = connector_2.position
        distance = position_1.distance position_2
        $logfile.puts "close_enough: position delta = #{distance}"
        if distance > @@delta_max
            str = "close_enough:failed #{self.name} #{connector_2.name} " +
                               " ndot = #{distance} > delta_max = #{@@delta_max}"
            puts str
            return false
        end
        
        normal_1 = @normal
        normal_2 = connector_2.normal
        ndot = normal_1.dot normal_2
        ndot = -ndot
        if ndot < 0.0 
            return false
        end
        if ndot < @@dot_min
            str = "close_enough:failed #{self.name} #{connector_2.name} " +
                               " ndot = #{ndot} < @@dot_min = #{@@dot_min}"
            $logfile.puts str
            puts str
            return false
        end
        return true
    end

    def verify_connection
        cpt = Connector.connector(linked_guid)
        if cpt.nil?
            self.linked_guid = "UNCONNECTED"
            return
        end

        if close_enough(cpt)
            $logfile.puts "Connection verified: #{self.name} to  #{cpt.name}"
            return true
        else
            $logfile.puts "Connection broken: #{guid} #{@linked_guid}"
            break_connection_link
            return false
        end
    end

    def name
        nm = "S#{@section.section_index_g}-#{@tag}"
        #puts nm
        return nm
    end

    def section_guid 
        return @section.guid
    end

    def parent_section
        return @section
    end
    def parent_section=(section)
        puts "###################################################Connector.parent_section=" +
                    "SHOULD NEVER GET HERE############################################"
        @section       = section
        @section_group = section.section_group
    end

    def linked_guid
        return @linked_guid
    end

    def linked_connector
        return  Connector.connector(@linked_guid)
    end

    def connected?
        if @linked_guid == "UNCONNECTED"
            return false
        else
            return true
        end
    end

    def linked_guid= guid
        @linked_guid = guid
        cname = "ConnectorAttributes"
        @connector_group.set_attribute(cname, 
                                        "linked_guid", 
                                        @linked_guid)
    end

    def make_connection_link(cpt)
        if cpt.is_a? StartPoint
            return
        else
            self.linked_guid= cpt.guid
            cpt.linked_guid = guid
            $logfile.puts "make_connection_link: #{self.name} to #{cpt.name}"
        end
    end

    def break_connection_link
        cpt = Connector.connector(@linked_guid)
        puts "Connector.break_connection_link, #{cpt.linked_guid}, #{self.linked_guid}"
        cpt.linked_guid= "UNCONNECTED"
        self.linked_guid    = "UNCONNECTED"
    end

    def guid
        if @connector_group
            return @connector_group.guid
        else
            return ""
        end
    end

    def tag=(t)
        @tag = t
        cname = "ConnectorAttributes"
        @connector_group.set_attribute(cname, "tag", @tag)
        $logfile.puts "connector.tag=, tag updated new tag = #{@tag} #{guid}"
    end

    def position(app_flg=true)
        if app_flg == true
            return @position
        else
            return @position.transform(@section_group.transformation.inverse)
        end
    end

    def theta(app_flg=true)
        if app_flg == true
            return @theta
        else
            xform = @section_group.transformation.inverse
            return @theta + atan2(xform.xaxis.y, xform.xaxis.x)
        end
    end

    def normal (app_flg=true)
        return @normal
    end

    def to_s(ntab = 1)
        x = @position.x
        y = @position.y
        z = @position.z
        a = @theta * 180.0 / Math::PI
        stab =""
        n = 0
        while n < ntab
            stab = stab + " \t"
            n += 1
        end
        stab+"Connector: guid #{self.guid},  " +
                             "tag=#{@section.section_index_g} #{@tag} \n" + 
          stab+"\tposition     (#{x.to_s},#{y.to_s},#{z.to_s}), theta #{a} \n" +
          stab+"\tlinked_guid  #{@linked_guid} \n" +
          stab+"\tsection_guid #{@section.guid} \n"
    end
end
