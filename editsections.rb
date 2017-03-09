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

class EditSections

    def initialize
        TrackTools.tracktools_init("EditSections")
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
        $logfile.puts "############################# activate EditSections #{Time.now.ctime}"
        puts          "############################# activate EditSections #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        @ptLast = Geom::Point3d.new 1000, 1000, 1000
        @selection = Sketchup.active_model.selection
        @selection.clear

        @drawn = false
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate EditSections #{Time.now.ctime}"
        puts          "############################ deactivate EditSections #{Time.now.ctime}"
        TrackTools.model_summary
        $logfile.flush
        view.invalidate if @drawn
    end

    def onMouseMove( flags, x, y, view)
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        if npick > 0 
            path = @ph.path_at(0)
            section = Section.section_path?(path)
            if  section.nil?
                if @menu_flg == true
                    undef getMenu
                    if ( !@section.nil? && !@section.section_group.deleted? )
                        @section.outline_visible(false)
                    end
                    @cursor_id = @cursor_looking
                    @menu_flg = false
                    define_onRButtonDown
                end
            else
                @section   = section
                @section.outline_visible(true)
                @cursor_id = @cursor_on_target
                if @menu_flg == false
                    make_edit_menu
                    @menu_flg = true
                end
            end
        else
            if ( !@section.nil? && !@section.section_group.deleted? )
                @section.outline_visible(false)
            end
            if @menu_flg == true
                undef getMenu
                @cursor_id = @cursor_looking
                @menu_flg = false
            end
        end
    end # end onMouseMove

    def make_edit_menu
        def getMenu(menu)
            menu.add_item("Erase Current Selection") {
                erase_section
            }
            menu.add_item("Add To Section List") {
                add_to_selection
            }
            menu.add_item("Close") {
                puts "onMouseMove-Close, deactivating conext menu"
                undef getMenu
                @cursor_id = @cursor_looking
                @menu_flg = false
            }
        end
    end

    def erase_section
        if ( @section.nil? )
            return
        end
        if ( @section.section_type == "switch" )
            $switches.erase_switch(@section)
            @section = nil
            return
        end

        zone = @section.zone
        if ( zone.erase_section(@section) )    #erase_section returns true no sections remain
            $zones.delete_zone(zone.guid)
            Sketchup.active_model.selection.clear
            @section = nil
        end
    end

    def add_to_selection
        @selection.add ( @section)
    end
end #end of Class EditSections
