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

include Math

class StraightSection < Section

    #####################################################################
    ###################################################  initialize
    def initialize( arg)
        @type = "straight"
        @lens = Hash.new
        @lens["10.0"]  = [10.0,  24]
        @lens["5.0"]   = [5.0,   12]
        @lens["4.5"]   = [4.5,   11]
        @lens["1.75"]  = [1.75,  4]
        @lens["1.375"] = [1.375, 3]
        super(arg)
    end
    ################################################# end initialize

    ####################################################################
    ############################################### load_sketchup_group
    def load_sketchup_group
        sname = "SectionAttributes"
        @lencode    = @section_group.get_attribute(sname, "lencode")
        @slope      = @section_group.get_attribute(sname, "slope")
        @zone_name  = @section_group.get_attribute(sname, "zone_name")
        @zone_index = @section_group.get_attribute(sname, "zone_index")
        xform_bed_a = @section_group.get_attribute(sname, "xform_bed")
        @xform_bed  = Geom::Transformation.new(xform_bed_a)
        @code = @lencode
    end

    ####################################################################
    ################################################ build_sketchup_section
    def build_sketchup_section(target_point)
        if $repeat == -1
            okflg = false
            while !okflg
                okflg = true
                prompts = [$exStrings.GetString("Length"),
                           $exStrings.GetString("Slope"),
                           $exStrings.GetString("Connect With"),
                           $exStrings.GetString("Repeat")]
                values = [@@lencode, @@slope, "A", 1]
                tlist  = ["10.0|5.0|4.5|1.75|1.375", "", "A|B",""]

                results = inputbox prompts, values, tlist, 
                             $exStrings.GetString("StraightTrack Dimensions")
                if not results
                    $repeat = 1  # force loop in onMouseMove to quit
                    return
                end
                @@lencode,  @@slope, @@tag_cnnct, $repeat = results
                if !target_point.check_slope(@@slope)
                    okflg = false
                end
            end
        end
        timer = Timer.new("StraightSection.build_sketchup_group, repeat = #{$repeat}")
        @lencode      = @@lencode
        @slope        = @@slope
        @tag_cnnct    = @@tag_cnnct
        lngth          = @lens[@lencode][0]
        n_section_ties = @lens[@lencode][1]
        @code = @lencode

        dh       = @slope * lngth
        dx       = 0
        dl       = lngth
        alpha      = asin( dh /dl )
        vt         = Geom::Vector3d.new 0,  dl, dh
        p0         = Geom::Point3d.new  0,  0,  0
        @xform_bed = Geom::Transformation.translation( vt )

        ux         = Geom::Vector3d.new 1, 0, 0
        uz         = Geom::Vector3d.new 0, 0, 1
        tr_alpha   = Geom::Transformation.rotation p0, ux, alpha


        sname = "SectionAttributes"
        @section_group.set_attribute(sname, "type",      "straight")
        @section_group.set_attribute(sname, "lencode",    @lencode)
        @section_group.set_attribute(sname, "slope",      @slope)
        @section_group.set_attribute(sname, "xform_bed",  @xform_bed.to_a)
        @section_group.set_attribute(sname, "zone_name",  "unassigned")
        @section_group.set_attribute(sname, "zone_index", 9999)

        lpts = []
        np = @@bed_profile.length
        i = 0
        while i < np do
            lpts[i] = @@bed_profile[i].transform tr_alpha
            i += 1
        end

    # Build section bed and ties

        body_group = @section_group.entities.add_group
        body_group.name = "track"
        body_group.layer= "track_sections"
        footprnt_group = @section_group.entities.add_group
        footprnt_group.name= "footprint"
        footprnt_group.layer= "footprint"

        pz = (target_point.position true).z
        p0 = Geom::Point3d.new(@@bed_profile[0].x, @@bed_profile[0].y, 0.0)
        p2 = Geom::Point3d.new(@@bed_profile[2].x, @@bed_profile[2].y, 0.0)
        t1 = Geom::Transformation.translation([0.0, lngth, dh])
        q0 = p0.transform t1
        q2 = p2.transform t1
        footprnt_group.entities.add_edges(p0, q0)
        footprnt_group.entities.add_edges(p2, q2)
        footprnt_group.entities.add_edges(q0, q2)
        cpts = []       # cpts will be updated in  extend_profile 
        StraightSection.extend_profile(@section_group, body_group,
                                       n_section_ties,
                                       lpts,
                                       @xform_bed,
                                       @@bed_mat,
                                       true, 
                                       cpts)
     # add section rails
        rh = @@bed_h + @@tie_h
        nr = 0
        while nr < 3
            offset = Geom::Vector3d.new( (nr-1)*0.6875, 0, rh)
            lpts = []
            np = @@rail_profile.length
            i = 0
            while i < np do
                lpts[i] = @@rail_profile[i].transform tr_alpha
                lpts[i] = lpts[i] + offset
                i += 1
            end
            StraightSection.extend_profile(@section_group, body_group,
                                           n_section_ties,
                                           lpts,
                                           @xform_bed,
                                           @@rail_mat, 
                                           false,
                                           cpts)
            nr += 1
        end
        self.connection_pts= cpts
        section_point = connection_pt(@tag_cnnct)
        tr_group = make_tr_group(target_point, section_point)
        @section_group.transformation = tr_group
        if @tag_cnnct == "A"
            connection_pt("A").make_connection_link(target_point)
            $current_connection_point = connection_pt("B")
        else
            connection_pt("B").make_connection_link(target_point)
            $current_connection_point = connection_pt("A")
        end
        $logfile.puts timer.elapsed
        return true
    end
    ##############################################end build_sketchup_section

    ######################################################################
    ##################################### outline_group_factory
    def outline_group_factory(zone_group)
        timer = Timer.new("StraightSection.outline_group_factory")
        outline_group = zone_group.entities.add_group
        outline_group.material = Zone.material
        style    = Zone.style

        outline_group.layer = "zones"
        outline_group.name  = "outline"
        outline_group.attribute_dictionary("OutlineAttributes", true)
        outline_group.set_attribute("OutlineAttributes", "section_guid", @section_group.guid)
        outline_group.set_attribute("OutlineAttributes", "section_index", @section_index)
        entry_tag = self.entry_tag
        cpt = connection_pt(entry_tag)
        $logfile.puts "StraightSection.build_outline_group, section #{@section_index}" +
                          " entry_tag #{entry_tag}"
        slope = @slope
        if entry_tag != "A"
            slope = -@slope
        end
        dl        = @lens[@lencode][0]
        dh        = slope * dl
        alpha      = asin( dh /dl )
        p0         = Geom::Point3d.new  0,  0,  0
        ux         = Geom::Vector3d.new 1, 0, 0
        tr_alpha   = Geom::Transformation.rotation p0, ux, alpha
        vt        = Geom::Vector3d.new(0.0, dl, dh)
        xform_bed = Geom::Transformation.translation(vt)
        ic     = 1
        center = @@bed_profile[ic]
        lpts   = []
        rpts   = []
        j      = 0
        @@bed_profile.each_with_index do |pt, i|
            if i != ic
                v = pt - center
                v.length = 1.0
                p    = []
                lpts[j] = (pt + v).transform tr_alpha
                j += 1
            end
        end
        np = j
        if style == "faces"
            lpts.each_with_index {|p,i| rpts[i] = p.transform xform_bed}
            Section.add_faces(outline_group.entities, lpts, rpts, material)
        else
            np.times { |i|
                edges = outline_group.entities.add_edges(lpts[i-1],lpts[i])
            }
            lpts.each_with_index {|p,i| rpts[i] = p.transform xform_bed}
            np.times { |i|
                edges = outline_group.entities.add_edges(rpts[i], lpts[i])
            }
            np.times { |i|
                edges = outline_group.entities.add_edges(rpts[i-1],rpts[i])
            }
            outline_group.entities.add_face(lpts[0], lpts[1], rpts[1], rpts[0])
        end
        tr_group = make_tr_group(cpt)
        outline_group.transformation = tr_group
        outline_text_group_factory(outline_group)

        $logfile.puts timer.elapsed
        return outline_group
    end

    def outline_text_group_factory(outline_group)
        text_group = outline_group.entities.add_group
        text_group.name = "text"

        puts " #{@section_index}   #{@entry_tag}  #{@section_group.guid}"
        puts " #{@section_index}   #{@exit_tag}"
        puts " #{@section_index}   #{@slope}"
        entry_tag = self.entry_tag
        slope     = @slope
        if entry_tag != "A"
            slope = - @slope
        end
        char_group = text_group.entities.add_group
        char_group.entities.add_3d_text(@zone_name, TextAlignLeft, @@ofont, @@obold, false,
                                             @@otxt_h, 0.6, 0.0, @@ofill)
        bx = char_group.bounds
        bkgrnd_w = bx.width + 1.0
        bkgrnd_h = 1.25
        puts "bkgrnd_w #{bkgrnd_w}"
        len_s    = @lens[@lencode][0]
        if bkgrnd_w > len_s
            char_group.entities.clear!
            text_group.erase!
            text_group = nil
            return text_group
        end
        xmn      = -0.5 * bkgrnd_h 
        xmx      = +0.5 * bkgrnd_h 
        ymn      = 0.5 *len_s - 0.5 * bkgrnd_w
        ymx      = 0.5 *len_s + 0.5 * bkgrnd_w
        puts "xmn #{xmn}"
        puts "xmx #{xmx}"
        puts "ymn #{ymn}"
        puts "ymx #{ymx}"
        trkh     = @@bed_h + @@tie_h + 0.25
        bkz      = trkh + 0.01
        p0   = Geom::Point3d.new(xmn, ymn, bkz)
        p1   = Geom::Point3d.new(xmn, ymx, bkz)
        p2   = Geom::Point3d.new(xmx, ymx, bkz)
        p3   = Geom::Point3d.new(xmx, ymn, bkz)
        face = text_group.entities.add_face(p0, p1, p2, p3)
        face.back_material= "white"
        face.material = "white"
        face.edges.each {|e| e.hidden=true}

        orgx  = 0.5 * bx.height
        orgy  = 0.5 * len_s - 0.5 * bx.width
        orgz  = trkh + 0.02
        vt    = Geom::Vector3d.new( orgx, orgy, orgz)
        p0    = Geom::Point3d.new(0.0, 0.0, 0.0)
        uz    = Geom::Vector3d.new(0.0, 0.0, 1.0)
        t1    = Geom::Transformation.rotation(p0, uz, 0.5 * Math::PI)
        xform = Geom::Transformation.translation( vt) * t1
        char_group.transform! xform
        char_entities = char_group.explode
        ux    = Geom::Vector3d.new(1.0, 0.0, 0.0)
        
        xforms = Geom::Transformation.rotation(p0, ux, atan(slope) )
        text_group.transform!  xforms
        return text_group
    end
        

    ######################################################################
    ###################################### Report
    def report
        sname = "SectionAttributes"
        if @section_group.nil?
            puts "StraightSection.report: @section_group is nil"
        end
        lngth  = @lens[@lencode][0]

        return [@type, sprintf("%5s",lngth)]
    end

    ######################################################################
    ##################################### info
    def info(cpt0)
        sname = "SectionAttributes"
        tag = cpt0.tag

        cpt1 = nil
        if tag == "B"
            cpt1 = self.connection_pt("A")
        else
            cpt1 = self.connection_pt("B")
        end
        
        info_text = "Straight " + @lencode
        q = Geom::Point3d.new(0, 0, 0)
        return ["straight", info_text, q]
    end

    def tag
        return sprintf("%s-S%04d", @zone_name, @zone_index)
    end

    ######################################################################
    ####################################### StraightSection.extend_profile

    def StraightSection.extend_profile(section_group, body_group,
                                       n_section_ties,
                                       lpts,
                                       tr_bed,
                                       face_mat,
                                       tie_flg,
                                       cpts)

        face_A = body_group.entities.add_face(lpts)
        np = lpts.length
        rpts = []
        nr   = 0
        lpts.each do |x|
            rpts[nr] = x.transform tr_bed
            nr += 1
        end
        Section.add_straight_faces(body_group.entities, 
                                   lpts, 
                                   rpts, 
                                   face_mat)
        face_B = body_group.entities.add_face(rpts)
        if tie_flg
            nc = cpts.length
            cpts[nc] = Connector.factory(section_group, "A", face_A)
            nc = cpts.length
            cpts[nc] = Connector.factory(section_group, "B", face_B)
        end

        if ( tie_flg) then
            vs = rpts[3] - lpts[3]
            dt = (vs.length) / n_section_ties
            v1 = vs
            v1.length = dt
            bpts = []
            bpts[0] = lpts[np-1]
            bpts[1] = lpts[np-2]
            n = 0 
            while ( n < n_section_ties)
                bpts[2] = bpts[1] + v1
                bpts[3] = bpts[0] + v1
                Section.make_tie( body_group.entities, bpts)
                bpts[1] = bpts[2]
                bpts[0] = bpts[3]
                n += 1
            end
        end
        return 

        #### The decison to reverse face_A and face_B was determined 
        #### heuristically. If the algorithm for doing extention of
        #### bed_profile changes the decision may have to changed as well
    end
    #################################### end StraightSection.extend_profile

end  # end of Class StraightSection