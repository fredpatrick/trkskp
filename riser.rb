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

include Math
include Trk

class Riser
    def initialize(mode, riser_group, risertab=nil)
        puts "Riser.initialization"
        @riser_group = riser_group
        
        if mode == "build"
            @risertab     = risertab
            @center_point = @risertab.center_point
            @slope        = @risertab.slope
            @height       = @center_point.z
            @target_point = Geom::Point3d.new(@center_point.x, @center_point.y, 0.0)
            @normal       = @risertab.normal
            puts to_s
            $logfile.puts to_s
            build_new_riser(@target_point, @height, @slope)
        elsif mode == "load"
            load_existing_riser
        end
    end

    def to_s(level = 1)
        str =  "##########################################################\n"
        str += "################### Riser ################################\n"
        str += Trk.tabs(level) + "riser risertab_index = #{@risertab.risertab_index}\n"
        str += Trk.tabs(level) + "riser center_point   = #{@centerpoint}\n"
        str += Trk.tabs(level) + "riser slope          = #{@slope}\n"
        str += Trk.tabs(level) + "riser height         = #{@height}\n"
        str += Trk.tabs(level) + "riser target_point   = #{@target_point}\n"
        str += Trk.tabs(level) + "riser normal         = #{@normal}\n"
        str += "##########################################################\n"
        return str
    end

    def build_new_riser(target_point, height,slope)
        puts "riser.build_new_risertab, target_point #{target_point}, height = #{height}, " +
                      "slope = #{slope}"
        @definition = Trk.select_definition
        if @definition.nil?
            working_path = TrackTools.working_path
            filename = File.join(working_path, "RiserComponents", "riser_base_c.skp")
            puts "riser.build_new_riser, filename = #{filename}"
            Sketchup.active_model.definitions.load(filename)
            @definition = Trk.select_definition
        end
        puts Trk.definition_to_s(@definition, 1)
        instances = @definition.instances
        instances.each{ |i| puts Trk.instance_to_s(i, 1) }
        mount_point = @definition.get_attribute("RiserBaseAttributes", "mount_point")
        insertion_point = @definition.insertion_point
        bottom_xform = make_transformation(insertion_point, mount_point, 0.0, 180.degrees)
        top_xform    = make_transformation(insertion_point, mount_point, @height, 0.0)
        bottom_riser_base = @riser_group.entities.add_instance(@definition, bottom_xform)
        puts Trk.instance_to_s(bottom_riser_base, 1)
        top_riser_base    = @riser_group.entities.add_instance(@definition, top_xform)
        puts Trk.instance_to_s(top_riser_base, 1)
        puts Trk.definition_to_s(bottom_riser_base.definition, 1)
        #puts "riser.initialization, got a definition, name = #{@definition.name}"
        #Sketchup.active_model.entities.add_instance( @definition, Geom::Transformation.new)
        #rbdef_xform = Geom::Transformation.new
        #@riser_group.entities.add_instance(@riser_base_def, rbdef_xform)
    end

    def make_transformation(insertion_point, mount_point, z, rotate)
        vmove = insertion_point - mount_point 
        vmove_xform = Geom::Transformation.translation(vmove)
        rotate_xform = Geom::Transformation.rotation(Geom::Point3d.new(0.0, 0.0, 0.0),
                                                     Geom::Vector3d.new(0.0, 1.0, 0.0),
                                                     rotate)
        height_xform = Geom::Transformation.translation(Geom::Vector3d.new(0.0, 0.0, z))
        xform = height_xform * rotate_xform * vmove_xform
        return xform
    end
    def edit_base_def
        puts "riser.edit_base_def"
        if @riser_base_def.nil?
            puts "dont have riser_base_c"
            return nil
        end
        attrdicts = @riser_base_def.attribute_dictionaries
        if !attrdicts.nil?
             attrdicts.each do |ad|
                puts ad.name
                ad.each_pair { |k, v| puts "\t #{k}    #{v}" }
            end
        else 
            puts "riser.edit_base_def, definition has no attribute dictionary"
        end
        attrd = @riser_base_def.attribute_dictionary("RiserBaseAttributes", true)
        @riser_base_def.set_attribute("RiserBaseAttributes", "center_point", @center_point)
        rbdef_xform = Geom::Transformation.new
        rb = @riser_group.entities.add_instance(@riser_base_def, rbdef_xform)
        puts "addriser.edit_base_def, added instance"
        rbd = rb.definition
        attrdicts = rb.attribute_dictionaries
        if !attrdicts.nil?
             attrdicts.each do |ad|
                puts ad.name
                ad.each_pair { |k, v| puts "\t #{k}    #{v}" }
            end
        else 
            puts "riser.edit_base_def, instance has no attribute dictionary"
        end
        attrdicts = rbd.attribute_dictionaries
        if !attrdicts.nil?
             attrdicts.each do |ad|
                puts ad.name
                ad.each_pair { |k, v| puts "\t #{k}    #{v}" }
            end
        else 
            puts "riser.edit_base_def, instance def has no attribute dictionary"
        end
    end

    def load_definition
        puts "load_definitions"
        working_path = TrackTools.working_path
        component_dir = File.join(working_path, "RiserComponents")
        filenames = Dir.entries(component_dir)
        filenames.each{ |f|  puts "load_definitions.filesname #{f}"}
        m         = 0   
        tlist = ""
        filenames.each do |fn|
            puts "load_definition, fn = #{fn}, extname = #{File.extname(fn)}"
            if File.extname(fn) == '.skp'
                if m == 0
                    tlist = File.basename(fn)
                else
                    tlist = tlist + "|#{File.basename(fn)}"
                end
                m += 1
            end
        end
        opts = [tlist]
        puts "load_definition, opts = #{opts}"
        puts "load_definitions, m = #{m}"
        title = "Select Component"
        prompts = ["basename"]
        defaults = [" "]
        results = UI.inputbox prompts, defaults, opts, title
        filename = File.join(component_dir, results[0])
        puts "load_definition,filename = #{filename}"
        definition = Sketchup.active_model.definitions.load filename
        return definition
    end

    def load_existing_riser
    end
