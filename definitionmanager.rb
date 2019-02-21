# Copyright 2018, Xylocomp Inc
#
# This extention provides tools for working with component definitions  in Sketchup model
require 'sketchup.rb'
require 'extensions.rb'
require 'langhandler.rb'
$trkdir = "/Users/fredpatrick/wrk/trkskp"
puts $trkdir
require "#{$trkdir}/trk.rb"
require "#{$trkdir}/riserbase.rb"

$exStrings = LanguageHandler.new("definitionmanager.strings")

definitionmanagerExtension = SketchupExtension.new(
  $exStrings.GetString("Work with Component Definitions"),
  "/Users/fredpatrick/wrk/trkskp/tracktools.rb")

definitionmanagerExtension.description = $exStrings.GetString(
  "Tools for dumping attributes in Sketchup model")
definitionmanagerExtension.version = "1.0"
definitionmanagerExtension.creator = "Xylocomp"
definitionmanagerExtension.copyright = "2018, Xylocomp Inc."

Sketchup.register_extension definitionmanagerExtension, true

class DefinitionManager
    def initialize
        logpath = "/Users/fredpatrick/wrk/definitionmanager.log"
        @@logfile = File.open(logpath, "w")
        puts "DefinitionManager.initialize"
        @@logfile.puts "DefinitionManager.initialize"
        #TrackTools.tracktools_init("DefinitionManager")
    end

    def activate
        puts          "########################## activate DefinitionManager #{Time.now.ctime}"
        read_defaults
        
        done = false
        while !done do
            title = "DefinitionManager"
            tlist = "WorkOnDefinition|MergeDefinition|CurrentDefinitions|RemoveAllDefinitions"
            result = UI.inputbox ["Option"], ["SeclectDefinition"], [tlist], title
            return if result == false

            option = result[0]
            if option == "WorkOnDefinition"
                work_on_definition()
            elsif option == "MergeDefinition"
                merge_definition()
            elsif option == "CurrentDefinitions"
                current_definitions()
            elsif option == "RemoveAllDefinitions"
                remove_all_definitions
                ret = UI.messagebox("Do you want to save results of remove?", MB_YESNO)
                if ret == IDYES
                    Sketchup.active_model.save
                end
            end
        end
    end

    def read_defaults
        @defaults = Hash.new
        @definition_types = Hash.new
        @defaults_filnam = ENV["HOME"] + "/wrk/skp/definitionmanager.dflt"
        lines = IO.readlines(@defaults_filnam)
        lines.each do |l|
            puts "DefinitionManager.activate, l = #{l}"
            words = l.split
            type  = words[0]
            if type == "Default"
                words.delete_at(0)
                key, value = words
                @defaults[key] = value
            elsif type == "DefinitionType"
                words.delete_at(0)
                puts "DefinitionManager.activate, words = #{words}"
                key, value = words
                @definition_types[key] = value
            end
        end
        puts "DefinitionManager.activate. Defaults"
        puts "DefinitionManager.activate. Defaults"
        @defaults.each_pair { |k,v| puts " #{k} --  #{v} " }
        puts "DefinitionManager.activate. DefinitionTypes"
        @definition_types.each_pair { |k,v| puts " #{k} --  #{v} " }
    end

    def work_on_definition
        while true do
            filname = select_definition_file()
            break if filname.nil?

            while true do
                definition = select_definition_from_file(filname)
                break if definition.nil?

                do_actions(definition)
            end
        end
    end

    def merge_definition()
        definitions = Sketchup.active_model.definitions

        while true do
            filname = select_definition_file()
            break if filname.nil?

            definitions.load(filname)
        end

        ret = UI.messagebox("Do you want to erase tag groups from definition?",  MB_YESNO)
        if ret == IDYES
            while true do
                definition = select_definition_from_model()
                break if definition.nil?

                erase_tag_groups(definition)
            end
        end
    end

    def select_definition_file
        #dirname  = UI.select_directory(directory: "#{ENV['HOME'] + '/wrk/skp'}")  
        dirname  = UI.select_directory()  
        return if dirname.nil?
        filnames = make_filenames(dirname)
        puts "select_definition, filnames = #{filnames}"
        title    = "Select File from #{dirname}"
        results  = UI.inputbox ["filname"], [" "], [filnames], title
        return nil if results == false

        filname  = results[0]
        return filname
    end

    def select_definition_from_file(filname)
        @defs    = Definitions.new(filname)
        title    = "Selection definition from #{filname}"
        results  = UI.inputbox ["defname"], [" "], [@defs.opts], title
        return nil  if results == false

        defname  = results[0]
        return nil if defname == " "
        definition =  @defs.definition(defname)
        return definition
    end

    def select_definition_from_model()
        @defs    = Definitions.new()
        title    = "Selection definition from active Model"
        results  = UI.inputbox ["defname"], [" "], [@defs.opts], title
        return nil  if results == false

        defname  = results[0]
        return nil if defname == " "
        definition =  @defs.definition(defname)
        return definition
    end

    def do_actions(definition)
        while true do
            title      = "Action for #{definition.name}"
            tlist      = ["List|Remove|Rename|Edit|Instance|AddAttribute|FindTagGroups|EraseTagGroups"]
            result     = UI.inputbox ["Action"], ["List"], tlist, title
            return nil if result == false

            action     = result[0]
            if action == "List"
                puts Trk.definition_to_s(definition, 2)
            elsif action == "Rename"
                @defs.rename_definition(definition.name)
                action_done = true
            elsif action == "Remove"
                definition.instances.each { |i| puts " #{i.name}" }
                @defs.remove(definition.name)
                ret = UI.messagebox("Do you want to save results of remove?", MB_YESNO)
                if ret == IDYES
                    Sketchup.active_model.save
                end
                return nil
            elsif action == "Edit"
                def_type = prompt_for_type(definition) 
                code = make_edit_definition
                puts "do_action, definition_type = #{def_type}"
                puts "do_action, ###################### code #######################"
                puts " #{code}"
                puts "do_action, ################## end code #######################"
                Trk.traverse_for_entity(definition, ["Face", "Edge"]) { |e, path| 
                    e.delete_attribute("FaceAttributes") if e.typename == "Face"
                    e.delete_attribute("EdgeAttributes") if e.typename == "Edge"
                }
                definition.delete_attribute("TrkDefinitionAttrs")
                definition.set_attribute("TrkDefinitionAttrs",  "definition_type", def_type)
                definition.set_attribute("TrkDefinitionAttrs",  "timedate",       "#{Time.now}")
               #RiserBase.edit_riserbase(definition)
                begin
                    DefinitionManager.class_eval code
                rescue => ex
                    puts ex.to_s
                    trace = ex.backtrace
                    trace.each{ |s| puts s}
                    Sketchup.active_model.tools.pop_tool
                end
                #puts Trk.definition_to_s(definition, 2)
                ret = UI.messagebox("Do you want to save results of edit?", MB_YESNO)
                if ret == IDYES
                    Sketchup.active_model.save
                end
            elsif action =="Instance"
                xform = Geom::Transformation.new
                Sketchup.active_model.entities.add_instance(definition, xform)
                action_done = true
            elsif action == "AddAttribute"
                add_attribute(definition)
            elsif action == "FindTagGroups"
                find_tag_groups(definition)
            elsif action == "EraseTagGroups"
                erase_tag_groups(definition)
            end
        end
    end

    def add_attribute(definition)
        results = true
        while results do
            title    = "Add attributes to defininition, name = #{definition.name},"+
                            " Cancel = NO"
            prompts  = ["Dictionary", "Name", "Value"]
            defaults = [" ", " ", " "]
            attribute_dictionaries = definition.attribute_dictionaries
            opts = nil
            attribute_dictionaries.each do |ad|
                if opts.nil?
                    opts = ad.name
                else
                    opts += "|" + ad.name
                end
            end
            puts "add_attribute, opts = #{opts}"
            tlist    = [opts, "", ""]
            results  = UI.inputbox prompts, defaults, tlist, title
            break if results == false
            ad_name, name, value = results
            if value == "false"
                value = false
            elsif value == "true"
                value = true
            end
            puts "add_attribute, name = #{name}, value = #{value}, #{value.class}"
            definition.set_attribute(ad_name, name, value)
        end
    end

    def cleanup_definitions
        @@logfile.puts "####################################### eliminate entities with no name"
        @@logfile.flush
        STDOUT.flush
        # the following code assumes that no legitimate entities in active_model.entities
        # have entity.name == ""
        #definitions.each { |d| puts "merge_defintion, definition name = #{d.name}" }
        n = 0
        Sketchup.active_model.entities.each do |e|
            if (e.is_a? Sketchup::Group) || (e.is_a? Sketchup::ComponentInstance )
                puts " e.name = #{e.name} #{e.typename}"
                if e.name == ""
                    Sketchup.active_model.entities.erase_entities(e)
                    n += 1
                end
            end
        end
        @@logfile.puts "##################################### #{n} entities w/ noname erased"
        @@logfile.flush
