require 'sketchup.rb'
$trkdir = "/Users/fredpatrick/wrk/trkskp"
require "#{$trkdir}/trk.rb"

class ExamineDefinitions
    def initialize
        puts "examinedefinitions.initialize"
        puts "################################################################"
        puts "####################################### Definitions"
        puts "####################################### #{Time.now.ctime}"
        $logfile.puts "################################################################"
        $logfile.puts "####################################### Definitions"
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
        @menu_def = false
    end

    def onSetCursor
        if @cursor_id
            UI.set_cursor(@cursor_id)
        end
    end

    def activate
        $logfile.puts "########################## activate Definitions #{Time.now.ctime}"
        puts          "########################## activate Definitions #{Time.now.ctime}"
        @ip = Sketchup::InputPoint.new
        @menu_flg = false
        @ptLast = Geom::Point3d.new 1000, 1000, 1000
        @state = "starting"
        make_context_menu
    end

    def deactivate(view)
        $logfile.puts "######################## deactivate Definitions #{Time.now.ctime}"
        puts          "######################## deactivate Definitions #{Time.now.ctime}"
        $logfile.flush
    end

    def make_context_menu
        def getMenu(menu)
            puts "EditRiserBase.getMenu - @state = #{@state}, " + 
                            "@filename = #{@filename}"
            if @definition
                puts "                  @definition.name = #{@definition.name}"
            else
                puts "                  no definition selected"
            end
            select_file_id = menu.add_item("Select File") {
                target_dir = "/Users/fredpatrick/wrk/skp/RiserComponents"
                @filename = Trk.select_file(target_dir)
                @state = "have_file"
                puts "Select File, @state #{@state}, @filename = #{@filename}, " +
                               "active_model = #{Sketchup.active_model.name}"
                @definition = nil
            }
            select_def_id = menu.add_item("Select Definition") {
                @definition = Trk.select_definition
                if @definition
                    @state = "have_definition"
                else
                    @state = "starting"
                    @definition = nil
                end
            }
            remove_def_id = menu.add_item("Remove Definition") {
                result = UI.messagebox("Do you really want to remove #{@definition}?", MB_YESNO)
                if result == IDYES
                    definitions = Sketchup.active_model.definitions
                    definitions.remove(@definition)
                    @definition = nil
                end
            }
            instance_id = menu.add_item("Create Instance") {
                xform_ident = Geom::Transformation.new
                Sketchup.active_model.add_instance(@definition, xform_ident)
                definitions = Sketchup.active_model.definitions
                puts "EditRiserBase, #{@definition}, " +
                                    "count_instances = #{definitions.count_instances}"
                @state = "have_definition"
            }
            dump_id = menu.add_item("Dump") {
                puts Trk.definition_to_s(@definition, 1)
                @state = "have_definition"
            }
            next_def_id = menu.add_item("Get Definition") {
                @state = "have_file"
                @definition = nil
            }

            if @state == "starting"
                menu.set_validation_proc(select_file_id) {MF_ENABLED}
                menu.set_validation_proc(select_def_id)  {MF_GRAYED}
                menu.set_validation_proc(remove_def_id)  {MF_GRAYED}
                menu.set_validation_proc(instance_id)    {MF_GRAYED}
                menu.set_validation_proc(dump_id)        {MF_GRAYED}
                menu.set_validation_proc(next_def_id)    {MF_GRAYED}
            elsif @state == "have_file"
                menu.set_validation_proc(select_file_id) {MF_GRAYED}
                menu.set_validation_proc(select_def_id)  {MF_ENABLED}
                menu.set_validation_proc(remove_def_id)  {MF_GRAYED}
                menu.set_validation_proc(instance_id)    {MF_GRAYED}
                menu.set_validation_proc(dump_id)        {MF_GRAYED}
                menu.set_validation_proc(next_def_id)    {MF_GRAYED}
            elsif @state == "have_definition"
                menu.set_validation_proc(select_file_id) {MF_GRAYED}
                menu.set_validation_proc(select_def_id)  {MF_GRAYED}
                menu.set_validation_proc(remove_def_id)  {MF_ENABLED}
                menu.set_validation_proc(instance_id)    {MF_ENABLED}
                menu.set_validation_proc(dump_id)        {MF_ENABLED}
                menu.set_validation_proc(next_def_id)    {MF_ENABLED}
            end
            @menu_def = true
        end
    end

end

if( not $draw_definitions )
    add_separator_to_menu("Draw")
    dmenu = UI.menu("Draw")
    dmenu.add_item("Definitions") {
        Sketchup.active_model.select_tool(ExamineDefinitions.new)
    }
    $draw_definitions_loaded = true
end
