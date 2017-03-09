
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

class CurvedSection < Section

    ##################################################################
    ############################################# initialize
    def initialize( section_group)
        @zone_guid = section_group.get_attribute("SectionAttributes", "zone_guid")
        @zone      = $zones.zone(@zone_guid)
        puts "CurvedsSection.initialize"
        @arcO72      = Hash.new
        @arcO72["Full"]    = [22.50, 34]
        @arcO72["Half"]    = [11.25, 20]
        @arcO60      = Hash.new
        @arcO60["Full"]    = [22.50, 28]
        @arcO48      = Hash.new
        @arcO48["Full"]    = [30.00, 31]
        @arcO48["Half"]    = [15.00, 15]
        @arcO48["Quarter"] = [ 7.50, 8]
        @arcO36      = Hash.new
        @arcO36["Full"]    = [45.00, 36]
        @arcO36["Half"]    = [22.50, 18]
        @arcO36["Quarter"] = [11.25, 9]
        @parms = Hash.new
        @parms["O72"] = [36.0, @arcO72, "Full|Half" ]
        @parms["O60"] = [30.0, @arcO60, "Full|" ]
        @parms["O48"] = [24.0, @arcO48, "Full|Half|Quarter" ]
        @parms["O36"] = [18.0, @arcO36, "Full|Half|Quarter" ]
        #puts "CurvedSection.initialize @parms #{@parms.inspect}"
        super(section_group)
    end

    def zone
        return @zone
    end
    def inline_length
        return @inline_length
    end
    ######################################### end of initialize
    ###################################################################
    ####################################### load_sketchup_group
    def load_sketchup_group
        sname = "SectionAttributes"
        @entry_tag       = @section_group.get_attribute(sname, "entry_tag")
        @section_index_z = @section_group.get_attribute(sname, "section_index_z")
        @dcode           = @section_group.get_attribute(sname, "diameter_code")
        @arctyp          = @section_group.get_attribute(sname, "arc_type")
        phash = @parms[@dcode][1]
        pb = phash[@arctyp]

        @n_section_ties = pb[1]
        @direc      = @section_group.get_attribute(sname, "direction")
        @slope      = @section_group.get_attribute(sname, "slope")
        xform_bed_a = @section_group.get_attribute(sname, "xform_bed")
        @xform_bed  = Geom::Transformation.new(xform_bed_a)
        xform_alpha_a = @section_group.get_attribute(sname, "xform_alpha")
        if xform_alpha_a.nil?        # this code is kludge while we add slices_group
            radius         = (@parms[@dcode])[0]
            arclen         = pb[0] * Math::PI / 180.0
            @xform_alpha = make_xform_alpha(radius, arclen)
            @section_group.set_attribute(sname, "xform_alpha",     @xform_alpha.to_a)
        else
            @xform_alpha  = Geom::Transformation.new(xform_bed_a)
        end
        radius         = (@parms[@dcode])[0]
        @inline_length = radius * pb[0] * Math::PI / 180.0


        arclen_s = sprintf("  %5.2f", pb[0])
        @code = @dcode + arclen_s
    end

    def make_xform_alpha(radius, arclen)
        delta       = arclen / @n_section_ties
        dh          = @slope * radius * arclen / @n_section_ties
        dl          = radius * sin(delta)
        alpha       = asin( dh /dl )
        p0          = Geom::Point3d.new  0, 0, 0
        ux          = Geom::Vector3d.new 1, 0, 0
        xform_alpha = Geom::Transformation.rotation p0, ux, alpha
        return xform_alpha
    end

    ####################################### build_sketchup_section
    def build_sketchup_section(target_point, section_index_g)
        if $repeat == -1
            okflg = false
            arclst = "Full|Half|Quarter"
            while !okflg
                okflg = true
                prompts = [$exStrings.GetString("Diameter"),
                           $exStrings.GetString("Arc"), 
                           $exStrings.GetString("Direction"),
                           $exStrings.GetString("Slope"),
                           $exStrings.GetString("Connect With"),
                           $exStrings.GetString("Repeat")]
                values = [@@dcode,@@arctyp,@@direc,@@slope,"A",1]

                tlist  = ["O72|O60|O48|O36", 
                          arclst,
                          "Left|Right", 
                          "",
                          "A|B",
                          ""]

                results = inputbox prompts, values, tlist, 
                          $exStrings.GetString("CurvedTrack Dimensions")
                if not results
                    $repeat = 1  # force loop in onMouseMove to quit
                    return false
                end

                @@dcode,@@arctyp,@@direc,@@slope,@@tag_cnnct,
                            $repeat =results
                phash = @parms[@@dcode][1]
                if phash[@@arctyp].nil?
                    arclst = @parms[@@dcode][2]
                    okflg = false
                end
                if !target_point.check_slope(@@slope)
                    okflg = false
                end
            end
        end
        $logfile.puts "CurvedSection.build_sketchup_group, repeat = #{$repeat}"
        timer = Timer.new("CurvedSection.build_sketchup_group")
        @dcode    = @@dcode
        @arctyp   = @@arctyp
        @direc    = @@direc
        @slope    = @@slope
        @tag_cnnct= @@tag_cnnct
        radius         = (@parms[@dcode])[0]
        phash = @parms[@dcode][1]
        pb = phash[@arctyp]
        len_arc = pb[0]
        @n_section_ties = pb[1]
        arclen = len_arc * Math::PI / 180.0
        @inline_length =  radius * arclen
        
        delta    = arclen / @n_section_ties
        dh       = @slope * radius * arclen / @n_section_ties
        dl       = radius * sin(delta)
        alpha    = asin( dh /dl )
        vt       = Geom::Vector3d.new 0,  0,  dh
        p0       = Geom::Point3d.new  0,  0,  0
        uz       = Geom::Vector3d.new 0,  0,  1
        arc_origin = Geom::Point3d.new -radius, 0, 0
        if @direc == "Right"
            delta      = -delta
            arc_origin = Geom::Point3d.new radius, 0, 0
        end
        t1        = Geom::Transformation.rotation arc_origin, uz, delta
        tr_vt     = Geom::Transformation.translation( vt )
        @xform_bed = tr_vt * t1

        ux       = Geom::Vector3d.new 1, 0, 0
        @xform_alpha = Geom::Transformation.rotation p0, ux, alpha

        @entry_tag         = "A"
        @section_index_z   = 999
        sname = "SectionAttributes"
        @section_group.set_attribute(sname, "section_type",  @section_type)
        @section_group.set_attribute(sname, "diameter_code", @dcode)
        @section_group.set_attribute(sname, "arc_type",      @arctyp)
        @section_group.set_attribute(sname, "direction",     @direc)
        @section_group.set_attribute(sname, "slope",         @slope)
        @section_group.set_attribute(sname, "xform_bed",     @xform_bed.to_a)
        @section_group.set_attribute(sname, "xform_alpha",   @xform_alpha.to_a)
        @section_index_g = section_index_g
        @section_group.set_attribute(sname, "section_index_g", @section_index_g)
        @section_group.set_attribute(sname, "section_index_z", @section_index_z)
        @section_group.set_attribute(sname, "entry_tag",       @entry_tag)

        lpts = []
        np = @@bed_profile.length
        i = 0
        while i < np do
            lpts[i] = @@bed_profile[i].transform @xform_alpha
            i += 1
        end


        body_group = @section_group.entities.add_group
        body_group.name= "track"
        body_group.layer= "track_sections"
        footprnt_group = @section_group.entities.add_group
        footprnt_group.name= "footprint"
        footprnt_group.layer= "footprint"

        pz = (target_point.position true).z
        p0 = Geom::Point3d.new(@@bed_profile[0].x, @@bed_profile[0].y, 0.0)
        p2 = Geom::Point3d.new(@@bed_profile[2].x, @@bed_profile[2].y, 0.0)
        n  = 0
        q0 = Geom::Point3d.new
        q2 = Geom::Point3d.new
        while n < @n_section_ties
            q0 = p0.transform @xform_bed
            q2 = p2.transform @xform_bed
            footprnt_group.entities.add_edges(p0, q0)
            footprnt_group.entities.add_edges(p2, q2)
            p0 = q0
            p2 = q2
            n = n + 1
        end
        footprnt_group.entities.add_edges(q0, q2)

        cpts = []
        rpts = CurvedSection.extend_profile(section_group, 
                                            body_group,
                                            @n_section_ties,
                                            lpts,
                                            @xform_bed,
                                            @@bed_mat,
                                            true,
                                            cpts)

     # add section rails
        nr = 0
        while nr < 3
            offset = Geom::Vector3d.new( (nr-1)*0.6875, 
                                        0, 
                                        @@bed_h + @@tie_h)
            lpts = []
            np = @@rail_profile.length
            i = 0
            while i < np do
                lpts[i] = @@rail_profile[i].transform @xform_alpha
                lpts[i] = lpts[i] + offset
                i += 1
            end
            CurvedSection.extend_profile(section_group, 
                                         body_group,
                                         @n_section_ties,
                                         lpts,
                                         @xform_bed,
                                         @@rail_mat, 
                                         false,
                                         cpts)
            nr += 1
        end
        self.connectors = cpts                       
        section_point = connector(@tag_cnnct)
        tr_group = make_tr_group(target_point, section_point)
        @section_group.transformation = tr_group
        if @tag_cnnct == "A"
            connector("A").make_connection_link(target_point)
            $current_connection_point = connector("B")
        else
            connector("B").make_connection_link(target_point)
            $current_connection_point = connector("A")
        end

        make_slices
        
        @outline_group           = outline_group_factory
        @outline_text_group      = outline_text_group_factory
        $logfile.puts timer.elapsed
        return true
    end

    ########################################## end build_sketchup_section
    
    def make_curved_transformation(direc, radius, delta, dh)
        p0 = Geom::Point3d.new(0.0, 0.0, 0.0)
        uz = Geom::Vector3d.new(0.0, 0.0, 1.0)
        vt = Geom::Vector3d.new(0.0, 0.0, dh)

        xform = nil
        if direc == "Left"
            arc_origin = Geom::Point3d.new(-radius, 0.0, 0.0)
            xform      = Geom::Transformation.rotation(arc_origin, uz, delta)
        else
            arc_origin = Geom::Point3d.new( radius, 0.0, 0.0)
            xform      = Geom::Transformation.rotation(arc_origin, uz, -delta)
        end
        xform = Geom::Transformation.translation(vt) * xform
        return xform
    end

    ######################################################################
    ##################################### outline_group_factory

    def outline_group_factory
        outline_group = @section_group.entities.add_group
        outline_group.attribute_dictionary("OutlineAttributes", true)
        outline_group.set_attribute("OutlineAttributes", "section_index_g", @section_index_g)
        outline_group.layer    = "zones"
        outline_group.name     = "outline"
        outline_group.material = Zone.material
        timer          = Timer.new("CurvedSection.build_outline_group")
        style          = Zone.style
        phash          = @parms[@dcode][1]
        pb             = phash[@arctyp]
        radius         = @parms[@dcode][0]
        n_section_ties = pb[1]
        arclen         = pb[0] * Math::PI / 180.0

        slope = @slope
        direc = @direc
        delta = arclen / n_section_ties
        dh             = slope * radius * delta
        dl             = radius * sin(delta)
        xform_b = make_curved_transformation(direc, radius, delta, dh)
        ux      = Geom::Vector3d.new(1.0, 0.0, 0.0)
        p0      = Geom::Point3d.new(0.0, 0.0, 0.0)
        alpha   = asin(dh / dl)
        xform_alpha = Geom::Transformation.rotation(p0, ux, alpha)
        face_pts = []
        @@bed_profile.each_with_index {|p,i| face_pts[i] = p.transform(xform_alpha)}
        ic     = 1
        face_pts.each.with_index {|p,i| $logfile.puts "build_outline_group  #{i} #{p.to_s}" }
        center = face_pts[ic]
        lpts   = []
        rpts   = []
        j      = 0
        face_pts.each_with_index do |pt, i|
            if i != ic
                v = pt - center
                v.length = 1.0
                lpts[j] = pt + v
                j += 1
            end
        end
        np  = j
        if style == "faces"
            n_section_ties.times { |n|
                lpts.each_with_index {|p,i| rpts[i] = p.transform xform_b}
                Section.add_faces(outline_group.entities, lpts, rpts, material)
                rpts.each_with_index {|p,i| lpts[i] = p }
            }
        else
            np.times { |i|
                edges = outline_group.entities.add_edges(lpts[i-1],lpts[i])
            }
            n_section_ties.times { |n|
                lpts.each_with_index {|p,i| rpts[i] = p.transform xform_b}
                np.times { |i|
                    edges = outline_group.entities.add_edges(rpts[i], lpts[i])
                }
                outline_group.entities.add_face(lpts[0],lpts[1],rpts[1])
                outline_group.entities.add_face(lpts[0],rpts[1],rpts[0])
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

        radius  = @parms[@dcode][0]
        phash   = @parms[@dcode][1]
        pb      = phash[@arctyp]

        arclen = pb[0] * Math::PI / 180.0
        pt    = connector("B").position
        slope = pt.z / pt.y
        direc  = @direc
        p0    = Geom::Point3d.new(0.0, 0.0, 0.0)
        ux    = Geom::Vector3d.new(1.0, 0.0, 0.0)
        xform_alpha = Geom::Transformation.rotation(p0, ux, atan(slope) )
        rp     = radius + 0.625             #inside radius of background disk
        rm     = radius - 0.625             #outside radius of background disk
        ri     = radius - 0.5 * @@otxt_h     #radius of baske of characters
        nc     = @zone.zone_name.length
        trk_h  = @@bed_h + @@tie_h + 0.25

        ############# make the background disc
        beta_c = 0.5 * arclen
        delta  = @@otxt_w / ri                # delta beta for each character
        arc_w  = 0.5 * @@otxt_w / rm + nc * delta + 0.5 * @@otxt_w / rm
        beta_a = beta_c - 0.5 * arc_w
        beta_b = beta_c + 0.5 * arc_w
        pts    = []
        dela   = (beta_b - beta_a)/ 10.0
        bkz    = trk_h + 0.02
        11.times do |j|
            beta = beta_a + j * dela
            y  = rm * sin(beta)
            if direc == "Left"
                x = rm * cos(beta) - radius
            else
                x = radius - rm * cos(beta)
            end
            pts [j] = Geom::Point3d.new(x, y, bkz)
        end
        11.times do |j|
            beta = beta_a + j * dela
            y  = rp * sin(beta)
            if direc == "Left"
                x = rp * cos(beta) - radius
            else
                x = radius - rp * cos(beta)
            end
            pts [20-j] = Geom::Point3d.new(x, y, bkz)
        end
        face = outline_text_group.entities.add_face(pts)
        face.material = "white"
        face.back_material = "white"
        face.edges.each { |e| e.hidden=true}

        #make the zone name characters one at a time
        uz      = Geom::Vector3d.new(0.0, 0.0, 1.0)
        t1      = Geom::Transformation.rotation( p0, uz, 0.5 * Math::PI)
        vt      = Geom::Vector3d.new( 0.5 * @@otxt_h, 0.0, trk_h + 0.03)
        xform0  = Geom::Transformation.translation(vt) * t1

        beta = beta_a + 0.5 * delta
        @zone.zone_name.each_char do |c|
            char_group = outline_text_group.entities.add_group
            char_group.entities.add_3d_text(c, TextAlignLeft, @@ofont, @@obold, false,
                                                    @@otxt_h, 0.6, 0.0, @@ofill)
            if direc == "Left"
                arc_origin = Geom::Point3d.new(-radius, 0.0, 0.0)
                xform = Geom::Transformation.rotation(arc_origin, uz, beta) * xform0
            else
                arc_origin = Geom::Point3d.new( radius, 0.0, 0.0)
                xform = Geom::Transformation.rotation(arc_origin, uz,-beta) * xform0
            end
            char_group.transform! xform
            char_entities = char_group.explode
            beta = beta + delta
        end
        outline_text_group.transform! xform_alpha
        return outline_text_group
    end

    ######################################################################
    ###################################### Report
    def report
        sname        = "SectionAttributes"
        dcode        = @section_group.get_attribute(sname, "diameter_code")
        arctyp       = @section_group.get_attribute(sname, "arc_type")
        section_type = @section_group.get_attribute(sname, "section_type")
        return [section_type, dcode, arctyp]
    end

    #######################################################################
    #################################### Info
    def info(cpt0)
        sname = "SectionAttributes"
        dcode  = @section_group.get_attribute(sname, "diameter_code")
        arctyp = @section_group.get_attribute(sname, "arc_type")
        direc  = @section_group.get_attribute(sname, "direction")
        tag    = cpt0.tag
        radius = @parms[dcode][0]

        cpt1 = nil
        if tag == "B"
            cpt1 = self.connector("A")
        else
            cpt1 = self.connector("B")
        end
        
        pa      = self.connector("A").position(true)
        theta   = self.connector("A").theta(true)
        pb      = self.connector("B").position(true)


        q = Geom::Point3d.new
        if direc == "Left"
            q.x= pa.x + radius * cos(theta - 0.5 * Math::PI)
            q.y= pa.y + radius * sin(theta - 0.5 * Math::PI)
        else
            q.x= pa.x + radius * cos(theta + 0.5 * Math::PI)
            q.y= pa.y + radius * sin(theta + 0.5 * Math::PI)
        end
        q.z= 0.0
        info_text = "Curved (#{q.x.to_s}, #{q.y.to_s})"
        info_text = info_text + "\n" + @dcode + " - " + @arctyp

        return ["curved", info_text, q, pa, pb]
    end
                
    def tag
        return sprintf("%s-S%04d", @zone.zone_name, @zone.zone_index)
    end

    ####################################################################
    ################################# CurvedSection.extend_profile
    def CurvedSection.extend_profile(section_group, 
                                     body_group,
                                     n_section_ties,
                                     lpts,
                                     xform_bed,
                                     face_mat,
                                     tie_flg,
                                     cpts,
                                     first_tie = 0)

        #puts "Extend n_section_ties #{n_section_ties}"
        timer = Timer.new("Extend")
        face_A = body_group.entities.add_face(lpts)
        np = lpts.length
        rpts = []
        n = 0 
        while ( n < n_section_ties)
            nr   = 0
            lpts.each do |x|
                rpts[nr] = x.transform xform_bed
                nr += 1
            end
            Section.add_faces(body_group.entities, lpts, rpts, face_mat)
            if ( tie_flg && n >= first_tie ) then
                bpts =   [ lpts[np-1], lpts[np-2], rpts[np-2], rpts[np-1] ]
                Section.make_tie( body_group.entities, bpts)
            end

            i = 0
            while ( i < nr)
                lpts[i] = rpts[i]
                i += 1
            end
            n += 1
            #puts " n #{n} #{timer.elapsed}"
        end
        face_B = body_group.entities.add_face(rpts)
        if tie_flg
            if first_tie == 0    # normal CursvedSection
                nc = cpts.length
                cpts[nc] = Connector.factory(section_group, "A", face_A)
                nc = cpts.length
                cpts[nc] = Connector.factory(section_group, "B", face_B)
            else                 # called from SwitchSection
                nc = cpts.length
                cpts[nc] = Connector.factory(section_group, "C", face_B)
            end
        end

        #puts timer.elapsed
        return rpts
    end
    ########################### end of CurvedSection.extend_profile

    def make_slices
        @section_group.entities.each do |e|
            if ( e.is_a? Sketchup::Group )
                if ( e.name == "slices" )
                    e.erase!
                end
            end
        end
        @shells           = Hash.new

        last              = true
        slices_group      = @section_group.entities.add_group
        slices_group.name = "slices"
        slices_group.hidden = true
        slices_group.attribute_dictionary("SectionShellAttributes", true)
        slices_group.set_attribute("SectionShellAttributes", "shell_type"   , "notype")
        puts @inline_length
        slices_group.set_attribute("SectionShellAttributes", "inline_length", @inline_length)

        shell = SectionShell.new(slices_group, self)
        @shells[shell.guid] = shell

        lpts = []
        @@bed_profile.each_with_index{ |p,i| lpts[i] = p.transform @xform_alpha}


        rpts = []
        n = 0
        while ( n < @n_section_ties )
            f = slices_group.entities.add_face( lpts)
            f.set_attribute("SliceAttributes","slice_index", n)
            lpts.each_with_index{ |p,i| rpts[i] = p.transform @xform_bed}
            rpts.each_with_index{ |p,i| lpts[i] = p}
            n += 1
        end

        if ( last )
            f =slices_group.entities.add_face( lpts)
            f.set_attribute("SliceAttributes", "slice_index", n)
        end
        slices_group.set_attribute("SectionShellAttributes", "slice_count", n+1 )
        return slices_group
    end

    def export_ordered_slices(vtxfile, tag)
        vtxfile.puts sprintf("section %-20s %d\n",    "section_index_z", @section_index_z)
        vtxfile.puts sprintf("section %-20s %d\n",    "shell_count",     @shells.size)
        vtxfile.puts sprintf("section %-20s\n",    "end")
        @shells.each_value do |s|
            s.write_ordered_slices(vtxfile, tag)
        end
    end

    def entry_tag
        return @entry_tag
    end
    def entry_tag=(etg)
        @entry_tag = entry_tag
        @section_group.set_attribute("SectionAttributes", "entry_tag", @entry_tag)
    end
    def exit_tag
        exttg = "B"
        if ( @entry_tag != "A" )
            exttg = "A"
        end
        return exttg
    end

    def section_index_g
        return @section_index_g
    end

    def section_index_z
        return @section_index_z
    end

    def update_ordered_attributes(section_index_z, entry_tag)
        @section_index_z = section_index_z
        @entry_tag       = entry_tag
        @section_group.set_attribute("SectionAttributes", "section_index_z", @section_index_z)
        @section_group.set_attribute("SectionAttributes", "entry_tag", @entry_tag)
    end

end  #### End of Class CurvedSection
