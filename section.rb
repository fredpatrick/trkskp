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
$exStrings = LanguageHandler.new("track.strings")

require "#{$trkdir}/connectionpoint.rb"

include Math

class Section
    require "#{$trkdir}/sectionshell.rb"
    require "#{$trkdir}/curvedsection.rb"
    require "#{$trkdir}/straightsection.rb"
    require "#{$trkdir}/switchsection.rb"

    def Section.init_class_variables
        puts "Section.init_class_variables"
        @@track_sections = Hash.new
        ################################# inputbox defaults
        Section.get_class_defaults

        #################################  TrackAttributes
        @@model = Sketchup.active_model
        mattrs = @@model.attribute_dictionary( "TrackAttributes" )
        aname = "TrackAttributes"
        if mattrs
            $logfile.puts "mattrs true"
            @@bed_h         = @@model.get_attribute(aname,"bed_h")
            @@bed_w         = @@model.get_attribute(aname,"bed_w")
            @@bed_tw        = @@model.get_attribute(aname,"bed_tw")
            @@bed_mat       = @@model.get_attribute(aname,"bed_mat")
            @@bed_profile   = @@model.get_attribute(aname,"bed_profile")
            @@tie_h         = @@model.get_attribute(aname,"tie_h")
            @@tie_w         = @@model.get_attribute(aname,"tie_w")
            @@tie_mat       = @@model.get_attribute(aname,"tie_mat")
            @@rail_mat      = @@model.get_attribute(aname,"rail_mat")
            @@rail_profile  = @@model.get_attribute(aname,"rail_profile")
            @@base_h        = @@model.get_attribute(aname,"base_h")
            @@base_w        = @@model.get_attribute(aname,"base_w")
            @@base_d        = @@model.get_attribute(aname,"base_d")
            @@section_count = 9999
            $logfile.puts "section_count-0 #{@@section_count}"
            @@section_count = @@model.get_attribute(aname,"section_count")
            $logfile.puts "section_count-1 #{@@section_count}"
            puts "@@section_count: #{@@section_count}"
            @@switch_count  = @@model.get_attribute(aname,"switch_count")
            $logfile.puts "switch_count-1 #{@@switch_count}"
            if @@switch_count.nil?
                @@switch_count = @@model.set_attribute(aname, "switch_count", 0)
            else
                @@switch_count  = @@model.get_attribute(aname,"switch_count")
            end
        else
            $logfile.puts "mattrs false"
            mattrs = @@model.attribute_dictionary( "TrackAttributes" , true)
            @@bed_h         = @@model.set_attribute(aname,"bed_h",0.4375)
            @@bed_w         = @@model.set_attribute(aname,"bed_w",3.3125)
            @@bed_tw        = @@model.set_attribute(aname,"bed_tw",2.5)
            @@bed_mat         = @@model.set_attribute(aname,"bed_mat","LightGrey")
            @@bed_profile   = @@model.set_attribute(aname,"bed_profile",
                             [Geom::Point3d.new( @@bed_w * 0.5  ,0 ,0),
                              Geom::Point3d.new( 0            ,0 ,0),
                              Geom::Point3d.new(-@@bed_w * 0.5  ,0 ,0),
                              Geom::Point3d.new(-@@bed_tw * 0.5 ,0 ,0.4375),
                              Geom::Point3d.new( @@bed_tw * 0.5 ,0 ,0.4375)])
            @@tie_h         = @@model.set_attribute(aname,"tie_h",0.03125)
            @@tie_w         = @@model.set_attribute(aname,"tie_w",0.15625)
            @@tie_mat       = @@model.set_attribute(aname,"tie_mat","black")
            @@rail_mat      = @@model.set_attribute(aname,"rail_mat","gold")
            @@rail_profile  = @@model.set_attribute(aname,"rail_profile",
                             [Geom::Point3d.new( 0.0625 ,0 ,0),
                              Geom::Point3d.new(-0.0625 ,0 ,0),    
                              Geom::Point3d.new(-0.0625 ,0 ,0.25),
                              Geom::Point3d.new( 0.0625 ,0 ,0.25) ])
            @@section_count = @@model.set_attribute(aname,"section_count",0)
            $logfile.puts "section_count #{@@section_count}"
            @@switch_count  = @@model.set_attribute(aname,"switch_count",0)
            layers = @@model.layers
            $logfile.puts "layers #{layers.length}"
            layers.add "footprint"
            layers.add "track_sections"
            layers.add "structure"
            layers.add "table"
            $logfile.puts "layers #{layers.length}"
        end
        @@otxt_h = 1.0
        @@ofont  = "Courier"
        @@obold  = false
        @@ofill  = false
        @@otxt_w = 0.7865
    end
    def Section.get_class_defaults
        puts "get_class_defaults"
        dname = "SectionBuildDefaults"
        model = Sketchup.active_model
        tdflts = model.attribute_dictionary(dname, true)
        @@dcode    = model.get_attribute(dname, "dcode",   "O72")
        @@arctyp   = model.get_attribute(dname, "arctyp",  "Full")
        @@direc    = model.get_attribute(dname, "direc",   "Left")
        @@lencode  = model.get_attribute(dname, "lencode", "10")
        @@slope    = model.get_attribute(dname, "slope",   0.02)
    end
    def Section.set_class_defaults
        puts "set_class_defaults"
        dname = "SectionBuildDefaults"
        model = Sketchup.active_model
        tdflts = model.attribute_dictionary(dname)
        puts tdflts.name
        model.set_attribute(dname, "dcode",    @@dcode)
        model.set_attribute(dname, "arctyp",   @@arctyp)
        model.set_attribute(dname, "direc",    @@direc)
        model.set_attribute(dname, "lencode",  @@lencode)
        model.set_attribute(dname, "slope",    @@slope)
    end
    
    ###############################################################
    ###################################### Section.factory
    def Section.factory (section_group, connection_point = nil)
        section_type = section_group.get_attribute("SectionAttributes", "section_type")
        section = nil
        if section_type == "curved"
            section = CurvedSection.new(section_group)
        elsif section_type == "straight"
            section = StraightSection.new(section_group)
        elsif section_type == "switch"
            section = SwitchSection.new(section_group)
        end
        @@track_sections[section.guid] = section
        if ( !connection_point.nil? )
            $logfile.puts "section.factory-new_section begin"
            section_group.attribute_dictionary("SectionAttributes",true)
            section_index_g = @@section_count
            @@section_count += 1
            @@model.set_attribute("TrackAttributes","section_count", @@section_count)        
            if !section.build_sketchup_section(connection_point, section_index_g)
                $logfile.puts "section_factory erase section_group"
                @@track_sections.delete section.guid
                section_group.erase!
                $logfile.flush
                return nil
            end
            $logfile.puts "section.factory-new_section section_group built"
            TrackTools.model_summary
        else
            section.load_sketchup_group
            section.connectors= Connector.load_connectors(section_group)
        end
        $logfile.puts section.to_s
        $logfile.flush
        return  section
    end

    ###############################################################
    ############################################## Erase
    def Section.erase(section_group)
        $logfile.puts "Section.erase #{section_group.guid}"
        @@track_sections.delete section_group.guid
        section_group.erase!
        $logfile.flush
    end
    def Section.remove_section_entry(guid)
        @@track_sections.delete guid
    end

    ###############################################################
    #################################################### initialize

    def initialize( section_group)
        @section_group   = section_group
        @section_type    = section_group.get_attribute("SectionAttributes", "section_type")
        @section_index_z = section_group.get_attribute("SectionAttributes", "section_index_g")
        sname = "SectionAttributes"
        sattrs = section_group.attribute_dictionary(sname)
        if !sattrs                       # if no dictionary this is new section_group
            section_group.attribute_dictionary(sname, true)
            section_group.name = "section"
        else                             # this is existiong section_group
            @shells          = Hash.new
            @section_group.entities.each do |e|
                if ( e.is_a? Sketchup::Group )
                    if ( e.name == "slices" )
                        type = e.get_attribute("SectionShellAttributes", "shell_type")
                        shell = SectionShell.new(e, self)
                        @shells[shell.guid] = shell
                    elsif ( e.name == "outline" )
                        @outline_group = e
                    elsif ( e.name == "outline_text" )
                        @outline_text_group = e
                    end
                end
            end
        end
    end

    def Section.connect_sections
        $logfile.puts "Begin Section.connect_sections"
        Section.list_sections
        uclist = []
        nuc = 0
        Section.sections.each do |s|
            s.connectors.each do |c|
                if !c.connected?
                    uclist[nuc] = c
                    nuc += 1
                 else
                    if !c.verify_connection
                        uclist[nuc] = c
                        nuc += 1
                    end
                end
            end
        end
        $logfile.puts "Section.connect_sections:There are #{nuc} unconnected ConnectionPoints"
        $logfile.flush
        uclist.each_with_index do |c,i|
            uclist[i] = nil
            if !c.nil?
                uclist.each_with_index do |ct,j|
                    if !ct.nil?
                        if c.close_enough(ct)
                            c.make_connection_link(ct)
                            uclist[j] = nil
                        end
                    end
                end
            end
        end
        nuc = 0
        Section.sections.each do |s|
            s.connectors.each do |c|
                if !c.connected?
                    $logfile.puts "Section.connect_sections, #{nuc} connector.guid = " +
                    #{c.guid}, connector.tag = #{c.tag}, " +
                                "section_index_g = #{c.parent_section.section_index_g}"
                    nuc += 1
                end
            end
        end
        $logfile.puts "Section.connect_sections: Final pass #{nuc} " +
                                                    "unconnected Connectors remain"
        $logfile.flush
        puts "Section.connect_sections: Final pass #{nuc} unconnected Connectors remain"
    end

    def section_id
        return @section_group.guid
    end

    def guid
        return @section_group.guid
    end

    def section_type
        return @section_type
    end

    def section_group
        return @section_group
    end

    def section_index_g
        return @section_index_g
    end

    def update_zone_dependencies
        if ( !@outline_text_group.nil?)
            @outline_text_group.erase!
        end
        @outline_text_group = outline_text_group_factory
    end

    def slope
        return @slope
    end

    def code
        return @code
    end

    def closed?
        return @closed
    end

    def outline_visible (ov )
        @outline_group.visible = ov
    end

    def outline_material (color)
        @outline_group.material = color
    end

    ###############################################################
    #################################################### closest_point
    def closest_point(target_pt)
        #puts "Section.closest_point, target_pt = #{target_pt.to_s}"
       it_min = 9999
        distance_min = 9999.0
        it = 0
        #puts "Section.closest_point, @connectors.length = #{@connectors.length}"
        while it < @connectors.length
            #puts "Section.closet_point, @connectors[it].guid = #{@connectors[it].guid}"
            if !@connectors[it].connected?
                distance = target_pt.distance(@connectors[it].position(true))
                #puts "Section.closest_point, distance = #{distance}"
                p = @connectors[it].position(true)
                if distance < distance_min
                    it_min = it
                    distance_min = distance
                end
            end
            it += 1
        end
        if it_min == 9999 
            return nil
        else
            return @connectors[it_min]
        end
    end

    ###############################################################
    ############################################## connectors=
    def connectors=(ctrs)
        @connectors_h = Hash.new
        @connectors = ctrs
        @connectors.each do |c|
            @connectors_h[ c.tag ] = c
        end
    end

    ############################################## connectors
    def connectors
        return @connectors
    end

    ###############################################################
    ############################################## connection_point
    def connector(tag)
        return @connectors_h[tag]
    end

    ###############################################################
    ############################################## reverse forward direction
    def reverse_forward_direction
        cpt_A = @connectors_h["A"]
        cpt_B = @connectors_h["B"]
        cpt_A.tag = "B"
        cpt_B.tag = "A"
        @connectors_h["A"] = cpt_B
        @connectors_h["B"] = cpt_A
        @slope = -@slope
        @section_group.set_attribute("SectionAttributes", "slope", @slope)
    end

    ##################################################################
    ######################################  make tr_group
    def make_tr_group(target_point, section_point=nil)
        puts "make_tr_group, target_point = #{target_point.position}, section_point = #{section_point}" 
        uz         = Geom::Vector3d.new(0.0, 0.0, 1.0)
        if !section_point.nil?
            theta_a    = section_point.theta(false)
            position_a = section_point.position(false)
            theta_t    = target_point.theta
            position_t = target_point.position
            theta      = theta_t - ( theta_a + Math::PI)
        else                        # this assumes that section_group transformation is defined
            theta_a    = target_point.theta(false)
            position_a = Geom::Point3d.new(0.0, 0.0, 0.0)
            theta_t    = target_point.theta
            position_t = target_point.position
            theta      = theta_t + 0.5 * Math::PI
        end
        #puts "make_tr_group: tag_a #{section_point.tag}"
        $logfile.puts "make_tr_group: position_a #{position_a}"
        $logfile.puts "make_tr_group: theta_a #{theta_a*180.0/Math::PI}"
        $logfile.puts "make_tr_group: tag_t #{target_point.tag}"
            $logfile.puts "make_tr_group: position_t #{position_t}"
            $logfile.puts "make_tr_group: theta_t #{theta_t*180.0/Math::PI}"
        t2         = Geom::Transformation.rotation( position_a, uz, theta)
        x0         = position_t.x - position_a.x
        y0         = position_t.y - position_a.y
        z0         = position_t.z - position_a.z
        vg         = Geom::Vector3d.new( x0, y0, z0)
        tv         = Geom::Transformation.translation( vg )
        tr_group = tv * t2
        return tr_group
    end

    def make_transformation(target_position, target_normal, source_position, source_normal)
        source_normal.z = 0.0
        target_normal.z = 0.0
        source_normal   = Geom::Vector3d.new(0.0, 0.0, 0.0) - source_normal
        cos             = source_normal.dot(target_normal)
        sin             = source_normal.cross(target_normal).z
        rotation_angle  = Math.atan2(sin, cos)
        shift           = target_position - source_position
        xform_rotate    = Geom::Transformation.rotation(source_position,
                                                        Geom::Vector3d.new(0.0, 0.0, 1.0),
                                                        rotation_angle)
        xform_shift     = Geom::Transformation.translation(shift)
        return xform_shift * xform_rotate
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

    ##################################################################
    ############################################## to_s
    def to_s(ntab = 1)
        stab = ""
        1.upto(ntab) {|i| stab = stab + "\t"}
        str = stab + "Section: guid #{guid}" + " type  #{@section_type} "
        str = str + "section_index_g #{@section_index_g} \n"
        @connectors.each do |cpt|
            str = str +  cpt.to_s(ntab+1)
        end
        return str
    end



    ###############################################################
    ############################################## Section.section_group?
    def Section.section_group?(entity)
        if entity.nil?
            return false
        elsif !entity.is_a? Sketchup::Group 
            return false
        elsif entity.name != "section"
            return false
        else
            return true
        end
    end

    ############################################# Section.section
    def Section.section(group_guid)
        return @@track_sections[group_guid]
    end

    ############################################# Section.sections
    def Section.sections
        return @@track_sections.values
    end

    ##################################################################### Section.section_path?
    def Section.section_path? (path) 

        path.each_with_index do |e,i|
            if ( e.is_a? Sketchup::Group )
                #puts "Section.section_path? #{i}, e.name = #{e.name}, #{e.guid}"
                if ( e.name == "section" )
                    section = @@track_sections[e.guid]
                    return section
                end
            else
                return nil
            end
        end
        return nil
    end

    def Section.switches
        sws = []
        nsw = 0
        @@track_sections.values.each do |s|
            if s.type == "switch"
                sws[nsw] = s
                nsw += 1
            end
        end
        return sws
    end

    def Section.list_sections
        @@track_sections.each do |k,v|
            #puts "Section.list_sections, #{v.section_index_g}, #{v.section_type}, #{v.guid}"
        end
    end

    ####################################################################
    ######################################## Section.make_tie
    def Section.make_tie(entities, bpts )

  
        width = (bpts[2] - bpts[1]).length
        e     = 0.5 * (1.0 - @@tie_w/width)
        r1 = 1.0 - e
        r2 = e
        upts = []
        vpts = []
        upts[0] = Geom::Point3d.linear_combination r1, bpts[0], r2, bpts[3]
        vpts[0] = Geom::Point3d.linear_combination r2, bpts[0], r1, bpts[3]
        upts[1] = Geom::Point3d.linear_combination r1, bpts[1], r2, bpts[2]
        vpts[1] = Geom::Point3d.linear_combination r2, bpts[1], r1, bpts[2]
    
        plane = Geom.fit_plane_to_points( bpts )
        v = Geom::Vector3d.new(plane[0], plane[1], plane[2])
         v.normalize!
        v.length = -@@tie_h

        upts[2] = upts[1] + v
        upts[3] = upts[0] + v
        vpts[2] = vpts[1] + v
        vpts[3] = vpts[0] + v
  
        Section.add_faces( entities, upts, vpts, @@tie_mat)
    end 
    
    #####################################################################
    ########################################### Section.add_faces

    def Section.add_faces( entities, lpts, rpts, face_mat)
        nr   = lpts.length
        i = 0
        while i < nr
            entities.add_edges( lpts[i], rpts[i])
            edges = entities.add_edges(rpts[i - 1], rpts[i])
            edges[0].hidden = true
            face_1 = entities.add_face(lpts[i-1], lpts[i], rpts[i])
            face_1.material = face_mat
            face_1.back_material = face_mat
            face_2 = entities.add_face(lpts[i-1], rpts[i], rpts[i-1])
            face_2.material = face_mat
            face_2.back_material = face_mat
            edges = entities.add_edges(lpts[i-1], rpts[i])
            edges[0].hidden = true
            i  += 1
        end
    end 

    ######################################################################
    ########################################### Section.add_straight_faces
    
    def Section.add_straight_faces( entities, lpts, rpts, face_mat)
        nr   = lpts.length
        i = 0
        while i < nr
            face = entities.add_face(lpts[i-1], lpts[i], rpts[i], rpts[i-1])
            face.material = face_mat
            face.back_material = face_mat
            i  += 1
        end
    end 

    def Section.dump_transformation(xform, level)
        xf = xform.to_a
        str = ""
        tag= "transformation:"
        4.times { |n|
            n4 = n * 4
            str = str + tabs(level) + sprintf("%15s %10.6f,%10.6f,%10.6f,%10.6f\n",tag, xf[0+n4], xf[1+n4], xf[2+n4],xf[3+n4])
            tag = ""
        }
        return str
    end

    def Section.face_to_a(f)
        slice_index = f.get_attribute("SliceAttributes","slice_index")
        str = "make_skins, slice_index = #{slice_index}, "
        f.vertices.each_with_index{ |v,i| str += ", i = #{i} - #{v.position}" }
        return str
    end

    def Section.report_sections
        puts "Sections: #{@@track_sections.values.length}"
        types = Hash.new
        @@track_sections.each_value do |x|
            if x.nil?
                puts "report_sections: nil value in @@track_sections"
            end
            typ = x.report
            cc = types[typ]
            if !cc
                types[typ] = 1
            else
                cc = cc + 1
                types[typ] = cc
            end
        end
        puts "#################################### sort"
        sa = types.to_a
        sa = sa.sort {|a,b| a[0][0] <=> b[0][0] }
        sa.each do |pair|
            puts "#{pair[0]} #{pair[1]}"
        end
    end

    def Section.bed_w
        return @@bed_w
    end

    def Section.bed_h
        return @@bed_h
    end

    def Section.bed_tw
        return @@bed_tw
    end

    def Section.tie_h
        return @@tie_h
    end


end  #### end of Class Section

class Timer
    def initialize( tag )
        @tag = tag
        @t0  = Time.now.to_f
    end

    def elapsed
        @t1 = Time.now.to_f
        dt = @t1 - @t0
        @t0 = @t1
        return sprintf("%10s  %10.4f seconds", @tag, dt)
    end
end