end

class EditRiserBase
    def initialize
        puts "EditRiserBase.initialize"
        TrackTools.create_directory_attributes
        puts "################################################################"
        puts "####################################### EditRiserBase"
        puts "####################################### #{Time.now.ctime}"
        $logfile.puts "################################################################"
        $logfile.puts "####################################### EditRiserBase"
        $logfile.puts "####################################### #{Time.now.ctime}"
        $logfile.flush

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
        working_layer = Sketchup.active_model.layers["working"]
        if !working_layer
            Sketchup.active_model.layers.add "working"
        end
        @definition = Trk::select_definition
        @complete = @definition.get_attribute("RiserBaseAttributes", "complete?")

        puts "EditriserBase.activate#####################################"
        puts "EditriserBase.activate#####################################"
        puts "EditRiserBase.activate definition name = #{@definition.name}"
        puts "EditRiserBase.activate instances       = #{@definition.count_instances}"
        puts "EditRiserBase.activate complete        = #{@complete}"
        puts "EditriserBase.activate#####################################"
        puts "EditriserBase.activate#####################################"
        title = @definition.name
        prompts  = ["erase_instances?", "reset_faces?", "reset attrs?`"]
        defaults = ["Yes", "No", "No"]
        tlist    = ["Yes|No", "Yes|No", "Yes|No"]
        results  = UI.inputbox(prompts, defaults, tlist, title)
        if results[0] == "Yes" then @erase_instances = true else @erase_instances = false end
        if results[1] == "Yes" then @reset_faces = true else     @reset_faces = false end
        if results[2] == "Yes" then @reset_attrs = true else     @reset_attrs = false end
        puts "#{@erase_instances}, #{@reset_faces}, #{@reset_attrs}"

        if @erase_instances
            erase_instances
        end
        if @reset_faces
            @cursor_id = @cursor_looking
            @definition.entities.each do |e|
                if e.is_a? Sketchup::Face
                    a2 = e.get_attribute("FaceAttributes", "attach_to")
                    if a2
                        puts "EditRiserBase.initialize, a2 = #{a2}"
                        attribute_dictionary = e.attribute_dictionary("FaceAttributes")
                        attribute_dictionary.delete_key("attach_to")
                    end
                end
            end
        end
        if @reset_attrs
            set_definition_attributes
        end
        @on_target = false
        @complete  = false
    end

    def onSetCursor
        if @cursor_id
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "############################# activate EditRiserBase #{Time.now.ctime}"
        puts          "############################# activate EditRiserBase #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        @ptLast = Geom::Point3d.new 1000, 1000, 1000

        save_layer_state("working")

        if @definition.count_instances == 0
            @xform = Geom::Transformation.new
            @instance = Sketchup.active_model.entities.add_instance(@definition, @xform)
            @instance.layer = "working"
            @instance.name  = "temp"
        end
        #rstatus = EditRiserBase.member_defined?("onRButtonDown")
        #puts "addriser.activate, onRButtonDown = ${rstatus}"
    end

    def deactivate(view)
        $logfile.puts "############################ deactivate EditRiserBase #{Time.now.ctime}"
        puts          "############################ deactivate EditRiserBase #{Time.now.ctime}"
        $logfile.flush
        restore_layer_state
        erase_instances
    end

    def onMouseMove( flags, x, y, view)
        if !@reset_faces then return end
        @ip.pick view, x, y
        @ph = view.pick_helper
        npick = @ph.do_pick(x, y)

        @face = nil
        @instance = nil
        if npick > 0
            ans       = search_for_face(@ph)
            @face     = ans[0]
            @instance = ans[1]
            if @face
                @cursor_id = @cursor_on_target
                @on_target = true
            else
                @cursor_id = @cursor_looking
                @on_target = false
            end
        end
    end

    def search_for_face(ph)
        #puts "editriserbase.search_for_face"
        pkn = ph.count
        instance = nil
        face     = nil
        pkn.times{ |n|
            looking_for_face = false
            path = ph.path_at(n)
            path.each_with_index{ |e,i| 
                if e.is_a? Sketchup::ComponentInstance
                    instance = e
                elsif (e.is_a? Sketchup::Face) && instance
                    face = e
                end
            }
        }
        return [face, instance]
    end

    def onLButtonDown(flags, x, y, view)
        puts "EditRiserBase.onLButtonDown"
        if !@reset_faces then return end

        if @face && @instance
            facetype = select_facetype
            if facetype == "insert"
                @insert_face = @face
                @face.set_attribute("FaceAttributes", "attach_to", "insert") 
                puts "onLButtonDown, face attribute attach set to insert"
            elsif facetype == "mount"
                @mount_face = @face
                @face.set_attribute("FaceAttributes", "attach_to", "mount") 
                puts "onLButtonDown, face attribute attach set to mount"
            end
            puts "onLButtonDown, attach_to = " + 
                            "#{@face.get_attribute('FaceAttributes', 'attach_to')}"
            reverse_camera
        end
        
        @instance.definition.entities.each do |e|
            if e.is_a? Sketchup::Face
                a2 = e.get_attribute("FaceAttributes", "attach_to")
                if !a2.nil?
                    puts "onLButtonDown, face_id = #{e.entityID}, attach_to = #{a2}"
                end
            end
        end
        @complete = test_for_complete
        set_definition_attributes
    end

    def set_definition_attributes
        if @complete
            mount_face, insert_face = get_attach_faces
            p0 = insert_face.vertices[0].position
            p1 = insert_face.vertices[1].position
            p2 = insert_face.vertices[2].position
            p3 = insert_face.vertices[3].position
            q0 = Geom::Point3d.linear_combination(0.5, p0, 0.5, p3)
            q1 = Geom::Point3d.linear_combination(0.5, p1, 0.5, p2)
            rotation_axis   = q1 - q0
            rotation_origin = q0
            @definition.set_attribute("RiserBaseAttributes", "rotation_origin", rotation_origin)
            @definition.set_attribute("RiserBaseAttributes", "rotation_axis",   rotation_axis)
            insert_point = Geom::Point3d.linear_combination(0.5, p1, 0.5, p3)
            line         = [insert_point, insert_face.normal]
            mount_point  = Geom.intersect_line_plane(line, mount_face.plane)
            thickness    = insert_point.distance_to_plane(mount_face.plane)
            puts "set_definition_attributes thickness = #{thickness}"
            @definition.set_attribute("RiserBaseAttributes", "thickness",    thickness)
            @definition.set_attribute("RiserBaseAttributes", "insert_point", insert_point)
            @definition.set_attribute("RiserBaseAttributes", "mount_point",  mount_point)
        else
            puts "EditRiserBase.set_definition_attributes, complete = #{@complete}, "
                    "cannot set attributes"
        end
        puts Trk.definition_to_s(@definition, 2)
    end

    def select_facetype
        title = "Select Facetype"
        prompts = ["FaceType"]
        defaults = [" "]
        tlist = ["mount|insert"]
        results = UI.inputbox prompts, defaults, tlist, title
        puts "select_factype, results = #{results}"
        return results[0]
    end

    def test_for_complete
        mount_face, insert_face = get_attach_faces
        if mount_face && insert_face 
            @complete = true
        else
            @complete = false
        end
        @definition.set_attribute("RiserBaseAttributes", "complete?", @complete)
    end

    def get_attach_faces
        ans = [nil, nil]
        @definition.entities.each do |e|
            if e.is_a? Sketchup::Face
                at2 = e.get_attribute("FaceAttributes", "attach_to")
                if at2 == "mount"
                    ans[0] = e
                    puts "test_for_complete, found mount face"
                    $logfile.puts "test_for_complete, found mount face"
                elsif at2 == "insert"
                    ans[1] = e
                    puts "test_for_complete, found insert face"
                    $logfile.puts "test_for_complete, found insert face"
                end
            end
        end 
        return ans
    end

    def reverse_camera
        puts "EditRiserBase.reverse_camera"
        puts Trk.camera_parms 
        result = UI.messagebox("Do want to reverse camera.up?", MB_YESNO)
        if result == IDYES
            camera = Sketchup.active_model.active_view.camera
            eye = camera.eye
            eye = [-eye.x, -eye.y, -eye.z]
            up = camera.up
            up = up.reverse
            camera.set(eye, camera.target, up)
            puts Trk.camera_parms 
        end
    end

    def erase_instances
        @definition.instances.each{ |i|
            if !i.nil?
                result = UI.messagebox("Erase instance name = #{i.name}? ", MB_YESNO)
                if result == IDYES
                    i.erase!
                    puts "deactivate instance is erased"
                end
            end
        }
    end