#
#       xform = Geom::Transformation.new
#       puts "####################################### cleanup definitions"
#       @@logfile.puts "####################################### cleanup definitions"
#       @@logfile.flush
#       STDOUT.flush
#       definitions.each do |d|
#           if d.count_used_instances == 0
#              Sketchup.active_model.entities.add_instance(d, xform)
#           end
#           Trk.traverse_for_tag(d) do |t,e,total_xform|
#               @@logfile.puts "merge_definition, found tag group-#{t.text} - #{e.name} "
#           end
#           d.entities.each do |e|
#               if e.is_a? Sketchup::Group
#                   if e.name == "tag"
#                       @@logfile.puts "merge_definitions, tag_group erased," +
#                                   "#{e.typename} #{e.parent.typename}, #{e.parent.guid}"
#                       d.entities.erase_entities(e)
#                   end
#               end
#           end
#           @@logfile.puts "#################################### after traverses"
#           @@logfile.flush
#           @@logfile.puts Trk.definition_to_s(d)
#       end
    end

    def find_tag_groups(definition)
        Trk.traverse_for_groups(definition, "tag") do |path|
            e = path[path.length-1]
            str = ""
            path.each { |e| str += " #{e.name}" }
            @@logfile.puts "find_tag_groups, found tag group - #{e.name} " + str
            puts "find_tag_groups, found tag group - #{e.name} #{e.entities[0].text}" + str
        end
    end

    def erase_tag_groups(definition)
        Trk.traverse_for_groups(definition, "tag") do |path|
            e = path[path.length-1]
            t = e.entities[0]
            puts "erase_tag_groups, erasing tag = #{t.text} "
            path[path.length-2].entities.erase_entities(e) 
        end
    end

    def current_definitions()
        puts "################################### current defininitions ###################"
        definitions = Sketchup.active_model.definitions
        definitions.each_with_index do |d,i|
            if !d.group?
                type = definitions.get_attribute("TrkDefinitionsAttrs", "definition_type")
                if type.nil?
                    type = " ----"
                end
                instance_count = d.count_instances
                puts sprintf("%4d name = %20s type = %20s instances %2d\n", i, d.name, type, 
                                 instance_count)
            end
        end
    end
    def remove_all_definitions
        definitions = Sketchup.active_model.definitions
        puts "remove_all_definitions, defifinitions.count =  #{definitions.count}"
        ret = UI.messagebox("Do you really want to remove all definitions from model?", 
                            MB_YESNO)
        if ret == IDNO
            return
        end
        defs = []
        definitions.each do |d| 
            if !d.group?
                puts "remove_all_definitions, definition name = #{d.name}"
                defs << d
            end
        end
        defs.each do |d|
            definitions.remove(d)
        end
        if definitions.count != 0
            puts "remove_all_definitions did not work, count = #{definitions.count}"
        end


    end

    def deactivate(view)
        puts          "######################## deactivate DefinitionManager #{Time.now.ctime}"
        dfltfil   = File.open(@defaults_filnam, "w+")
        @defaults.each_pair         { |k,v| dfltfil.puts "Default          #{k}    #{v}" }
        @definition_types.each_pair { |k,v| dfltfil.puts "DefinitionType   #{k}    #{v}" }
        dfltfil.close
    end

    def make_filenames(dirname)
        puts "make_filenames, dirname = #{dirname}"
        if !Dir.exist?(dirname) then return "" end
        Dir.chdir(dirname)
        fs = Dir['*.skp']
        fs.each_with_index do |f,i| 
            fb = File.basename(f, '.skp')
            ib = fb.index('~')
            if !ib.nil? then fs[i] = "" end
        end
        fnames = " "
        i = 0
        fs.each do |f|
            if f != ""
                if i == 0
                    fnames = f
                else
                    fnames += "|" + f
                end
                i += 1
            end
        end
        return fnames
    end

    def prompt_for_type(definition)
        type = definition.get_attribute("TrkDefinitionAttrs", "definition_type")
        if !type.nil?
            UI.messagebox("DefinitionManager-edit found existing definition_type = #{type}")
            ret = UI.messagebox("YES- Use it, NO - select new type, CANCEL - Bail out",
                                MB_YESNOCANCEL)
            if ret == IDCANCEL 
                raise RuntimeError,  "Bail on prompt_for_type"
            elsif ret == IDYES
                return type
            end
        end
        prompts = ["DefType"]
        defaults = [" "]
        deftypes = make_deftypes
        tlist    = [deftypes]
        title    = "Select Definition Type"
        results  = UI.inputbox(prompts, defaults, tlist, title)
        return results[0]
    end
    
    def make_edit_definition
        code = ""
        n    = 0
        @definition_types.each_pair do |key,value|
            if n == 0
                code << "\t\t if def_type == \"#{key}\"\n"
            else
                code << "\t\t elsif def_type == \"#{key}\"\n"
            end
            code << "\t\t\t #{value}(definition)\n"
            n += 1 
        end
        code << "\tend\n"
        return code
    end                

    def make_deftypes
        deftypes = " "
        i = 0
        @definition_types.each_key do |key|
            if i == 0
                deftypes = key
            else
                deftypes += "|" + key
            end
            i += 1
        end
        return deftypes
    end
