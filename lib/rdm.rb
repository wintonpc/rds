# frozen_string_literal: true

require "unparser"
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
    def expand!(m_path, rb_path)
      begin
        load(m_path)
      rescue => e
        puts e
      end
      File.write(rb_path, Unparser.unparse(expand(Parser::CurrentRuby.parse(File.read(m_path), m_path))))
    end

    def expand(node)
      case node
      in Parser::AST::Node[:send, nil, ident, *args] if $transformers.keys.include?(ident)
        result = $transformers[ident].(ident, args)
        result
      in Parser::AST::Node[type, *children]
        Parser::AST::Node.new(type, children.map { |c| expand(c) }, location: node.location)
      else
        node
      end
    end
  end
end

module Kernel
  def require_relative_expand(path)
    rel_path = File.expand_path(path, File.dirname(caller[0].split(":")[0]))
    rb_path = rel_path + ".rb"
    m_path = rb_path + ".m"
    child_pid = fork do
      Rdm.expand!(m_path, rb_path)
      exit(0)
    end
    Process.waitpid(child_pid)
    $?.exitstatus == 0 or raise "require_relative_expand #{path} failed"
    require_relative(rel_path)
    # File.delete(rb_path)
  end

  def defmacro(name, &transformer)
    $transformers[name] = transformer
  end
end
