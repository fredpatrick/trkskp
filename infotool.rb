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

require "#{$trkdir}/section.rb"

$exStrings = LanguageHandler.new("track.strings")

include Math

class InfoTool

    def initialize

        cursor_path = Sketchup.find_support_file("riser_cursor_0.png",
                                                 "Plugins/xc_tracktools/")
        if cursor_path
            @cursor_looking = UI.create_cursor(cursor_path, 16, 16) 
        else
            UI.messagebox("Couldnt get cursor_path")
            return
        end 
        cursor_path = Sketchup.find_support_file("riser_cursor_1.png", 
                                                 "Plugins/xc_tracktools/")
        if  cursor_path
            @cursor_on_target = UI.create_cursor(cursor_path, 16, 16) 
        else
            UI.messagebox("Couldnt get cursor_path")
            return
        end 
        @cursor_id = @cursor_looking
        @istate = 0 
        @dtxt = ""
        @sid_last = 0
        @cid_last = 0
        @info_flg = false

        puts "#########################################################"

        Section.load_sections

    end

    def activate
        puts "activate InfoTool"
        @ip = Sketchup::InputPoint.new
        @drawn = false
        Section.report_sections
        risers = Riser.risers
        puts "Risers - #{risers.length}"
        risers.each do |riser|
            puts "height - #{riser.height.to_s}"
        end
    end

    def deactivate(view)
        puts "deactivate InfoTool"
        if @drawn
            view.invalidate
        end
    end

    def onSetCursor
        if @cursor_id
            UI.set_cursor(@cursor_id)
        end
    end

    def draw(view)
        if @ip.valid?
            if @info_flg == true
                styp = @info_data[0]
                q    = @info_data[2]
                info = @info_data[1]
                spt  = view.screen_coords(q)
                stx  = Geom::Point3d.new(5.0,25.0, 0.0)

                clr = Sketchup::Color.new "red"
                view.drawing_color = clr

                if styp == "curved" || styp == "switch"
                    view.line_stipple=""
                    view.line_width = 2.0
                    p0 = Geom::Point3d.new(spt.x - 10.0, spt.y, 0.0)
                    p1 = Geom::Point3d.new(spt.x + 10.0, spt.y, 0.0)
                    view = view.draw2d(GL_LINE_STRIP, p0, p1)
                    p0 = Geom::Point3d.new(spt.x, spt.y - 10.0, 0.0)
                    p1 = Geom::Point3d.new(spt.x, spt.y + 10.0, 0.0)
                    view = view.draw2d(GL_LINE_STRIP, p0, p1)
                    p0 = @info_data[3]
                    p1 = @info_data[4]
                    view.line_stipple="."
                    view.draw_line(q, p0)
                    view.draw_line(q, p1)
                end
                view.draw_text(stx, info)
            end
        end
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        ptCurrent = @ip.position
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked
        if !Section.section_group?(entity)
            @cursor_id = @cursor_looking
            return false
        end

        section = Section.section(entity.guid)
        connection_pt = section.closest_point(ptCurrent)
        if !connection_pt
            return false
        end
        sid = section.object_id
        cid = connection_pt.object_id
        if sid != @sid_last || cid != @cid_last
            @sid_last = sid
            @cid_last = cid
            @info_data = section.info(connection_pt)
            @info_flg = true
        end
        @cursor_id = @cursor_on_target
        ph.view.refresh
    end
end
