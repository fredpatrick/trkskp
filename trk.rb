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

#require 'sketchup.rb'

include Math

module Trk
    def search_paths(ph, target)
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
            if face_found
                return [target_group, target_face]
            else
                return nil
            end
        }
        return nil
    end

    def list_pick_paths(ph)
        pkn = ph.count
        pkn.times do |n|
            puts "path_at #{n}"
            path = ph.path_at(n)
            path.each_with_index do |e,i|
                if e.is_a? Sketchup::Group
                    puts " #{i} - #{e.name}"
                elsif e.is_a? Sketchup::Face
                    puts " #{i} - face"
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

    def definition_to_s(definition, level)
        d = definition
        t = tabs(level)
        str =  ""
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
        str += Trk.count_faces(d.entities, level,true)
    end

    def instance_to_s(instance, level)
        i = instance
        d = instance.definition
        t = tabs(level)
        str = ""
        str += t + "component instance name                 = #{i.name}, guid = #{i.guid}\n"
        str += t + "component instance definition           = #{d.name}, guid = #{d.guid}\n"
        str += t + "component instance layer                = #{i.layer.name}\n"
        str += t + "component instance visible?             = #{i.visible?}\n"
        str += t + "component instance model name           = #{i.model.name}\n"
        str += t + "component instance model title          = #{i.model.title}\n"
        str += t + "component instance parent typename      = #{i.parent.typename}\n"
        str += Trk.dump_transformation(i, level+1)
    end
        
    def dump_transformation(g, level)
        xf = g.transformation.to_a
        str = ""
        tag= "transformation:"
        4.times { |n|
            n4 = n * 4
            str = str + tabs(level) + sprintf("%15s %10.6f,%10.6f,%10.6f,%10.6f\n",
                                             tag, xf[0+n4], xf[1+n4], xf[2+n4],xf[3+n4])
            tag = ""
        }
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
        ne = 0
        nf = 0
        str = ""
        entities.each do |e|
            if e.is_a? Sketchup::Edge
                ne += 1
            elsif e.is_a? Sketchup::Face
                nf += 1
                if print_faces
                    str = str + face_to_s(e, level)
                end
            end
        end
        str = str +
              tabs(level+1) + " # of edges     #{ne}\n" +
              tabs(level+1) + " # of faces     #{nf}\n"
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
    
    def print_attributes(f, level)
        attrdicts = f.attribute_dictionaries
        str = ""
        if !attrdicts.nil?
            attrdicts.each do |ad|
                str = str + tabs(level+1) + "#{ad.name}\n"
                ad.each_pair do  |k,v| 
                    str = str + tabs(level+2) + " #{k}    #{v}\n"
                end
            end
        end
        return str
    end
    
    def face_to_s(f, level)
        attrdicts = f.attribute_dictionaries
        str = ""
        if !attrdicts.nil?
            attrdicts.each do |ad|
                str = str + tabs(level+1) + "#{ad.name}\n"
                ad.each_pair do  |k,v| 
                    str = str + tabs(level+2) + " #{k}    #{v}\n"
                end
            end
            f.vertices.each { |v| str = str + tabs(level+2) + " #{v.position}\n" }
        end
        return str
    end

    def print_face( face)
        slice_index = face.get_attribute("SliceAttributes", "slice_index")
        str = "Face, slice_index = #{slice_index}\n"
        face.vertices.each { |v| str = str + " #{v.position}" }
        return str
    end

    def save_layer_state(visible_layer = "base")
        @layer_state = Hash.new
        Sketchup.active_model.layers.each{ |l|
            lname = l.name
            @layer_state[lname] = l.visible?
            if lname == "footprint" || lname == "track_sections" || lname == "Layer0" ||
                        lname == "zones"
                l .visible= false
            elsif lname == visible_layer
                l.visible= true
            end
        }
    end

    def restore_layer_state
        Sketchup.active_model.layers.each{ |l| l.visible=@layer_state[l.name] }
    end

    def camera_parms
        view = Sketchup.active_model.active_view
        camera = view.camera

        str =  " camera direction    = #{camera.direction}\n"
        str += " camera target       = #{camera.target}\n"
        str += " camera eye          = #{camera.eye}\n"
        str += " camera up           = #{camera.up}\n"
        str += " camera focal_length = #{camera.focal_length}\n"
        str += " camera fov          = #{camera.fov}\n"
        str += " camera height       = #{camera.height}\n"
        str += " camera xaxis        = #{camera.xaxis}\n"
        str += " camera yaxis        = #{camera.yaxis}\n"
        str += " camera zaxis        = #{camera.zaxis}\n"
        return str
    end
end
