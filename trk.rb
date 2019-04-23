 #
 # 
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

include Math

module Trk
    def search_paths_for_face(ph, target)
        target_face  = nil
        target_group = nil
        face_found = false
        pkn = ph.count
        pkn.times { |n|
            path = ph.path_at(n)
            looking_for_face = false
            path.each_with_index{ |e,i|
                if e.is_a? Sketchup::Group
                    if e.name == target
                        target_group = e
                        looking_for_face = true
                    end
                elsif looking_for_face
                    target_face = nil
                    if e.is_a? Sketchup::Face
                        face_found = true
                        face_code = e.get_attribute("FaceAttributes", "face_code")
                        if face_code
                            target_face = face_code
                        end
                        break
                    end
                end
            }
            if face_found then break end
        }
        if face_found
            return [target_group, target_face]
        end
        return nil
    end

    def search_paths_for_edge(ph, target)
        target_edge  = nil
        target_group = nil
        edge_found = false
        pkn = ph.count
        pkn.times do |n|
            path = ph.path_at(n)
            looking_for_edge = false
            path.each_with_index do |e,i|
                if e.is_a? Sketchup::Group
                    if e.name == target
                        target_group = e
                        looking_for_edge = true
                    end
                elsif looking_for_edge
                    target_edge = nil
                    if e.is_a? Sketchup::Edge
                        is_centerline = e.get_attribute("EdgeAttributes", "centerline?")
                        if is_centerline
                            edge_found = true
                            target_edge = e
                            break
                        end
                    end
                end
            end
            if edge_found then break end
        end
        if edge_found
            return [target_group, target_edge]
        end
        return nil
    end

    def list_pick_paths(ph)
        pkn = ph.count
        pkn.times do |n|
            puts "path_at #{n}"
            path = ph.path_at(n)
            path.each_with_index do |e,i|
                if e.is_a? Sketchup::Group
                    puts " #{i} - #{e.name}, guid = #{e.guid}"
                elsif e.is_a? Sketchup::Face
                    puts " #{i} - face, entityID = #{e.entityID}"
                    puts Trk.face_to_s(e, 2)
                else
                    puts " #{i}  #{e.typename}"
                end
            end
        end
    end

    def select_definition
        definitions = Sketchup.active_model.definitions
        title = "Select Definition"
        prompts = ["Name"]
        defaults = [" "]
        n = 0
        opts = " "
        defs = Hash.new
        definitions.each_with_index{ |d,i|
            if !d.group?
                defs[d.name] = d
                if n == 0
                    opts = "#{d.name}"
                else
                    opts = opts + "|#{d.name}"
                end
                n += 1
            end
        }
        tlist = [opts]
        results = UI.inputbox prompts, defaults, tlist, title
        if results
            return  defs[results[0]]
        else
            return nil
        end
    end

    def find_definition_types
        types = []
        Sketchup.active_model.definitions.each do |d|
            if !d.group?
                type = d.get_attribute("TrkDefinitionAttrs", "definition_type")
                if !type.nil?
                    types << type
                end
            end
        end
        return types
    end
    
    def select_definition_by_type(type, attrnam=nil, attrval=nil)
        puts "select_definition_by_type, type = #{type}"
        definitions = []
        Sketchup.active_model.definitions.each do |d|
            if !d.group?
                if type == d.get_attribute("TrkDefinitionAttrs", "definition_type")
                    definitions << d
                end
            end
        end
        definitions.each { |d| puts "select_definition_by_type, definition name = #{d.name}" }
        filtered_definitions_h = Hash.new
        opts                   = nil
        definitions.each do |d|
            if !attrnam.nil?
                val = d.get_attribute("TrkDefinitionAttrs", attrnam)
                if val != attrval
                    next
                end
            end
            if opts.nil? 
                opts =  d.name
            else
                opts += "|" + d.name
            end
            filtered_definitions_h[d.name] = d
        end
        title = "Select Definition"
        results = UI.inputbox ["Def Name"], [" "], [opts], title
        puts "select_definition_by_type, results = #{results}"
        if results
            return filtered_definitions_h[results[0]]
        else
            return nil
        end
    end

    def find_definition(name)
        definitions = Sketchup.active_model.definitions
        definitions.each do |d|
            if d.name == name
                return d
            end
        end
        return nil
    end

    def traverse_for_entity(entities_parent, entity_types, path=nil, &block)
        path = [] if path.nil?
        path.push(entities_parent)
        entities_parent.entities.each do |e|
            if e.is_a? Sketchup::Group
                Trk.traverse_for_entity(e, entity_types, path, &block)
                path.pop
            else
                entity_types.each do |tn| 
                    yield e, path if e.typename == tn 
                end
            end
        end
    end

    def traverse_for_groups(entities_parent, group_name, path=nil, &block)
        path = Array.new if path.nil?
        path.push(entities_parent)
        if entities_parent.name == group_name
            yield path
        else
            entities_parent.entities.each do |e|
                if e.is_a? Sketchup::Group
                    Trk.traverse_for_groups(e, group_name, path, &block)
                    path.pop
                end
            end
        end
    end

    def traverse_for_tag(entities_parent, entity_xforms=nil, &block)
        entity = entities_parent
        if entities_parent.is_a? Sketchup::ComponentDefinition
            entity = entities_parent.instances[0]
            if entity.nil?
                puts "traverse_for_tag, definition has no instances, entity is nil"
                @@logfile.puts "traverse_for_tag, definition has no instances, entity is nil"
                return
            end
            entity_xforms = []
        end
        entity_xforms.push(entity.transformation)

        entities_parent.entities.each do |e|
            if e.is_a? Sketchup::Group
                Trk.traverse_for_tag(e, entity_xforms, &block) 
                entity_xforms.pop
            else
                if entities_parent.name == "tag"
                    entities_parent.entities.each do |t|
                        if t.is_a? Sketchup::Text
                            total_xform = nil
                            while xform = entity_xforms.pop
                                if total_xform.nil?
                                    total_xform = xform
                                else
                                    total_xform = xform * total_xform
                                end
                            end
                            yield t, entities_parent, total_xform
                        end
                    end
                end
            end
        end
    end

    def definition_to_s(definition, level=1)
        d = definition
        t = tabs(level)
        str =  "#################### Definition - #{d.name} - #{d.description} ############\n"
        str += t + "component definition name                 = #{d.name}, guid = #{d.guid}\n"
        str += t + "component definition description          = #{d.description}\n"
        str += t + "component definition layer                = #{d.layer.name}\n"
        str += t + "component definition visible?             = #{d.visible?}\n"
        str += t + "component definition model                = #{d.model.name}\n"
        str += t + "component definition title                = #{d.model.title}\n"
        str += t + "component definition count_instances      = #{d.count_instances}\n"
        str += t + "component definition count_used_instances = #{d.count_used_instances}\n"
        str += t + "component definition insertion_point      = #{d.insertion_point}\n"
        str += t + "component definition entities, length     = #{d.entities.length}\n"
        if !d.material.nil?
            str += t + "component definition material.color       = #{d.material.color}\n"
        end
        str += Trk.count_faces(d.entities, level, true)
        str += Trk.print_attributes(d, 1)
        d.entities.each do |e|
            if e.is_a? Sketchup::Group
                str += Trk.group_to_s(e, level)
            end
        end
        return str
    end

    def instance_to_s(instance, level)
        i = instance
        d = instance.definition
        t = tabs(level)
        str = "#################### Instance - #{i.name} - #{i.guid} ###################\n"
        str += t + "component instance name                 = #{i.name}, guid = #{i.guid}\n"
        str += t + "component instance definition           = #{d.name}, guid = #{d.guid}\n"
        str += t + "component instance layer                = #{i.layer.name}\n"
        str += t + "component instance visible?             = #{i.visible?}\n"
        str += t + "component instance model name           = #{i.model.name}\n"
        str += t + "component instance model title          = #{i.model.title}\n"
        str += t + "component instance parent typename      = #{i.parent.typename}\n"
        str += Trk.dump_transformation(i.transformation, level+1)
    end

    def group_to_s(g, level)
        puts "group_to_s, #{g.name}"
        str = tabs(level) + "###################### group name = #{g.name}\n"
        str +=  tabs(level) + "#{g.name}, typename = #{g.typename}, " +
               "layer = #{g.layer.name}, " +
               "hidden = #{g.hidden?}, locked = #{g.locked?}  #{g.guid}\n"
        str +=  dump_transformation(g.transformation, level+1)
        str += Trk.count_faces(g.entities, level, true)
        str += Trk.print_attributes(g, 1)
        if g.name == "tag"
            t = g.entities[0]
            if t.is_a? Sketchup::Text
                str += tabs(level+1) + "text = #{t.text} \n"
                str += tabs(level+1) + "point = #{t.point} \n"
            end
        end
        str +=  count_entities(g.entities, level+1)
        attrdicts = g.attribute_dictionaries
        if !attrdicts.nil?
            attrdicts.each do |ad|
                str +=  tabs(level+1) + "#{ad.name}"
                ad.each_pair do  |k,v| 
                    str +=  tabs(level+2) + " #{k}    #{v}"
                end
            end
        end
        level += 1
        entities = g.entities
        entities.each do |e|
            if e.is_a? Sketchup::Group
                str += group_to_s(e, level)
            end
        end
        return str
    end
        
    def dump_transformation(xform, level=1)
        xf = xform.to_a
        tag = ""
        str = tabs(level) + "transformation:\n"
        4.times { |n|
            n4 = n * 4
            str = str + tabs(level) + sprintf("%15s %10.6f,%10.6f,%10.6f,%10.6f\n",
                                             tag, xf[0+n4], xf[1+n4], xf[2+n4],xf[3+n4])
            tag = ""
        }
        str += tabs(level) + "origin  = #{xform.origin}\n"
        str += tabs(level) + "xaxis   = #{xform.xaxis}\n"
        str += tabs(level) + "yaxis   = #{xform.yaxis}\n"
        str += tabs(level) + "zaxis   = #{xform.zaxis}\n"
        return str
    end

    def select_file(target_dir)
        puts "Trk.select_file, active_model = #{Sketchup.active_model.name}, " +
                             "target_dir = #{target_dir}"
        filenames  = Dir.entries target_dir
        skpfiles   = []
        filenames.each do |fn|
            if File.extname(fn) == '.skp'
                skpfiles << fn
            end
        end
        opts = ""
        skpfiles.each do |s,m|
            if m == 0
                opts = File.basename(s)
            else
                opts = opts + "|#{File.basename(s)}"
            end
        end
        opts = [opts]
        title = "Select File"
        prompts = ["filename"]
        defaults = [" "]
        results = UI.inputbox prompts, defaults, opts, title
        if !results
            Sketchup.active_model.tools.pop_tool
        end
        filename = File.join(target_dir, results[0])
        if !Sketchup.open_file(filename)
            raise RunTimeError, ",select_file, Unable to open file #{filename}"
        end
        return filename
    end

    def count_faces(entities, level, print_faces=false)
        ng = 0
        ne = 0
        nf = 0
        nt = 0
        str = " "
        entities.each_with_index do |e,n|
            if e.is_a? Sketchup::Edge
                ne += 1
                if print_faces
                    str += print_attributes(e, level)
                end
            elsif e.is_a? Sketchup::Face
                nf += 1
                if print_faces
                    str += print_attributes(e, level)
                end
            elsif e.is_a? Sketchup::Text
                nt += 1
            elsif e.is_a? Sketchup::Group
                ng += 1
            end
        end
        str += tabs(level) + " # of groups    #{ng}\n" +
              tabs(level) + " # of edges     #{ne}\n" +
              tabs(level) + " # of faces     #{nf}\n" +
              tabs(level) + " # of text ents #{nt}\n"
