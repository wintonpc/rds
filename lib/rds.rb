# frozen_string_literal: true

require "parser/current"
require "set"
require "binding_of_caller"

require_relative "./rds/version"
require_relative "./rds/helpers"
require_relative "./ext/rds"

Parser::Builders::Default.emit_lambda              = true
Parser::Builders::Default.emit_procarg0            = true
Parser::Builders::Default.emit_encoding            = true
Parser::Builders::Default.emit_index               = true
Parser::Builders::Default.emit_arg_inside_procarg0 = true
Parser::Builders::Default.emit_forward_arg         = true
Parser::Builders::Default.emit_kwargs              = true
Parser::Builders::Default.emit_match_pattern       = true

class Asts
  @asts_by_path = {}
  @location_map = {}
  @mapped = {}
  @found = {}

  class << self
    def for_block(file, line, column)
      if file.start_with?("ast#")
        for_block(*@location_map[[file, line, column]])
      else
        ast = get(file)
        key = [ast.object_id, line, column]
        @found.fetch(key) { @found[key] = find_block(ast, line, column) }
      end
    end

    def eval(ast, binding=nil)
      binding ||= self.binding.of_caller(1)
      ast2, code = map(ast)
      Kernel.eval(code, binding, ast_file(ast2))
    end

    private

    def get(path)
      @asts_by_path.fetch(path) do
        @asts_by_path[path] = Parser::CurrentRuby.parse(File.read(path), path)
      end
    end

    def map(ast)
      code = Unparser.unparse(ast)
      # need object_id because AST::Node#hash is a function of content and excludes location
      @mapped.fetch(ast.object_id) do
        @mapped[ast] = begin
          ast2 = Parser::CurrentRuby.parse(code, "ast##{ast.object_id}")
          do_map(ast, ast2)
          [ast2, code]
        end
      end
    end

    def do_map(a, b)
      return unless a.is_a?(Parser::AST::Node)
      if a.type == :block
        # use b.location.begin.column rather than ast_begin_column because it matches what Proc#source_region returns
        @location_map[[ast_file(b), ast_begin_line(b), b.location.begin.column]] =
          [ast_file(a), ast_begin_line(a), a.location.begin.column]
      end
      a.children.zip(b.children, &method(:do_map))
    end

    def find_block(ast, beg_line, beg_col)
      return nil unless ast.is_a?(Parser::AST::Node)
      if ast.type == :block && ast_begin_line(ast) == beg_line && ast.location.begin.column == beg_col
        ast
      else
        ast.children.lazy.map { |c| find_block(c, beg_line, beg_col) }.reject(&:nil?).first
      end
    end
  end
end

def block_ast(p, full: false)
  file, beg_line, beg_col = p.source_region
  node = Asts.for_block(file, beg_line, beg_col)
  if node.nil?
    raise "Couldn't find AST for #{p}"
  elsif full
    node
  else
    node.children[2]
  end
end

def syntax(&block)
  block_ast(block)
end

def quasisyntax(&block)
  do_unsyntax(block_ast(block), block.binding)
end

def do_unsyntax(x, b, hint=x)
  return x unless x.is_a?(Parser::AST::Node)
  case x
  in [:send, nil, :unsyntax | :_u, expr]
    [datum_to_syntax(Asts.eval(expr, b), hint)]
  in [:block, [:send, nil, :unsyntax | :_u], [:args], expr]
    [datum_to_syntax(Asts.eval(expr, b), hint)]
  in [:send, nil, :unsyntax_splicing | :_us, expr]
    datum_to_syntax(Asts.eval(expr, b), hint)
  in [:block, [:send, nil, :unsyntax_splicing | :_us], [:args], expr]
    datum_to_syntax(Asts.eval(expr, b), hint)
  else
    Parser::AST::Node.new(x.type, x.children.flat_map { |c| do_unsyntax(c, b, hint) }, location: x.location)
  end
end

def datum_to_syntax(x, hint)
  if x.is_a?(Integer)
    Parser::AST::Node.new(:int, [x], location: hint.location)
  elsif x.is_a?(Symbol)
    Parser::AST::Node.new(:sym, [x], location: hint.location)
  else
    x
  end
end

alias _s syntax
alias _q quasisyntax

def define_syntax(name, &transform)
  define_method(name) do |*_, &block|
    stx = block_ast(block, full: true)
    puts "in (#{stx.object_id}):\n#{ast_text(stx)}"
    stx2 = transform.(stx)
    puts "out:\n#{ast_text(stx2)}"
    Asts.eval(stx2, block.binding)
  end
end
