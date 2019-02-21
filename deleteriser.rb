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
require "#{$trkdir}/risers.rb"
require "#{$trkdir}/trk.rb"

class DeleteRiser
    def initialize
        puts "DeleteRiserConnector.initialize"
        TrackTools.tracktools_init("DeleteRiser")

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
    end

    def onSetCursor
        if @cursor_id
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "########################### activate DeleteRiser #{Time.now.ctime}"
        puts          "########################### activate DeleteRiser #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        @cursor_id      = @cursor_looking
        @state          = "looking"
        @on_target      = false
        @riser_group = nil
    end

    def deactivate(view)
        $logfile.puts "######################## deactivate DeleteRiser #{Time.now.ctime}"
        puts          "######################## deactivate DeleteRiser #{Time.now.ctime}"
        $logfile.flush
    end

    def onMouseMove( flags, x, y, view)
        pick_helper = nil
        npick       = 0
        if @state == "looking"
            @ip.pick view, x, y
            pick_helper   = view.pick_helper
            npick         = pick_helper.do_pick(x, y, 1.0)
        end
        if npick > 0
            @riser_group = identify_target(pick_helper)
            @cursor_id = @cursor_on_target
            @on_target = true
            if @riser_group
                @state          = "riser_picked"
            else
                @on_target = false
                @state = "looking"
                @cursor_id = @cursor_looking
            end
        else
            @on_target = false
            @state = "looking"
            @cursor_id = @cursor_looking
        end
    end

    def onLButtonDown(flags, x, y, view)
        return if !@on_target
        puts "DeleteRiser, onLButtonDown"
        if @state == "riser_picked"
            $risers.delete_riser(@riser_group)
            @state = "looking"
            @on_target = false
            @cursor_id = @cursor_looking
            @riser_group = nil
        end
    end

    def identify_target(pick_helper)
        riser_group     = nil
        pick_helper.count.times do |n|
            path = pick_helper.path_at(n)
            path.each do  |e|
                if e.is_a? Sketchup::Group
                    if e.name == "riser" 
                        riser_group = e                          # base_group is always defined 
                        return riser_group
                    end
                end
            end
        end
        return nil
    end
end        #end of class DeleteRiser
