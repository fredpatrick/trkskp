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

class TrackEditTool

def initialize
    SKETCHUP_CONSOLE.show

    TrackTools.tracktools_init("TrackEdiTool")
    puts "RUNNING TrackEditTool"

#   attrdicts = Sketchup.active_model.attribute_dictionaries
#   attrdicts.each do |at|
#       $logfile.puts at.name
#       at.each_pair { |k, v| $logfile.puts "   key #{k}        #{v}" }
#   end
#   rendering_options = Sketchup.active_model.rendering_options
#   rendering_options["EdgeColorMode"]= 0
#   rendering_options.each_pair { |key, value| $logfile.puts "#{key} : #{value}" }
    $logfile.flush

    $current_connection_point = nil
    @dtxt = ""
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
    @ip_xform = Sections.sections_group.transformation.clone
    @ip_xform.invert!
    puts "TrackTool.initialize, sections_group.transformation"
    puts "#{dump_transformation(Sections.sections_group.transformation)}"
    puts "TrackTool.initialize, @ip_xform"
    puts "#{dump_transformation(@ip_xform)}"

    @cursor_id = @cursor_looking
    @istate = 0 
end


def activate
    puts "activate TrackTool"
    $logfile.puts "################################# activate TrackEditTool #{Time.now.ctime}"
    printf( "@istate = %d\n", @istate)
    @ip = Sketchup::InputPoint.new
    @menu_flg = false
    @ptLast = Geom::Point3d.new 1000, 1000, 1000

    @drawn = false
    Sketchup.set_status_text $exStrings.GetString(
              "TrackTool::Press left mouse button when location found"),
               SB_PROMPT
end

def deactivate(view)
    puts "deactivate TrackTool"
    $logfile.puts "################################ deactivate TrackEditTool #{Time.now.ctime}"
    attrdicts = Sketchup.active_model.attribute_dictionaries
    attrdicts.each do |at|
        $logfile.puts at.name
        at.each_pair { |k, v| $logfile.puts "   key #{k}        #{v}" }
    end
    TrackTools.model_summary
    $logfile.flush
    view.invalidate if @drawn
    Section.set_class_defaults
end

def onSetCursor
    #printf( "onSetCursor,@cursor_id = %d\n", @cursor_id )
    #printf( "@istate = %d\n", @istate)
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

def onLButtonDown(flags, x, y, view)
    puts "onLButtonDown"
    selection = Sketchup.active_model.selection
    selection.each do |e|
        puts e.typename
        if e.is_a? Sketchup::Group
            puts e.name
        end
    end
    #printf( "@istate = %d\n", @istate)
end

def onRButtonDown(flags, x, y, view)
    puts "onRButtonDown"
end

def onMouseMove( flags, x, y, view)
    @ip.pick view, x, y
    @ph = view.pick_helper
    npick = @ph.do_pick(x, y)

    if npick > 0 
        path = @ph.path_at(0)
        if got_section?(path)
            on_target = true
        end
    end
    if !on_target
        reset_cursor
        return
    end

    if @menu_flg == false
        def getMenu(menu)
            menu.add_item("Erase section") {
                erase_section(@section_group)
            }
            menu.add_item("Close") {
                puts "onMouseMove-Close, deactivating conext menu"
                reset_cursor
            }
        end
        @menu_flg = true
        @istate = 1
        @cursor_id = @cursor_on_target
        return
    end
end # end onMouseMove

    def reset_cursor
        @cursor_id = @cursor_looking
        @istate = 0
        if @menu_flg 
            undef getMenu
            @menu_flg = false
        end
    end

def erase_section(section_group)
    puts "erase_section #{section_group}"
    puts "erase_section #{@section_group}"
    Section.erase(@section_group)
    @istate = 0
    @cursor_id = @cursor_looking
    undef getMenu
    @menu_flg = false
end

def got_section? (path) 
    if !path[0].is_a? Sketchup::Group
        return false
    elsif path[0].name != "sections"
        return false
    end
    if !path[1].is_a? Sketchup::Group
        return false
    elsif path[1].name != "section"
        return false
    end
    @section_group = path[1]
    return true
end
    
def intersection_path? (ph)
    edge1 = nil
    edge2 = nil
    cline = nil
    entities = ph.all_picked
    is = 0
    entities.each do |x|
        if x.is_a? Sketchup::ConstructionLine
            if cline.nil? 
                cline = [x.position, x.direction]
                is += 1
            end
        elsif x.is_a? Sketchup::Edge
            if edge1.nil?
                edge1 = x
            else
                edge2 = x
            end
            is += 1
        end
    end
    if is == 2 || is == 3
        ve = edge1.line[1]
        normal = ve.normalize
        pt = Geom.intersect_line_line( cline, edge1.line)
        if !pt.nil?
            cpt = StartPoint.new(pt, normal)
            $current_connection_point = cpt
            return true
        end
        return false
    else
        return false
    end
end # end of look_for_intersection

def reset( view)
    @ip1.clear
    if ( view )
        view.tooltip = nil
        view.invalidate if @drawn
    end
    @drawn = false
 end

    def dump_transformation(xform)
        xf = xform.to_a
        str = ""
        tag= "transformation:"
        4.times { |n|
            n4 = n * 4
            str = str + sprintf("%15s %10.6f,%10.6f,%10.6f,%10.6f\n",tag, xf[0+n4], xf[1+n4], xf[2+n4],xf[3+n4])
            tag = ""
        }
        return str
    end

end #end of Class TrackTool
