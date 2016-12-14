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

require 'langhandler.rb'
$exStrings = LanguageHandler.new("track.strings")

require "#{$trkdir}/connectionpoint.rb"

include Math

class Sections

    ###############################################################
    ##################################### Sections.load_sections
    def Sections.load_sections
        Section.init_class_variables
        Connector.init_class_variables
        $logfile.puts "Begin load_sections"
        @@sections_group = nil
        Sketchup.active_model.entities.each do |e|
            if e.is_a? Sketchup::Group
                if e.name == "sections"
                    @@sections_group = e
                    break
                end
            end
        end

        if @@sections_group.nil?
            $logfile.puts "Creating new sections_group"
            @@sections_group = Sketchup.active_model.entities.add_group
            @@sections_group.name = "sections"
        else
            $logfile.puts "Loading sections_group"
            @@sections_group.entities.each do |s|
                if Section.section_group? (s)
                    section = Section.factory(s, "")
                end
            end
        end
        $logfile.puts "End load_sections"
    end

    def Sections.sections_group
        return @@sections_group
    end

end # end of class Sectiuons

class Section
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
        dname = "TrackDefaults"
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
        dname = "TrackDefaults"
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
    def Section.factory (arg1, arg2)
        $logfile.puts "Section.factory  #{arg2}"
        type = ""
        section_group = nil
       new_section = false
        sname = "SectionAttributes"
        if arg1.is_a? Sketchup::Group
            type = arg1.get_attribute(sname,
                                      "type", 
                                      "notype")
            section_group = arg1
        else
            section_group = Sections.sections_group.entities.add_group
            type = arg2
            new_section = true
        end
        section = nil
        if type == "curved"
            section = CurvedSection.new(section_group)
        elsif type == "straight"
            section = StraightSection.new(section_group)
        elsif type == "switch"
            section = SwitchSection.new(section_group)
        end
        @@track_sections[section.guid] = section
        if new_section
            $logfile.puts "section.factory-new_section begin"
            section_group.attribute_dictionary(sname,true)
            @@section_count += 1
            @@model.set_attribute("TrackAttributes", "section_count", @@section_count)
            section_group.set_attribute(sname,"section_index", @@section_count)
            if !section.build_sketchup_section(arg1)
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
            section.connection_pts= Connector.load_connectors(section_group)
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

    ###############################################################
    #################################################### initialize

    def initialize( section_group)
        @section_group = section_group
        sname = "SectionAttributes"
        sattrs = section_group.attribute_dictionary(sname)
        if !sattrs                       # if no dictionary this is new section_group
            section_group.attribute_dictionary(sname, true)
            section_group.name = "section"
            @entry_tag = "U"
            @exit_tag  = "U"
        else                             # this is existiong section_group
            @zone_name     = @section_group.get_attribute(sname, "zone_name", "")
            @zone_index    = @section_group.get_attribute(sname, "zone_index", 9999)
            @entry_tag     = @section_group.get_attribute(sname, "entry_tag", "U")
            @exit_tag      = @section_group.get_attribute(sname, "exit_tag", "U")
            @section_index = @section_group.get_attribute(sname, "section_index")
        end
    end

    def Section.connect_sections
        $logfile.puts "Begin Section.connect_sections"
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
        $logfile.puts "Tracktool:There are #{nuc} unconnected ConnectionPoints"
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
                    nuc += 1
                end
            end
        end
        $logfile.puts "Tracktool: Final pass #{nuc} unconnected Connectors remain"
        puts "Tracktool: Final pass #{nuc} unconnected Connectors remain"
    end

    def section_id
        return @section_group.guid
    end

    def guid
        return @section_group.guid
    end

    def type
        return @type
    end

    def section_group
        return @section_group
    end

    def section_index
        return @section_index
    end

    def zone_name
        return @zone_name
    end

    def zone_index
        return @zone_index
    end
    
    def entry_tag
        if @entry_tag != "U"
            return @entry_tag
        else
            return "A"
        end
    end

    def exit_tag
        if @exit_tag != "U"
            return @exit_tag
        else
            return "B"
        end
    end

    def set_zone_parms (zone_name, zone_index, arg1, arg2)
        @zone_name  = zone_name
        @zone_index = zone_index
        @entry_tag  = arg1
        @exit_tag   = arg2
        @section_group.set_attribute("SectionAttributes","zone_name", @zone_name)
        @section_group.set_attribute("SectionAttributes","zone_index", @zone_index)
        @section_group.set_attribute("SectionAttributes","entry_tag", @entry_tag)
        @section_group.set_attribute("SectionAttributes","exit_tag", @exit_tag)
    end

    def reset_zone_parms
        $logfile.puts "reset_zone_parms: #{Time.now.ctime}"
        $logfile.puts "                  zone_name #{@zone_name} zone_index #{@zone_index} "
        if !@text_group.nil?
            @text_group.erase!
            @text_group = nil
        end
        @zone_name = "unassigned"
        @zone_index = 9999
        @entry_tag  = "U"
        @exit_tag   = "U"
        @section_group.set_attribute("SectionAttributes","zone_name", @zone_name)
        @section_group.set_attribute("SectionAttributes","zone_index", @zone_index)
        @section_group.set_attribute("SectionAttributes","entry_tag", @entry_tag)
        @section_group.set_attribute("SectionAttributes","exit_tag", @exit_tag)
        $logfile.flush
    end

    def slope
        return @slope
    end

    def code
        return @code
    end

    ###############################################################
    #################################################### closest_point
    def closest_point(target_pt)
       it_min = 9999
        distance_min = 9999.0
        it = 0
        while it < @connection_pts.length
            if !@connection_pts[it].connected?
                distance = 
                        target_pt.distance(@connection_pts[it].position(true))
                p = @connection_pts[it].position(true)
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
            return @connection_pts[it_min]
        end
    end

    ###############################################################
    ############################################## connection_pts=
    def connection_pts=(connection_pts)
        @cpts_h = Hash.new
        @connection_pts = connection_pts
        @connection_pts.each do |cpt|
            @cpts_h[ cpt.tag ] = cpt
        end
    end

    ############################################## connectors
    def connectors
        return @connection_pts
    end

    ###############################################################
    ############################################## connection_point
    def connection_pt(tag)
        return @cpts_h[tag]
    end

    ###############################################################
    ############################################## reverse forward direction
    def reverse_forward_direction
        cpt_A = @cpts_h["A"]
        cpt_B = @cpts_h["B"]
        cpt_A.tag = "B"
        cpt_B.tag = "A"
        @cpts_h["A"] = cpt_B
        @cpts_h["B"] = cpt_A
        @slope = -@slope
        @section_group.set_attribute("SectionAttributes", "slope", @slope)
    end

    ##################################################################
    ######################################  make tr_group
    def make_tr_group(target_point, section_point=nil)
        
        uz         = Geom::Vector3d.new(0.0, 0.0, 1.0)
        if !section_point.nil?
            theta_a    = section_point.theta(false)
            position_a = section_point.position(false)
            theta_t    = target_point.theta(true)
            position_t = target_point.position(true)
            theta      = theta_t - ( theta_a + Math::PI)
        else                        # this assumes that section_group transformation is defined
            theta_a    = target_point.theta(false)
            position_a = Geom::Point3d.new(0.0, 0.0, 0.0)
            theta_t    = target_point.theta(true)
            position_t = target_point.position(true)
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

    ##################################################################
    ############################################## to_s
    def to_s(ntab = 1)
        stab = ""
        1.upto(ntab) {|i| stab = stab + "\t"}
        str = stab + "Section: guid #{guid}" + " type  #{@type} "
        str = str + "section_index #{@section_index} \n"
        str = str + stab +"\tzone_name     #{@zone_name} zone_index #{@zone_index} \n"
        @connection_pts.each do |cpt|
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
        if !path[0].is_a? Sketchup::Group
            return nil
        elsif path[0].name != "sections"
            return nil
        end
        if !path[1].is_a? Sketchup::Group
            return nil
        elsif path[1].name != "section"
            return nil
        end
        section_group = path[1]
        section = Section.section(section_group.guid)
        return section
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
