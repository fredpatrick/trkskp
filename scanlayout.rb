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
require "#{$trkdir}/zone.rb"
require "#{$trkdir}/switches.rb"

$exStrings = LanguageHandler.new("track.strings")

include Math

class ScanLayout

    def initialize
        TrackTools.tracktools_init("ScanLayout")
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
        @ip_xform = $zones.zones_group.transformation.clone
        @ip_xform.invert!

        @cursor_id = @cursor_looking
        @istate = 0 
    end

    def onSetCursor
        if @cursor_id
            
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "############################# activate ScanLayout #{Time.now.ctime}"
        puts          "############################# activate ScanLayout #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @on_target = false
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate ScanLayout #{Time.now.ctime}"
        puts          "############################ deactivate ScanLayout #{Time.now.ctime}"
        TrackTools.model_summary
        $logfile.flush
        view.invalidate if @drawn
    end

    def onLButtonDown( flags, x, y, view)
        if !@on_target then return end
        puts "onLButtonDown"

        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)
        puts "onLButtonDown, npick = #{npick}"

        if npick > 0 
            i = 0
            while i < npick
                path = @ph.path_at(i)
                puts "path size = #{path.size}"
                path.each_with_index do |e,i|
                    if ( e.is_a? Sketchup::Group )
                        puts "Section.section_path? #{i}, e.name = #{e.name}, #{e.guid}"
                      # if ( e.name == "section" )
                      #     section = @@track_sections[e.guid]
                      #     return section
                      # end
                    end
                end
                i += 1
            end
        end
    end


    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        if npick > 0 
            path = @ph.path_at(0)
            section = Section.section_path?(path)
            if  section.nil?
                @on_target = false
                @cursor_id = @cursor_looking
            else
                @on_target = true
                @cursor_id = @cursor_on_target
            end
        end
    end # end onMouseMove
end #end of Class ScanLayout
