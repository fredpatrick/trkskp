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

require 'Sketchup.rb'
require 'langhandler.rb'

include Math

class Riser

    def Riser.init_class_variables
        model = Sketchup.active_model
        aname = "TrackAttributes"
        
        @@base_h      =model.get_attribute(aname,"base_h")
        @@base_w      =model.get_attribute(aname,"base_w")
        @@base_d      =model.get_attribute(aname,"base_d")

        @@base_pts = []
        @@base_pts[0] = Geom::Point3d.new  -@@base_w / 2, -@@base_d / 2, 0
        @@base_pts[1] = Geom::Point3d.new  -@@base_w / 2,  @@base_d / 2, 0
        @@base_pts[2] = Geom::Point3d.new   @@base_w / 2,  @@base_d / 2, 0
        @@base_pts[3] = Geom::Point3d.new   @@base_w / 2, -@@base_d / 2, 0

        @@base_mat   = "black"
        @@column_mat = "saddlebrown"

        @@track_risers = Hash.new
    end

    def Riser.load_risers(section_group)
        section_group.entities.each do |e|
            if e.is_a? Sketchup::Group
                 if e.name == "riser"                         
                    Riser.factory(e)
                end
            end
        end
    end

    def Riser.factory(arg_group, connection_pt = nil, slope = nil)
        $logfile.puts "Riser.factory begin"
        TrackTools.model_summary
        riser__group = nil
        if arg_group.name == "section"
            world_pt  = connection_pt.position(true)
            height    = world_pt.z
            if height <= 0.0 
                return
            end
            riser_group = arg_group.entities.add_group
            riser_group.layer= "structure"
        else
            riser_group = arg_group
        end
            
        riser = Riser.new(riser_group, connection_pt, slope)
        riser_id = riser.riser_id
        @@track_risers[riser_id] = riser
        TrackTools.model_summary
        $logfile.puts "Riser.factory end"
    end

    def Riser.riser(guid)
        return @@track_risers[guid]
    end

    def Riser.risers
        return @@track_risers.values
    end

    def initialize (riser_group, connection_pt=nil, slope=nil)
        @riser_group = riser_group 
        rname = "RiserAttributes"
        rattrs = @riser_group.attribute_dictionary(rname)
        if rattrs
            @cid    = @riser_group.get_attribute(rname, "connection_id")
            @height = @riser_group.get_attribute(rname, "height")
            @slope  = @riser_group.get_attribute(rname, "slope")
            puts @cid
            cpt = Connector.connector(@cid)
            cpt.riser_id = @riser_group.guid
        else
            riser_group.name = "riser"
            world_pt  = connection_pt.position(true)
            @height    = world_pt.z
            @slope     = slope
            rattrs = @riser_group.attribute_dictionary(rname, true)
            @cid = connection_pt.guid
            @riser_group.set_attribute(rname,"connection_id", @cid)
            @riser_group.set_attribute(rname, "height", @height)
            @riser_group.set_attribute(rname, "slope", @slope)
            create_riser(@riser_group, connection_pt, @slope)
            connection_pt.riser_id= @riser_group.guid
        end
    end

    def riser_id
        return @riser_group.guid
    end

    def connection_pt_id
        return @cid
    end

    def height
        return @height
    end

    def slope
        return @slope
    end

    def create_riser riser_group, connection_pt, slope
        $logfile.puts "riser.create_riser begin"
        TrackTools.model_summary
        target_pt = connection_pt.position
        theta     = connection_pt.theta

        tr      = Geom::Transformation.rotation( target_pt, 
                                                 [0, 0, 1],
                                                 theta - 0.5 * Math::PI )

        riser_pt = Geom::Point3d.new(target_pt.x, 
                                     target_pt.y, 
                                     target_pt.z - @height)
        if @height > 2 * @@base_h
            $logfile.puts "riser.create_riser @height = #{@height}"
            TrackTools.model_summary
            top_group = riser_group.entities.add_group
            delta = slope * @@base_d / 2
            make_riser_block( top_group, @@base_h, delta)
            $logfile.puts "riser.create_riser make_riser_block"
            TrackTools.model_summary
            p = riser_pt + [0, 0, @height - @@base_h]
            tt = tr * Geom::Transformation.new( p )
            top_group = top_group.transform! tt

            base_group = riser_group.entities.add_group
            make_riser_block( base_group, @@base_h, 0)
            $logfile.puts "riser.create_riser make_riser_block"
            TrackTools.model_summary
            tt = tr * Geom::Transformation.new( riser_pt )
            base_group = base_group.transform! tt

            column_group = riser_group.entities.add_group
            make_columns( column_group, @height)
            $logfile.puts "riser.create_riser make_columns"
            TrackTools.model_summary
            p = riser_pt + [0, 0, @@base_h]
            tt = tr * Geom::Transformation.new( p )
            column_group = column_group.transform! tt
        else
            top_group = riser_group.entities.add_group
            delta = slope * @@base_d / 2
            make_riser_block( top_group, @height, delta)
            tt = tr * Geom::Transformation.new( riser_pt )
            top_group = top_group.transform! tt

        end
        TrackTools.model_summary
        $logfile.puts "riser.create_riser end"
    end

    def make_riser_block( blk_group, blk_height, delta)
        entities = blk_group.entities
        entities.add_face( @@base_pts )
        tpts = []
        tpts[0] = @@base_pts[0] + [ 0, 0, blk_height - delta]
        tpts[1] = @@base_pts[1] + [ 0, 0, blk_height + delta]
        tpts[2] = @@base_pts[2] + [ 0, 0, blk_height + delta]
        tpts[3] = @@base_pts[3] + [ 0, 0, blk_height - delta]
        f = entities.add_face( tpts )
        f.material = @@base_mat
        f = entities.add_face(@@base_pts[0],@@base_pts[1], tpts[1], tpts[0])
        f.material = @@base_mat
        f = entities.add_face(@@base_pts[1],@@base_pts[2], tpts[2], tpts[1])
        f.material = @@base_mat
        f = entities.add_face(@@base_pts[2],@@base_pts[3], tpts[3], tpts[2])
        f.material = @@base_mat
        f = entities.add_face(@@base_pts[3],@@base_pts[0], tpts[0], tpts[3])
        f.material = @@base_mat

        return blk_group
    end

    def footprint ( target_pt, theta )
        puts "footprint", target_pt, theta.radians
        p0      = target_pt
        uz      = Geom::Vector3d.new 0, 0, 1
        tr      = Geom::Transformation.rotation p0, uz, theta
        vt      = Geom::Vector3d.new target_pt.x, target_pt.y, target_pt.z
        tt      = tr * Geom::Transformation.translation( vt )

        a       = []
        n = 0
        while n < 4
            a[n] = @@base_pts[n].transform tt
            n += 1
        end
        a[4] = a[0]
        return a
    end

    def make_columns( column_group, height)
        $logfile.puts "riser.make_columns begin"
        TrackTools.model_summary
        circle_edges = column_group.entities.add_circle( 
                                    [-0.5 * @@base_w + 0.75, 0, 0],
                                    [0, 0, 1],
                                     0.25,
                                     8 )
        $logfile.puts "riser.make_columns add_circle"
        TrackTools.model_summary
        face = column_group.entities.add_face( circle_edges )
        $logfile.puts "riser.make_columns add_face"
        TrackTools.model_summary
        face.material = @@column_mat
        face.back_material = @@column_mat
        face.pushpull( -height + 2 * @@base_h)
        $logfile.puts "riser.make_columns face.pushpull 1"
        TrackTools.model_summary
        circle_edges = column_group.entities.add_circle( 
                                    [ 0.5 * @@base_w - 0.75, 0, 0],
                                    [0, 0, 1],
                                     0.25,
                                     24 )
        face = column_group.entities.add_face( circle_edges )
        face.material = @@column_mat
        face.back_material = @@column_mat
        face.pushpull( -height + 2 * @@base_h)
        $logfile.puts "riser.make_columns face.pushpull 2"
        TrackTools.model_summary
    end

    def to_s
        "Riser: height = #{@height}, slope = #{@slope}"
                #"\n       riser_id = #{@riser_group.guid}" +
                #"\n       cid      = #{@cid}"
    end

end   # end of class Riser