end

class ManageDefinitions
    def initialize
        TrackTools.tracktools_init("ManageDefinitions")
    end

    def activate
        $logfile.puts "########################## activate ManageDefinitions #{Time.now.ctime}"
        $logfile.flush
        puts "########################## activate ManageDefinitions #{Time.now.ctime}"
        while true do
            definitions = Sketchup.active_model.definitions
            prompts = ["Name", "Action"]
            opts    = " "
            dopt    = " "
            m       = 0
            defs = Hash.new
            definitions.each_with_index do |d,n|
                if !d.group?
                    tag = d.name + " #{d.count_instances}"
                    defs[d.name] = d
                    if m == 0
                        opts = "#{tag}"
                        dopt = tag
                    else 
                        opts = opts + "|#{tag}"
                    end
                    m += 1
                end
            end
            actions     = "Dump|Remove|Save"
            tlist       = [opts , actions]
            defaults    = [ dopt, "Dump"] 
            results     = UI.inputbox prompts, defaults, tlist, "Manage Definitions"
            if !results
                break
            end
            tag, action = results
            ix = tag.index(' ')
            dname = tag[0,ix]
            puts "managedefinitions.activate, dname = #{dname}, action = #{action}"
            if action == "Dump"
                puts Trk::definition_to_s(defs[dname], 1)
                $logfile.puts Trk::definition_to_s(defs[dname], 1)
            elsif action == "Remove"
                result = UI.messagebox("Do you really want to remove definition #{dname}",
                                           MB_YESNO)
                if result == IDYES
                    d = defs[dname]
                    puts "iname = #{d.name}, type = #{d.typename}"
                    #Sketchup.active_model.definitions.remove(defs[dname])
                    instances = d.instances
                    instances.each{ |i| i.erase!}
                    Sketchup.active_model.definitions.purge_unused
                    #d.entities.each{ |e| d.entities.erase_entities(e)}
                    #a = d.attribute_dictionary("RiserBaseAttributes")
                    #d.attribute_dictionaries.delete(a)
                end
            elsif action == "Save"
                Sketchup.active_model.save
            end
        end
        puts "managedefinitions.actvate pop_tool"
        model = Sketchup.active_model
        if !model.nil?
            puts "managedefinitions.activate, tool_name = #{model.tools.active_tool_name}"
            tool = Sketchup.active_model.tools.pop_tool
            puts "managedefinitions.activate-1, tool_name = #{model.tools.active_tool_name}"
        else
            puts "managedefinitions.active_model is nil"
        end
    end

    def deactivate(view)
        $logfile.puts "######################### deactivate ManageDefinitions #{Time.now.ctime}"
        $logfile.flush
        puts "########################## deactivate ManageDefinitions #{Time.now.ctime}"
    end
    def onCancel(reason, view)
        puts "managedefinitions.onCancel, reason = #{reason}"
    end
    def onMouseEnter(view)
        puts "managedefinitions.onMouseEnter, tool_name = #{Sketchup.active_model.tools.active_tool_name}"
    end
    def resume(view)
        puts "managedefinitions.resume.tool_name = #{Sketchup.active_model.tools.active_tool_name}"
    end
    def suspend(view)
        puts "managedefinitions.suspend, tool_name = #{Sketchup.active_model.tools.active_tool_name}"
    end
end