end      # end of class DefinitionManager

if( not $draw_tracktool_definitionmanager_loaded)
    dmenu = UI.menu("Draw")
    dmenu.add_item("DefinitionManager") {
        Sketchup.active_model.select_tool DefinitionManager.new
    }
    $draw_tracktool_definitionmanager_loaded = true
end

class Definitions
    def initialize(filname=nil)
        if !filname.nil?
            path_n = File.expand_path(filname)
            path   = Sketchup.active_model.path
            puts "Definitions-initialize path = #{path}"
            puts "Definitions-initialize path = #{path_n}"

            if path != path_n
                Sketchup.active_model.close
                Sketchup.open_file(filname)
                path = Sketchup.active_model.path
            end
        end
        n = 0
        @definitions = Hash.new
        Sketchup.active_model.definitions.each_with_index do |d,i|
            if !d.group?
                @definitions[d.name] = d
            end
        end
    end

    def opts
        opts_ = " "
        n     = 0
        @definitions.each_key do |k|
            if n == 0
                opts_ = "#{k}"
            else
                opts_ = opts_ + "|#{k}"
            end
            n += 1
        end
        return opts_
    end
    def definition(defname)
        return @definitions[defname]
    end
    def remove(defname)
        ret = Sketchup.active_model.definitions.remove(@definitions[defname])
        if !ret
            result = UI.messagebox("Remove of #{definition.name} failed, exit?", 
                                   MB_YESNO)
            if result == ID_YES
                Sketchup.active_model.tools.pop_tool
            end
        else
            @definitions.delete defname
            puts "definitionmanager.do_action, remove succeeded for #{defname}"
            puts "definitionmanager.do_action, opts = #{@opts}"
        end
    end

    def rename_definition(defname)
        definition = @definitions[defname]
        title = "Rename Definition-#{defname}"
        results = UI.inputbox ["Name"], [""], [""], title
        new_name = results[0]
        if @definitions.keys.include? new_name
            ret = UI.messagebox("WARNING: New name existsin definitions, continue", MB_YESNO)
            if ret == IDNO
                raise RuntimeError, "new_name duplicates name of existing definition"
            end
        end
        definition.name= new_name
        if defname != new_name
            puts "rename_definition, name changed to #{defname}"
        end
    end

    def names
        return @definitions.keys
    end
end
