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

class SwitchSection < Section
    
    ##################################################################
    ############################################# initialize
    def initialize( arg)
        @section_type = "switch"
        @parms = Hash.new
        @parms["O72"] = [36.0, 15.625, 37, 22.5, 34, 1.3125,  8]
        @parms["O60"] = [30.0, 14.50,  35, 22.5, 28, 0.0,   18]
        @parms["O48"] = [24.0, 15.00,  36, 30.0, 31, 0.0,   20]
        @parms["O36"] = [18.0, 10.00,  24, 45.0, 36, 0.0,   24]
        super(arg)
    end
    ######################################### end of initialize

    ###################################################################
    ###################################### load_sketchup_group
    def load_sketchup_group
        sname = "SectionAttributes"
        @dcode           = @section_group.get_attribute(sname, "diameter_code")
        @arctyp          = @section_group.get_attribute(sname, "arc_type")
        @slope           = @section_group.get_attribute(sname, "slope")
        @direc           = @section_group.get_attribute(sname, "direction")
        xform_bed_a      = @section_group.get_attribute(sname, "xform_bed")
        @xform_bed       = Geom::Transformation.new(xform_bed_a )
        xform_bed_arc_a  = @section_group.get_attribute(sname, "xform_bed_arc")
        @xform_bed_arc   = Geom::Transformation.new(xform_bed_arc_a )
        xform_alpha_a = @section_group.get_attribute(sname, "xform_alpha")
        if xform_alpha_a.nil? # this code kludge while we add slices_group
            @xform_alpha = make_xform_alpha()
            @section_group.set_attribute(sname, "xform_alpha",  @xform_alpha.to_a)
        else
            @xform_alpha  = Geom::Transformation.new(xform_alpha_a)
        end
        @switch_index = @section_group.get_attribute(sname, "switch_index")
        @switch_name  = @section_group.get_attribute(sname, "switch_name")
        @code = @dcode
        @thru_length  = @parms[@dcode][1]
        radius         = @parms[@dcode][0]
        @out_length   = radius * @parms[@dcode][3]  * Math::PI / 180.0
        @n_ties_arc   = @parms[@dcode][4]
    end

    def switch_index
        return @switch_index
    end

    def switch_name
        return @switch_name
    end

    def switch_name= (swnm)
        @switch_name = swnm
        @section_group.set_attribute("SectionAttributes", "switch_name", @switch_name)
        @outline_text_group.erase!
        @outline_text_group = outline_text_group_factory
    end

    def make_xform_alpha()
        alpha       = asin( @slope )
        p0          = Geom::Point3d.new  0, 0, 0
        ux          = Geom::Vector3d.new 1, 0, 0
        xform_alpha = Geom::Transformation.rotation p0, ux, alpha
        return xform_alpha
    end
    ###################################################################
    ####################################### build_sketchup_section
    def build_sketchup_section(target_point, section_index_g)
        if $repeat == -1
            okflg = false
            while !okflg
                okflg = true
                prompts = [$exStrings.GetString("Diameter"),
                           $exStrings.GetString("Direction"),
                           $exStrings.GetString("Slope"),
                           $exStrings.GetString("Connect With"),
                           $exStrings.GetString("Repeat")]
                values = [@@dcode,@@direc,0.00,"A",1]
                tlist  = ["O72|O60|O48|O36", "Left|Right", "","A|B|C",""]

                results = inputbox prompts, values, tlist, 
                           $exStrings.GetString("SwitchTrack Dimensions")
                if not results
                    $repeat = 1 # force loop in onMouseMove to quit
                    return false
                end

                @@dcode, @@direc, @@slope, @@tag_cnnct, $repeat = results
                if !target_point.check_slope(@@slope)
                    okflg  = false
                end
            end
        end
        timer = Timer.new("SwitchSection.build_sketchup_group, repeat = #{$repeat}")
        @dcode    = @@dcode
        @direc    = @@direc
        @slope    = @@slope
        @tag_cnnct= @@tag_cnnct
        @code     = @dcode

        radius          = @parms[@dcode][0]
        len_straight    = @parms[@dcode][1]
        n_ties_straight = @parms[@dcode][2]
        len_arc         = @parms[@dcode][3]
        @n_ties_arc      = @parms[@dcode][4]
        a               = @parms[@dcode][5]
        first_tie       = @parms[@dcode][6]

        arclen   = len_arc * Math::PI / 180.0
        delta    = arclen / @n_ties_arc
        dh_arc   = @slope * radius * arclen / @n_ties_arc
        dl_arc   = radius * sin(delta)
        vt_arc   = Geom::Vector3d.new 0,  0,  dh_arc
        uz       = Geom::Vector3d.new 0,  0,  1
        arc_origin = Geom::Point3d.new( -radius, a, a*@slope)
        if @direc == "Right"
            delta      = -delta
            arc_origin = Geom::Point3d.new(radius, a, a*@slope)
        end
        t1         = Geom::Transformation.rotation arc_origin, uz, delta
        tr_vt_arc  = Geom::Transformation.translation( vt_arc )
        @xform_bed_arc =  tr_vt_arc * t1

        if ( a != 0.0 ) 
            dh              = @slope * a
            dx              = 0
            dl              = a
            alpha           = asin( dh /dl )
            vt              = Geom::Vector3d.new 0,  dl, dh
            @xform_bed_alen = Geom::Transformation.translation( vt )
        else
            @xform_bed_alen = nil
        end

        dh           = @slope * len_straight
        dx           = 0
        dl           = len_straight
        alpha        = asin( dh /dl )
        vt           = Geom::Vector3d.new 0,  dl, dh
        @xform_bed   = Geom::Transformation.translation( vt )

        alpha        = asin( dh /dl )
        ux           = Geom::Vector3d.new 1, 0, 0
        p0           = Geom::Point3d.new  0,  0,  0
        @xform_alpha     = Geom::Transformation.rotation p0, ux, alpha
        @thru_length = @parms[@dcode][1]
        @out_length  = radius * @parms[@dcode][3] * Math::PI / 180.0

        sname = "SectionAttributes"
        @section_group.set_attribute(sname, "section_type",  "switch")
        @section_group.set_attribute(sname, "diameter_code", @dcode)
        @section_group.set_attribute(sname, "slope",         @slope)
        @section_group.set_attribute(sname, "direction",     @direc)
        @section_group.set_attribute(sname, "xform_bed",     @xform_bed.to_a)
        @section_group.set_attribute(sname, "xform_bed_arc", @xform_bed_arc.to_a)
        @switch_index = @@switch_count
        @section_group.set_attribute(sname, "switch_index",  @switch_index)
        @switch_name = sprintf("SW%03d", @switch_index)
        @section_group.set_attribute(sname, "switch_name",  @switch_name)
        @@switch_count += 1
        @@model.set_attribute("TrackAttributes", "switch_count", @@switch_count)
        @section_index_g = section_index_g
        @section_group.set_attribute(sname, "section_index_g",  @section_index_g)
        lpts = []
        np = @@bed_profile.length
        i = 0
        while i < np do
            lpts[i] = @@bed_profile[i].transform @xform_alpha
            i += 1
        end
    # Build straight section bed and ties
        body_group = @section_group.entities.add_group
        body_group.name = "track"
        body_group.layer= "track_sections"
        footprnt_group = @section_group.entities.add_group
        footprnt_group.name= "footprint"
        footprnt_group.layer= "footprint"

        pz = (target_point.position true).z
        p0 = Geom::Point3d.new(@@bed_profile[0].x, @@bed_profile[0].y, 0.0)
        p2 = Geom::Point3d.new(@@bed_profile[2].x, @@bed_profile[2].y, 0.0)
        ts = Geom::Transformation.translation([0.0, len_straight, dh])
        q0 = p0.transform ts
        q2 = p2.transform ts
        footprnt_group.entities.add_edges(p0, q0)
        footprnt_group.entities.add_edges(p2, q2)
        footprnt_group.entities.add_edges(q0, q2)
        p0 = p0 + [0.0, a, 0.0]
        p2 = p2 + [0.0, a, 0.0]
        n  = 0
        while n < @n_ties_arc
            q0 = p0.transform @xform_bed_arc
            q2 = p2.transform @xform_bed_arc
            footprnt_group.entities.add_edges(p0, q0)
            footprnt_group.entities.add_edges(p2, q2)
            p0 = q0
            p2 = q2
            n = n + 1
        end
        footprnt_group.entities.add_edges(q0, q2)
        
        cpts = []
        rpts = StraightSection.extend_profile(section_group, body_group,
                                              n_ties_straight,
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
                lpts[i] = @@rail_profile[i].transform @xform_alpha
                lpts[i] = lpts[i] + offset
                i += 1
            end
            StraightSection.extend_profile(section_group, body_group,
                                           n_ties_straight,
                                           lpts,
                                           @xform_bed,
                                           @@rail_mat, 
                                           false,
                                           cpts)
            nr += 1
        end

    # Build curved section bed and ties
        offset = Geom::Vector3d.new(0, a, a * @slope)
        kpts = []
        np = @@bed_profile.length
        i = 0
        while i < np do
            kpts[i] = @@bed_profile[i].transform @xform_alpha
            kpts[i] = kpts[i] + offset
            i += 1
        end
        rpts = CurvedSection.extend_profile(section_group, body_group,
                                            @n_ties_arc,
                                            kpts,
                                            @xform_bed_arc,
                                            @@bed_mat,
                                            true,
                                            cpts,
                                            first_tie)

     # add section rails
        nr = 0
        while nr < 3
            offset = Geom::Vector3d.new( (nr-1)*0.6875, 
                                        a, 
                                        @@bed_h + @@tie_h + a *  @slope)
            kpts = []
            np = @@rail_profile.length
            i = 0
            while i < np do
                kpts[i] = @@rail_profile[i].transform @xform_alpha
                kpts[i] = kpts[i] + offset
                i += 1
            end
            CurvedSection.extend_profile(section_group, body_group,
                                         @n_ties_arc,
                                         kpts,
                                         @xform_bed_arc,
                                         @@rail_mat, 
                                         false,
                                         cpts)
            nr += 1
        end

        self.connectors = cpts                                    
        section_point = connector(@tag_cnnct)
        tr_group = make_tr_group(target_point,section_point)
        @section_group.transformation = tr_group

        if @tag_cnnct == "A"
            connector("A").make_connection_link(target_point)
            $current_connection_point = connector("B")
        elsif @tag_cnnct =="B"
            connector("B").make_connection_link(target_point)
            $current_connection_point = connector("A")
        elsif @tag_cnnct == "C"
            connector("C").make_connection_link(target_point)
            $current_connection_point = connector("A")
        end
        make_slices
        @outline_group         = outline_group_factory
        @outline_text_group    = outline_text_group_factory
        $logfile.puts timer.elapsed
        return true
    end
    ############################################ end build_section

    def outline_group_factory
        timer = Timer.new("SwitchSection.outline_group_factory")
        outline_group = @section_group.entities.add_group
        material = Switches.switch_material
        style    = Switches.switch_style

        @n_ties_arc   = @parms[@dcode][4]
        a            = @parms[@dcode][5]

        outline_group.layer = "zones"
        outline_group.name  = "outline"
        outline_group.attribute_dictionary("OutlineAttributes", true)
        outline_group.set_attribute("OutlineAttributes", "section_guid", @section_group.guid)
        #outline_group.transformation= @section_group.transformation

        cpt = connector("A")
        face_pts = cpt.face_points
        ic     = face_pts[1]
        center = face_pts[0][ic]
        jpts   = {}
        lpts   = []
        rpts   = []
        j      = 0
        face_pts[0].each_with_index do |pt, i|
            if i != ic
                v = pt - center
                v.length = 1.0
                p    = []
                lpts[j] = pt + v
                j += 1
            end
        end
        np = j

        if style == "faces"
            lpts.each_with_index {|p,i| rpts[i] = p.transform @xform_bed}
            Section.add_faces(outline_group.entities, lpts, rpts, material)
        else
            np.times { |i|
                edges = outline_group.entities.add_edges(lpts[i-1],lpts[i])
            }
            lpts.each_with_index {|p,i| rpts[i] = p.transform @xform_bed}
            np.times { |i|
                edges = outline_group.entities.add_edges(rpts[i], lpts[i])
            }
            outline_group.entities.add_face(lpts[0], lpts[1], rpts[1], rpts[0])
            np.times { |i|
                edges = outline_group.entities.add_edges(rpts[i-1],rpts[i])
            }
        end

        offset = Geom::Vector3d.new(0.0, a, a * @slope)
        np.times { |i| lpts[i] = lpts[i] + offset }
        if style == "faces"
            @n_ties_arc.times { |n|
                lpts.each_with_index {|p,i| rpts[i] = p.transform @xform_bed}
                Section.add_faces(outline_group.entities, lpts, rpts, material)
                rpts.each_with_index {|p,i| lpts[i] = p }
            }
        else
            np.times { |i|
                edges = outline_group.entities.add_edges(lpts[i-1],lpts[i])
            }
            @n_ties_arc.times { |n|
                lpts.each_with_index {|p,i| rpts[i] = p.transform @xform_bed_arc}
                np.times { |i|
                    edges = outline_group.entities.add_edges(rpts[i], lpts[i])
                }
                outline_group.entities.add_face(lpts[0], lpts[1], rpts[1], rpts[0])
                rpts.each_with_index {|p,i| lpts[i] = p }
            }
            np.times { |i|
                edges = outline_group.entities.add_edges(rpts[i-1],rpts[i])
            }
        end
        $logfile.puts timer.elapsed
        return outline_group
    end

    def outline_text_group_factory
        outline_text_group = @section_group.entities.add_group
        outline_text_group.name = "outline_text"

        char_group = outline_text_group.entities.add_group
        char_group.entities.add_3d_text(@switch_name, TextAlignLeft, @@ofont, @@obold, false,
                                             @@otxt_h, 0.6, 0.0, @@ofill)
        bx = char_group.bounds
        bkgrnd_w = bx.width + 1.0
        bkgrnd_h = 1.25
        len_s    = @parms[@dcode][1]
        xmn      = -0.5 * bkgrnd_h 
        xmx      = +0.5 * bkgrnd_h 
        ymn      = 0.5 *len_s - 0.5 * bkgrnd_w
        ymx      = 0.5 *len_s + 0.5 * bkgrnd_w
        trkh     = @@bed_h + @@tie_h + 0.25
        bkz      = trkh + 0.01
        p0   = Geom::Point3d.new(xmn, ymn, bkz)
        p1   = Geom::Point3d.new(xmn, ymx, bkz)
        p2   = Geom::Point3d.new(xmx, ymx, bkz)
        p3   = Geom::Point3d.new(xmx, ymn, bkz)
        face = outline_text_group.entities.add_face(p0, p1, p2, p3)
        face.material = "white"
        face.back_material = "white"
        face.edges.each {|e| e.hidden=true}

        orgx  = 0.5 * bx.height
        orgy  = 0.5 * len_s - 0.5 * bx.width
        orgz  = trkh + 0.02
        vt    = Geom::Vector3d.new( orgx, orgy, orgz)
        q0    = Geom::Point3d.new(0.0, 0.0, 0.0)
        uz    = Geom::Vector3d.new(0.0, 0.0, 1.0)
        t1    = Geom::Transformation.rotation(q0, uz, 0.5 * Math::PI)
        xform = Geom::Transformation.translation( vt) * t1
        char_group.transform! xform
        char_entities = char_group.explode
        ux    = Geom::Vector3d.new(1.0, 0.0, 0.0)
        pt    = connector("C").position
        slope = pt.z / pt.y
        xform = Geom::Transformation.rotation(p0, ux, atan(slope) )
        outline_text_group.transform! xform
        return outline_text_group
    end

    ######################################################################
    ###################################### Report
    def report
        return [@section_type, @dcode, @direc]
    end

    #######################################################################
    #################################### Info
    def info(cpt0)
        sname = "SectionAttributes"
        lngth  = @parms[@dcode][1]
        tag    = cpt0.tag
        theta  = cpt0.theta(true)
        radius = @parms[@dcode][0]

        cpt1 = nil
        if tag == "B" 
            cpt1 = self.connector("A")
            cpt2 = self.connector("C")
            styp = "straight"
        elsif tag == "C"
            cpt1 = self.connector("A")
            cpt2 = self.connector("B")
            styp = "curve"
        else
            cpt1 = self.connector("C")
            cpt2 = self.connector("B")
            styp = "curve"
        end
        pa      = self.connector("A").position(true)
        theta   = self.connector("A").theta(true)
        pc      = self.connector("C").position(true)

        q = Geom::Point3d.new(999.0, 999.0, 0.0)
        if @direc == "Left"
            q.x= pa.x + radius * cos(theta - 0.5 * Math::PI)
            q.y= pa.y + radius * sin(theta - 0.5 * Math::PI)
        else
            q.x= pa.x + radius * cos(theta + 0.5 * Math::PI)
            q.y= pa.y + radius * sin(theta + 0.5 * Math::PI)
        end
        q.z= 0.0
        lentxt = sprintf("%s", lngth)
        info_text = "Switch (#{q.x.to_s}, #{q.y.to_s})"
        info_text = info_text + "\n" + @dcode+ " - " + lentxt+ " - "+@direc

        return ["switch", info_text, q, pa, pc]
    end

    def direction
        return @direc
    end

    def make_slices
        @section_group.entities.each do |e|
            if ( e.is_a? Sketchup::Group )
                if ( e.name == "slices" )
                    e.erase!
                end
            end
        end

        @shells = Hash.new
        make_out_slices
        make_thru_slices
    end
    
    def make_out_slices
        ###################################################### make slices_group for OUT
        slices_group = @section_group.entities.add_group
        slices_group.name = "slices"
        slices_group.hidden = true
        slices_group.set_attribute("SectionShellAttributes", "shell_type", "out")
        slices_group.set_attribute("SectionShellAttributes", "inline_length", @out_length)
        shell                 = SectionShell.new(slices_group, self)
        @shells[shell.guid]   = shell

        slice_index = 0
        lpts = []
        @@bed_profile.each_with_index{ |p,i| lpts[i] = p.transform @xform_alpha}

        if ( !@xform_bed_alen.nil? )
            f = slices_group.entities.add_face( lpts)
            f.set_attribute("SliceAttributes","slice_index", slice_index)
            slice_index += 1
        end

        n = 0
        while ( n < @n_ties_arc + 1)
            f = slices_group.entities.add_face( lpts)
            f.set_attribute("SliceAttributes","slice_index", slice_index)
            lpts.each_with_index{ |p,i| lpts[i] = p.transform @xform_bed_arc}
            slice_index += 1
            n += 1
        end

        slices_group.set_attribute("SectionShellAttributes", "slice_count", slice_index )
        slices_group.hidden = true
        return
    end
    ########################################################## make slices group for THRU
    def make_thru_slices
        last = true
        slices_group = @section_group.entities.add_group
        slices_group.name = "slices"
        slices_group.hidden = true
        slices_group.set_attribute("SectionShellAttributes", "shell_type", "thru")
        slices_group.set_attribute("SectionShellAttributes", "inline_length", @thru_length)
        shell                 = SectionShell.new(slices_group, self)
        @shells[shell.guid]   = shell

        lpts = []
        @@bed_profile.each_with_index{ |p,i| lpts[i] = p.transform @xform_alpha}

        nface = 1
        if last
            nface = 2
        end
        rpts = []
        n = 0
        while ( n < nface)
            f = slices_group.entities.add_face( lpts)
            f.set_attribute("SliceAttributes","slice_index", n)
            lpts.each_with_index{ |p,i| rpts[i] = p.transform @xform_bed}
            rpts.each_with_index{ |p,i| lpts[i] = p}
            n += 1
        end
        slices_group.set_attribute("SectionShellAttributes", "slice_count", n)
        slices_group.hidden = true
        return
    end
    def slices_tag(slices_type)
        str = "switch " + @switch_name + " " + slices_type
        return str
    end

    def export_ordered_slices(vtxfile, tag)
        vtxfile.puts sprintf("switch %-20s %-s\n", "switch_name", @switch_name)
        zone_name_A = connector("A").linked_connector.parent_section.zone.zone_name
        zone_name_B = connector("B").linked_connector.parent_section.zone.zone_name
        zone_name_C = connector("C").linked_connector.parent_section.zone.zone_name
        vtxfile.puts sprintf("switch %-20s %-s\n", "zone_name_A", zone_name_A)
        vtxfile.puts sprintf("switch %-20s %-s\n", "zone_name_B", zone_name_B)
        vtxfile.puts sprintf("switch %-20s %-s\n", "zone_name_C", zone_name_C)
        vtxfile.puts sprintf("switch %-20s %-d\n", "shell_count", @shells.size)
        vtxfile.puts sprintf("switch %-20s\n", "end")
            
        @shells.each_value do |s|
            s.write_ordered_slices(vtxfile, tag)
        end
    end
end


###########################################end Class SwitchSection
