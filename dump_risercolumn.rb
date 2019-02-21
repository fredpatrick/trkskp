
# Copyright 2018, Xylocomp Inc
#
# This extention provides tools for working with component definitions  in Sketchup model
require 'sketchup.rb'
require 'extensions.rb'
require 'langhandler.rb'

class DumpRiserColumn
    def initialize
    end
    def activate

        Sketchup.active_model.entities.each do |g|
            if g.is_a? Sketchup::Group
                je = 0
                jf = 0
                g.entities.each do |e|
                    if e.is_a? Sketchup::Edge
                        puts "dump_risercolumn-edge #{je} #{point3d_to_s(e.start.position)} " +
                                                         "#{point3d_to_s(e.end.position)} "
                        je += 1
                    elsif e.is_a? Sketchup::Face
                        puts "dump_risercolumn-face #{jf} "
                        jf += 1
                        e.vertices.each_with_index { |v,j|
                                      puts "    #{j} #{point3d_to_s(v.position)} " }
                    end
                end
            end
        end
    end

    def point3d_to_s(p)
        return sprintf("%10.6f %10.6f %10.6f", p.x, p.y, p.z)
    end
end
