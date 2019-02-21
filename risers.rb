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
require "#{$trkdir}/base.rb"
require "#{$trkdir}/riser.rb"
require "#{$trkdir}/risershim.rb"
require "#{$trkdir}/trk.rb"

include Math
include Trk

class Risers
    def initialize
        puts "Risers.initialize"
        @risers = Hash.new
        @risers_group = nil
        Sketchup.active_model.entities.each do |e|
            if e.is_a? Sketchup::Group
                if e.name == "risers"
                    @risers_group = e
                    @risers_group.layer = "base"
                end
            end
        end
        if @risers_group.nil? 
            puts "Risers.initialize-0"
            @risers_group      = Sketchup.active_model.entities.add_group
            @risers_group.name = "risers"
            @risers_group.description = "group risers"
            @risers_group.layer       = "base"
            @risers_group.make_unique
            @riser_count       = 0
            @risers_group.set_attribute("RisersAttributes", "riser_count", 0)
        else
            @riser_count        = @risers_group.get_attribute("RisersAttributes", "riser_count")
            @risers_group.entities.each do |e|
                if e.is_a? Sketchup::Group
                    if e.name == "riser"
                        riser_group = e
                        riser       = Riser.new( riser_group)
                        @risers[riser_group.guid] = riser
                    elsif e.name == "risershim"
                        risershim_group = e
                        risershim   = RiserShim.new(risershim_group)
                        @risers[risershim_group.guid] = risershim
                    end
                end
            end
        end
    end

    def Risers.search_for_face(ph)
        #puts "Risers.search_for_face"
        pkn = ph.count
        instance = nil
        face     = nil
        pkn.times{ |n|
            looking_for_face = false
            path = ph.path_at(n)
            path.each_with_index{ |e,i| 
                if e.is_a? Sketchup::ComponentInstance
                    puts "Risers.search_for_face #{i}, name = #{e.name}, ComponentInstance"
                    instance = e
                elsif (e.is_a? Sketchup::Face) && instance
                    puts "Risers.search_for_face #{i}, Face"
                    e.vertices.each{ |v,i| puts "             #{i}, #{v.position}" }
                    puts "Risers.search_for_face, normal = #{e.normal}"
                    face = e
                end
            }
        }
        return face
    end

    def erase_all_risers
        @risers.each_pair do |key, value|
            riser = value
            riser.erase
        end
        @risers.clear
    end

    def delete_riser(riser_group)
        guid  = riser_group.guid
        riser = @risers[guid]
        riser.erase
        @risers.delete guid
    end

    def bounding_box_to_s(bb, label)
        str = "######################## BoundingBox for #{label} ##########################"
        str += "    min      = #{bb.min}\n"
        str += "    max      = #{bb.max}\n"
        str += "    width    = #{bb.width}\n"
        str += "    height   = #{bb.height}\n"
        str += "    depth    = #{bb.depth}\n"
        str += "###########################################################################"
        return str
    end

    def create_new_riser(base, basedata, riser_defs, structure_h, stop_after_build)
        riser_group  = @risers_group.entities.add_group

        attach_point = basedata["attach_point"]
        rc_def = riser_defs["risercraddle_p"]
        rb_def = riser_defs["riserbase_b"]
        rc_thickness = rc_def.get_attribute("RiserConnectorAttrs", "thickness")
        rb_depth     = rb_def.bounds.depth
        puts "risers.create_new_riser, structure_h    = #{structure_h}, \n" +
                                      "rc_thickness   = #{rc_thickness}, \n" +
                                      "rb_depth       = #{rb_depth}, \n" +
                                      "attach_point   = #{attach_point}\n" +
                                      "attach_point.z = #{attach_point.z} \n" 
        cl = attach_point.z - rc_thickness - 2 * rb_depth - structure_h
        puts "risers.create_new_riser, cl = #{cl}"
        if cl > 0.5
            puts "risers.create_new_riser, creating Riser"

            riser_group.name = "riser"
            riser = Riser.new(riser_group, @riser_count,
                            base, basedata, riser_defs,
                            structure_h, stop_after_build)
        else
            puts "risers.create_new_riser, creating RiserShim"

            riser_group.name = "risershim"
            riser            = RiserShim.new(riser_group, @riser_count,
                                             base, basedata, structure_h)
        end
        @risers[riser_group.guid] = riser
        @riser_count += 1
        @risers_group.set_attribute("RisersAttributes", "riser_count", @riser_count)

        return riser
    end

    def riser(guid)
        return @risers[guid]
    end
end #end of class Risers
