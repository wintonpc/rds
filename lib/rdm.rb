# frozen_string_literal: true

require "parser/current"
Parser::Builders::Default.emit_lambda              = true
Parser::Builders::Default.emit_procarg0            = true
Parser::Builders::Default.emit_encoding            = true
Parser::Builders::Default.emit_index               = true
Parser::Builders::Default.emit_arg_inside_procarg0 = true
Parser::Builders::Default.emit_forward_arg         = true
Parser::Builders::Default.emit_kwargs              = true
Parser::Builders::Default.emit_match_pattern       = true

$transformers = {}

class Rdm
  class << self
    def expand!(path)
      child_pid = fork do
        do_expand(path)
        exit(0)
      end
      Process.waitpid(child_pid)
    end

    def do_expand(path)
      File.write(path.sub(/\.m$/, ""), File.read(path))
    end
  end
end

module Kernel
  def require_relative_expand(path)
    rel_path = File.expand_path(path, File.dirname(caller[0].split(":")[0]))
    Rdm.expand!(rel_path +  + ".rb.m")
    require_relative(rel_path)
  end
end
