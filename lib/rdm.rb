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
$debug_rdm = false

class Rdm
  class << self
    def expand!(inp, outp)
      puts "expand! #{inp}" if $debug_rdm
      begin
        puts "loading #{inp}" if $debug_rdm
        load(inp)
      rescue => e
        puts "Intermediate error: #{e}" if $debug_rdm
      end

      e_in = Parser::CurrentRuby.parse(File.read(inp), inp)
      e_out = expand(e_in)
      File.write(outp, do_unparse(e_out))
    end

    def expand(node)
      case node
      in Parser::AST::Node[:send, nil, ident, *args] if $transformers.keys.include?(ident)
        puts "expanding #{ident} #{node}" if $debug_rdm
        result = $transformers[ident].(ident, args)
        result
      in Parser::AST::Node[type, *children]
        Parser::AST::Node.new(type, children.map { |c| expand(c) }, location: node.location)
      else
        node
      end
    end

    def do_unparse(n)
      Unparser.unparse(n)
    rescue => e
      puts e
      debug_unparse(n)
      raise e
    end

    def debug_unparse(n)
      return unless n.is_a?(Parser::AST::Node)
      puts "debug_unparse #{n}" if $debug_rdm
      n.children.each do |c|
        begin
          Unparser.unparse(c)
        rescue Exception => e
          debug_unparse(c)
        end
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
      File.write(rb_path, file_fixed_point(m_path) { |inp, outp| Rdm.expand!(inp, outp) })
      exit(0)
    end
    Process.waitpid(child_pid)
    $?.exitstatus == 0 or raise "require_relative_expand #{path} failed"
    require_relative(rel_path)
  end

  private def file_fixed_point(inp)
    i = 1
    base = inp
    last_text = File.read(inp)
    temps = []
    loop do
      outp = "#{base}.#{i}"
      temps.push(outp)
      yield(inp, outp)
      text = File.read(outp)
      return text if text == last_text
      last_text = text
      i += 1
      inp = outp
    end
  ensure
    temps.each { |t| File.delete(t) }
  end

  def defmacro(name, &transformer)
    $transformers[name] = transformer
    puts "defined macro #{name}" if $debug_rdm
  end
end