#       end
        return str
    end

    def count_entities(entities, level)
        ng =
        ne = 0
        nf = 0
        nv = 0
        nu = 0
        nt = 0
        nc = 0
        nl = 0
        ndl = 0
        neu = 0
        str = tabs(level  ) + "entities count = #{entities.length}\n"
        entities.each do |e|
            if e.is_a? Sketchup::Group
                ng += 1
            elsif e.is_a? Sketchup::Edge
                ne += 1
            elsif e.is_a? Sketchup::Face
                nf += 1
            elsif e.is_a? Sketchup::Vertex
                nv += 1
            elsif e.is_a? Sketchup::Text
                nt += 1
            elsif e.is_a? Sketchup::ComponentInstance
                nc += 1
            elsif e.is_a? Sketchup::Loop
                nl += 1
            elsif e.is_a? Sketchup::DimensionLinear
                ndl += 1
            elsif e.is_a? Sketchup::EdgeUse
                neu += 1
            else
                puts e.typename
                nu += 1
            end
        end
        if ng  != 0 then str = str + tabs(level+1) + " # of groups              #{ng}\n" end
        if ne  != 0 then str = str + tabs(level+1) + " # of edges               #{ne}\n" end
        if nf  != 0 then str = str + tabs(level+1) + " # of faces               #{nf}\n" end
        if nv  != 0 then str = str + tabs(level+1) + " # of verticies           #{nv}\n" end
        if nt  != 0 then str = str + tabs(level+1) + " # of text ents           #{nt}\n" end
        if nc  != 0 then str = str + tabs(level+1) + " # of component instances #{nc}\n" end
        if nl  != 0 then str = str + tabs(level+1) + " # of loops               #{nl}\n" end
        if neu != 0 then str = str + tabs(level+1) + " # of edgeuses            #{neu}\n" end
        if ndl != 0 then str = str + tabs(level+1) + " # of dimensions          #{ndl}\n" end
        if nu  != 0 then str = str + tabs(level+1) + " # of other               #{nu}"    end
        return str
    end

    def tabs(ntab = 0)
        tbs = ""
        n = 0
        while n < ntab
            tbs = tbs + "\t"
            n += 1
        end
        return tbs
    end
    
    def print_attributes(f, level=1)
        attrdicts = f.attribute_dictionaries
        str = ""
        if !attrdicts.nil?
            attrdicts.each do |ad|
                if ad.name != "SU_DefinitionSet"
                    str = str + tabs(level+1) + "#{ad.name}\n"
                    ad.each_pair do  |k,v| 
                        #str = str + tabs(level+2) + " #{k}    #{v}\n"
                        str = str + tabs(level+2) + sprintf("%-18s = ", k) + "#{v}\n"
                    end
                    if ((f.is_a? Sketchup::Edge) || (f.is_a? Sketchup::Face))
                         f.vertices.each_with_index do |v,i|
                            str = str + tabs(level+2) + "#{v.position}\n"
                        end
                    end
                end
            end
            if f.is_a? Sketchup::Face
                str += tabs(level+2) + "normal = #{f.normal}\n"
            end
        end
        return str
    end
    
    def face_to_s(f, level)
        str       = " "
        attrdicts = f.attribute_dictionaries
        if !attrdicts.nil?
            attrdicts.each do |ad|
                str = str + tabs(level+1) + "#{ad.name}, layer = #{f.layer.name}\n"
                ad.each_pair do  |k,v| 
                    str = str + tabs(level+2) + " #{k}    #{v}\n"
                end
            end
            f.vertices.each { |v| str = str + tabs(level+2) + " #{v.position}\n" }
        end
        return str
    end

    def taggroup_to_s(g, level)
        xf = g.transformation
        edges = []
        text  = nil
        point = nil
        g.entities.each do |e|
            if e.is_a? Sketchup::Text
                text   = e.text
                point  = e.point
            elsif e.is_a? Sketchup::Edge
                edges << e
            end
        end
        str  = tabs(level) + "tag_group, name = #{g.name}, hidden = #{g.hidden?}, " +
                                    "transformation applied to geometry\n"
        str += tabs(level+1) + "text   = #{text}\n"
        puts str
        str += tabs(level+1) + "point  = #{point.transform(xf)}\n"
        edges.each do |e| 
            l   =  e.line
            str += tabs(level+1) + "edge   = #{l[0].transform(xf)},  #{l[1].transform(xf)}\n" 
        end
        str += Trk.dump_transformation(xf,  level+1)
        return str
    end


    def find_facetag(d, tag)
        textent = nil
        d.entities.each do |e|
            if e.is_a? Sketchup::Text
                if e.text == tag
                    textent = e
                   #puts "find_facetag, found textent, text   = #{e.text} \n" +
                   #     "                             point  = #{e.point}"
                end
            end
        end
        if textent.nil? then return nil end

        d.entities.each do |e|
            if e.is_a? Sketchup::Face
                #puts "find_facetag, got Face, entityID = e.entityID"
                #e.vertices.each_with_index { |v,i| puts "find facetag,  #{i}  #{v.position}" }
                plane = e.plane
                if textent.point.on_plane?(plane)
                    puts "find_facetag, found tag on face, tag = #{tag}"
                    return e
                end
            end
        end
    end

    def print_face( face)
        slice_index = face.get_attribute("SliceAttributes", "slice_index")
        str = "Face, slice_index = #{slice_index}\n"
        face.vertices.each { |v| str = str + " #{v.position}" }
        return str
    end

    def face_to_s(f)
        str = "face - persistent_id = #{f.persistent_id} normal = #{f.normal} \n"
        f.vertices.each_with_index do |v,i| 
            p = v.position
            str += sprintf("%2d %15.10f #%15.10f %15.10f \n", i, p.x, p.y, p.z) 
        end
        return str
    end

    def save_layer_state(visible_layer = "base")
        @layer_state = Hash.new
        Sketchup.active_model.layers.each{ |l|
            lname = l.name
            @layer_state[lname] = l.visible?
            if lname == "track_sections" || lname == "Layer0" || lname == "zones"
                l .visible= false
            elsif lname == visible_layer
                l.visible= true
            end
        }
    end

    def restore_layer_state
        Sketchup.active_model.layers.each{ |l| l.visible=@layer_state[l.name] }
    end

    def camera_parms(camera = Sketchup.active_model.active_view.camera)

        str =  " camera direction    = #{camera.direction}\n"
        str += " camera target       = #{camera.target}\n"
        str += " camera eye          = #{camera.eye}\n"
        str += " camera up           = #{camera.up}\n"
        #str += " camera focal_length = #{camera.focal_length}\n"
        #str += " camera fov          = #{camera.fov}\n"
        str += " camera height       = #{camera.height}\n"
        str += " camera xaxis        = #{camera.xaxis}\n"
        str += " camera yaxis        = #{camera.yaxis}\n"
        str += " camera zaxis        = #{camera.zaxis}\n"
        return str
    end

    def make_transformation(source_pt, source_vector, target_pt, target_vector, slope)
        puts "make_transformation, source_vector = #{source_vector}"
        puts "make_transformation, target_vector = #{target_vector}"
        cos = source_vector.dot(target_vector)
        sin = (source_vector.cross(target_vector)).z
        puts "make_transformation, cos = #{cos}, sin = #{sin}"
        theta = Math.atan2(sin, cos)
        puts "make_transformation, theta = #{theta}"
        shift = target_pt - source_pt
        alpha = -Math.atan(slope)
        puts "make_transformation, slope = #{slope}, alpha = #{alpha}"

        xform_slope       = Geom::Transformation.rotation(source_pt, source_vector, alpha)
        xform_rotation = Geom::Transformation.rotation(source_pt, 
                                                       Geom::Vector3d.new(0.0, 0.0, 1.0), 
                                                       theta)
        xform_translation = Geom::Transformation.translation(shift)
        xform =  xform_translation * xform_rotation * xform_slope
        puts Trk.dump_transformation(xform,2)
        return xform
    end

    def build_transformation(source_point, source_xline, source_normal,
                             target_point, target_xline, slope=0.0)
        cos = source_xline.dot(target_xline)
        sin = (source_xline.cross(target_xline)).z
        angle = Math.atan2(sin, cos)
        puts "build_transformation, angle = #{angle}"
        delta = -Math.atan(slope)
        puts "build_transformation, delta = #{delta}"
        xform_slope       = Geom::Transformation.rotation(source_point, source_xline, delta)
        xform_rotation    = Geom::Transformation.rotation(source_point, source_normal, angle)
        xform_translation = Geom::Transformation.translation(target_point - source_point)
        return xform_translation * xform_rotation * xform_slope
    end

    def make_filename(fname)
        homedir  = Sketchup.active_model.get_attribute("DirectoryAttributes", "home_directory")
        workdir  = Sketchup.active_model.get_attribute("DirectoryAttributes", "work_directory")
        modeldir = Sketchup.active_model.get_attribute("DirectoryAttributes", "model_directory")
        filenam  = File.join(homedir, workdir, modeldir,fname)
        return filenam
    end

    def find_structure_top(p)
        structure_h = 0.0
        Sketchup.active_model.entities.each do |e|
            if e.layer.name == "structure"
                xform = e.transformation.inverse
                pt = p.transform(xform)
                pline = [pt, Geom::Point3d.new(pt.x, pt.y, -99.0) ]

                e.entities.each do |f|
                    if f.is_a? Sketchup::Face
                        q = Geom.intersect_line_plane(pline, f.plane)
                        if !q.nil?
                            result = f.classify_point(q)
                            if result != Sketchup::Face::PointOutside
                                if q.z > structure_h
                                    structure_h = q.z
                                end
                            end
                        end
                    end
                end
            end
        end
        return structure_h
    end
end
