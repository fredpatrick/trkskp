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

$trkdir = "/Users/fredpatrick/wrk/trkskp"
require "#{$trkdir}/riserbase.rb"
require "#{$trkdir}/risercolumn.rb"
require "#{$trkdir}/risertext.rb"

include Math
include Trk

class Riser
    def initialize(riser_group, riser_index=nil,
                   base=nil, basedata=nil, riser_defs=nil,
                   stop_after_build="No")
        @riser_group   = riser_group
        @guid          = riser_group.guid
        @riserconnector   = []
        @top_riserbase    = Hash.new
        @bottom_riserbase = Hash.new
        @risercolumn      = Hash.new
        if riser_index.nil?
            load_riser
            return
        end
        @riser_index   = riser_index
        @base               = base
        @basedata           = basedata
        @bottom_base_offset = 0.0
        @riser_group.set_attribute("RiserAttributes", "riser_index",        @riser_index)
        @riser_group.set_attribute("RiserAttributes", "base_guid",          @base.guid)
        @riser_group.set_attribute("RiserAttributes", "basedata",           @basedata.to_a)
        @riser_group.set_attribute("RiserAttributes", "secondary_count",    0)

        @basedata        = basedata
        target_point     = basedata["attach_point"]
        target_crossline = basedata["attach_crossline"]
        zt               = @basedata["attach_point"].z
        source_point     = Geom::Point3d.new(0.0, 0.0, zt)
        source_crossline = Geom::Vector3d.new(0.0, 1.0, 0.0)
        cos              = source_crossline.dot(target_crossline)
        sin              = source_crossline.cross(target_crossline).z
        rotation_angle   = Math.atan2(sin,cos)
        shift            = target_point - source_point
        xform_rotate     = Geom::Transformation.rotation(Geom::Point3d.new(0.0, 0.0, 0.0),
                                                         Geom::Vector3d.new(0.0, 0.0, 1.0), 
                                                         rotation_angle)
        xform_translation = Geom::Transformation.translation(shift)
        riser_xform       = xform_translation * xform_rotate
        @riser_group.transformation = riser_xform

        rc_index = 0
        @rcp_def           = riser_defs["risercraddle_p"]
        rc_type = @rcp_def.get_attribute("TrkDefinitionAttrs", "definition_type")
        #if rc_type == "risercraddle"
        @riserconnector[0] = RiserCraddle.new(@rcp_def,       rc_index, 
                                                  @riser_group, @riser_index, @basedata)
        #elsif rc_type == "risertab"
        #    @riserconnector[0] = RiserTab.new(@rc_def,       rc_index,
        #                                      @riser_group, @riser_index, @basedata)
        #end

        @slope = @riserconnector[0].slope
        @riser_group.set_attribute("RiserAttributes", "slope", @slope)
        attach_count = @riserconnector[0].attach_count
        attach_count.times do |n|
            side             = @riserconnector[0].attach_side(n)
            puts "####################Begin #{side} of Riser ###########################"
            attach_point  = @riserconnector[0].attach_point(n)
            attach_crossline = @riserconnector[0].attach_crossline(n)
            structure_p  = attach_point.transform(riser_xform)
            structure_h  = Trk.find_structure_top(structure_p)
            @bottom_base_offset = structure_h if structure_h > @bottom_base_offset
            puts "riser.initialize, ******************************riser_index = #{@riser_index}"
            puts "riser.initialize, ******************************side = #{side}"
            puts "riser.initialize, ******************************structure_p = #{structure_p}"
            puts "riser.initialize, ******************************structure_h = #{structure_h}"
            @top_riserbase[side]    = RiserBase.new(self, riser_defs["riserbase_t"], "top", 
                                              attach_point, structure_h,attach_crossline, side)
            @bottom_riserbase[side] = RiserBase.new(self, riser_defs["riserbase_b"], "bottom", 
                                              attach_point, structure_h,attach_crossline, side)

            #puts @top_riserbase[side].to_s
            #puts @bottom_riserbase[side].to_s

            @risercolumn[side] = RiserColumn.new(self, @riserconnector[0], side,
                                       @bottom_riserbase[side], @top_riserbase[side])
            puts "riser.initialization, riser built, side = #{side}"
            puts @risercolumn[side]
            outside_face = @risercolumn[side].outside_face
            if outside_face.nil?
                puts "riser.initialze, outside_face is nil, side = #{side}"
            end
            risertext = RiserText.new(@risercolumn[side].group, 1.0, @riser_index, side)
            @risercolumn[side].set_risertext(outside_face, side, risertext)
            print_riser_centerline(side)
            @riserconnector[0].set_risertext(self, side)
        end
        @riser_group.set_attribute("RiserAttributes", "bottom_base_offset", @bottom_base_offset)

        @base.register_riser(self)
        if stop_after_build == "Yes"
            return
        end    
    end

    def erase
        puts "riser.erase, riser_index = #{@riser_index}"
        @base.unregister_riser(self)
        @riser_group.erase!
        @riser_group = nil
    end

    def load_riser
        @riser_index        = @riser_group.get_attribute("RiserAttributes", "riser_index")
        @base_guid          = @riser_group.get_attribute("RiserAttributes", "base_guid")
        @base               = Base.base(@base_guid)
        @base.register_riser(self)
        basedata_a          = @riser_group.get_attribute("RiserAttributes", "basedata")
        @basedata = Hash.new
        basedata_a.each { |key,value| @basedata[key] = value}
        @bottom_base_offset = @riser_group.get_attribute("RiserAttributes", 
                                                         "bottom_base_offset")
        @slope              = @riser_group.get_attribute("RiserAttributes", "slope")
        @riser_group.entities.each do |e|
            if e.is_a? Sketchup::ComponentInstance
                if e.name == "risercraddle"
                    riserconnector = RiserCraddle.new(e)
                    rc_index       = riserconnector.rc_index
                    @riserconnector[rc_index] = riserconnector
                elsif e.name == "risertab"
                    riserconnector = RiserTab.new(e)
                    rc_index       = riserconnector.rc_index
                    @riserconnector[rc_index] = riserconnector
                elsif e.name == "riserbase"
                    riserbase = RiserBase.new(e)
                    side      = riserbase.side
                    kind      = riserbase.kind
                    if    kind == "bottom"
                        @bottom_riserbase[side] = riserbase
                    elsif kind == "top"
                        @top_riserbase[side] = riserbase
                    end
                end
            elsif e.is_a? Sketchup::Group
                if e.name == "risercolumn"
                    risercolumn = RiserColumn.new(e)
                    side        = risercolumn.side
                    @risercolumn[side] = risercolumn
                end
            end
        end
    end

    def set_risertext(outside_face, side, risertext)
        risertext_group = risertext.risertext_group
        bb_text = risertext_group.bounds
        text_width = bb_text.max.x - bb_text.min.x
        p0 = Geom::Point3d.new(0.0, 0.0, 0.0)
        ux = Geom::Vector3d.new(1.0, 0.0, 0.0)
        uy = Geom::Vector3d.new(0.0, 1.0, 0.0)
        uz = Geom::Vector3d.new(0.0, 0.0, 1.0)
        xform_r1 = Geom::Transformation.rotation(p0, ux,  0.5 * Math::PI)
        xform_r2 = Geom::Transformation.rotation(p0, uy, -0.5 * Math::PI)
        if side == "left"
            xform_r3 = Geom::Transformation.rotation(p0, uz, Math::PI)
        else
            xform_r3 = Geom::Transformation.rotation(p0, uy, Math::PI)
        end
        offset_text = 1.5 + 0.5 * text_width
        bb          = outside_face.bounds
        xt = 0.5 * (bb.max.x + bb.min.x)
        yt = bb.min.y
        zt = bb.max.z - offset_text
        puts "riser.set_risertext, bb.max.z = #{bb.max.z}, offset_text = #{offset_text}"
        target_point = Geom::Point3d.new(xt, yt, zt)
        puts "riser.set_risertest, target_point = #{target_point}"

        vt = target_point - p0
        xform_t = Geom::Transformation.translation(vt)
        xform = xform_t * xform_r3 *xform_r2 * xform_r1
        risertext_group.transformation=xform
    end

    def print_riser_centers
        riser_xform = @riser_group.transformation 
        str =  "################################## Riser Centers ############################\n"
        str += "top riserconnector, mount_point = #{@primary_riserconnector.mount_point}\n"
        str += "insert_point             = #{@top_riserbase.insert_point(riser_xform)}\n"
        secondary_riserconnector = @riserconnector_list.secondary_riserconnectors("P")
        if secondary_riserconnector
            str += "2nd riserconnector, mount_point = #{secondary_riserconnector.mount_point}\n"
            str += "mount_point              = #{@bottom_riserbase.mount_point(riser_xform)}\n"
            str += "#########################################################################\n"
        end
        return str
    end

    def print_riser_centerline(side)
        puts "############################# Riser Centerline #{side} ################"
        puts "                         TargetPoint                   MountPoint"
        tp_s = "#{@riserconnector[0].target_point}"
        mt_s = "#{@riserconnector[0].mount_point}"
        puts sprintf("RiserConnector     %30s %30s", tp_s, mt_s)
        tp_s = "#{@riserconnector[0].attach_rt_point(side)}"
        puts  sprintf("RiserBase-RiserText %30s", tp_s)
        tp_s = "#{@top_riserbase[side].target_point(false)}"
        mt_s = "#{@top_riserbase[side].mount_point(false)}"
        puts  sprintf("RiserBase-Top     %30s %30s", tp_s, mt_s)
        tp_s = "#{@bottom_riserbase[side].target_point(false)}"
        mt_s = "#{@bottom_riserbase[side].mount_point(false)}"
        puts  sprintf("RiserBase-Bottom  %30s %30s", tp_s, mt_s)
        puts "########################################################################"
    end

    def make_layout_transformation(primary_riserconnector, apndx)
        normal        = primary_riserconnector.attach_crossline(apndx)
        center_point  = primary_riserconnector.attach_point(apndx)
        target_point  = Geom::Point3d.new(center_point.x, center_point.y, 0.0)
        theta = atan2(-normal.x, normal.y)
        xform_rotation    = Geom::Transformation.rotation(Geom::Point3d.new(0.0, 0.0, 0.0),
                                                           Geom::Vector3d.new(0.0, 0.0, 1.0),
                                                           theta)
        xform_translation = Geom::Transformation.translation(target_point)
        layout_xform      = xform_translation * xform_rotation
        return layout_xform
    end

    def guid
        return @guid
    end
    def slope
        return @slope
    end

    def basedata
        return basedata
    end

    def bottom_base_offset
        return @bottom_base_offset
    end

    def riser_index
        return @riser_index
    end

    def riser_group
        return @riser_group
    end

    def top_riserbase(side)
        return @top_riserbase[side]
    end

    def bottom_riserbase(side)
        return @bottom_riserbase[side]
    end

    def primary_riserconnector
        return @riserconnector[0]
    end

    def secondary_riserconnector(j)
        return @riserconnector[j]
    end

    def to_s(level = 1)
        str =  "##########################################################\n"
        str += "################### Riser ################################\n"
        str += Trk.tabs(level) + "riser_index        = #{@riser_index}\n"
        str += Trk.tabs(level) + "bottom_base_offset = #{@bottom_base_offset}\n"
        str += Trk.tabs(level) + "slope              = #{@slope}\n"
        str += "##########################################################\n"
        return str
    end

    def edit_riser
        puts "riser.edit_riser"
        puts @base.basedata_to_s(@basedata)
        slices = @base.slices
        q = @basedata["centerline_point"]
        slice_index = @basedata["slice_index"]
        slope       = @basedata["slope"]
        @base.slices.secondary_centerline_point(q, slice_index, slope)
        #@base.skins.search_skins_faces(@base, @basedata, slices)
    end

    def add_secondary(riser_defs)
        puts "################################################################################"
        puts "################################################ Add Secondary #################"
        q           = @basedata["centerline_point"]
        slice_index = @basedata["slice_index"]
        slope       = @basedata["slope"]
        puts "add_secondary, q = #{q}"
        jmin        = @base.slices.secondary_centerline_point(q, slice_index, slope)
        puts "               slice_index at minimum = #{jmin}"
        pick_slice  = @base.slices.slice_points(jmin)
        z           = pick_slice[1].z
        p           = Geom::Point3d.new(q.x, q.y, z)
        pick_location = p
        facecode      = jmin * 100 + 1
        pick_mode     = @basedata["pick_mode"]
        @secondary_basedata = @base.slices.new_basedata(pick_location, facecode, pick_mode)
        puts @base.basedata_to_s(@secondary_basedata)
        attach_point= @secondary_basedata["attach_point"]
        rb_depth    = riser_defs["riserbase_b"].bounds.depth
        if (attach_point.z - @bottom_base_offset) > rb_depth
            puts "riser.add_secondary, creating risercraddle"
            secondary_count = @riser_group.get_attribute("RiserAttributes", "secondary_count")
            rc_index        = 1 + secondary_count
            #rc_type = rc_def.get_attribute("TrkDefinitionAttrs", "definition_type")
            #if rc_type == "risercraddle"
            @riserconnector[rc_index] = RiserCraddle.new(riser_defs["risercraddle_s"], rc_index,
                                                             @riser_group, @riser_index, 
                                                             @secondary_basedata)
            #elsif rc_type == "risertab"
            #    @riserconnector[rc_index]= RiserTab.new(rcs_def, rc_index,
            #                                            @riser_group, @riser_index, 
            #                                            @secondary_basedata)
            #end
            secondary_count += 1
            @riser_group.set_attribute("RiserAttributes", "secondary_count", secondary_count)
            @riserconnector[rc_index].side_count.times do |n|
                side         = @riserconnector[rc_index].attach_side(n)
                @risercolumn[side].cut_riserconnector_notch(@riserconnector[rc_index])
            end
        else
            puts "riser.add_secondary, creating risershim"
            riser_count = @riser_index + 1
            riser = RiserShim.new(riser_group, riser_count, 
                                  @base, @secondary_basedata, @bottom_base_offset)
        end
    end
end

