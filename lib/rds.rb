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
  do_unsyntax(remove_special_constructs(block_ast(block)), block.binding)[0]
end

def remove_special_constructs(x)
  case x
  in [:send, nil, :_case, subject, *cases]
    real_cases = cases.map do |c|
      c => [:block, [:send, nil, :_, [:begin, [:match_pattern_p, _, pat]]], _, expr]
      Parser::AST::Node.new(:in_pattern, [pat, nil, remove_special_constructs(expr)], location: c.location)
    end
    Parser::AST::Node.new(:case_match, [subject, *real_cases, nil], location: x.location)
  in [type, *children]
    Parser::AST::Node.new(type, children.map { |c| remove_special_constructs(c) }, location: x.location)
  else
    x
  end
end

def do_unsyntax(x, b, hint=x, depth=0)
  return x unless x.is_a?(Parser::AST::Node)

  go = lambda do |expr, level, eval: true, splice: false|
    result =
      if depth == 0 && eval
        datum_to_syntax(Asts.eval(expr, b), hint)
      else
        flat_map_children(x) { |c| do_unsyntax(c, b, hint, depth + level) }
      end
    splice ? result : [result]
  end

  case x
  in [:send, nil, :unsyntax | :_u, expr]
    go.(expr, -1)
  in [:block, [:send, nil, :unsyntax | :_u], [:args], expr]
    go.(expr, -1)
  in [:send, nil, :unsyntax_splicing | :_us, expr]
    go.(expr, -1, splice: true)
  in [:block, [:send, nil, :unsyntax_splicing | :_us], [:args], expr]
    go.(expr, -1, splice: true)
  in [:hash_pattern, [:pair, [:sym, :unsyntax], [:pin, expr]]]
    go.(expr, -1)
  in [:when, [:send, nil, :case_unsyntax_splicing, expr], nil]
    go.(expr, -1, splice: true)
  in [:kwoptarg, name, expr] if name.match(/^(unsyntax_splicing|_us)/)
    r = go.(expr, -1, splice: true)
    depth == 0 ? reorder_args(r) : r
  in [:kwoptarg, name, expr] if name.match(/^(unsyntax|_u)/)
    go.(expr, -1, splice: true)
  in [:block, [:send, nil, :quasisyntax | :_q], *_]
    go.(expr, 1, eval: false)
  else
    go.(expr, 0, eval: false)
  end
end

def reorder_args(args_stx)
  gs = args_stx.group_by(&:type)
  get = proc { |type| gs.delete(type) || [] }
  get.(:arg) + get.(:optarg) + get.(:kwarg) + get.(:kwoptarg) + gs.values.flat_map(&:itself)
end

def flat_map_children(node, &block)
  Parser::AST::Node.new(node.type, node.children.flat_map(&block), location: node.location)
end

def datum_to_syntax(x, hint)
  if x.is_a?(Integer)
    Parser::AST::Node.new(:int, [x], location: hint.location)
  elsif x.is_a?(Symbol)
    Parser::AST::Node.new(:sym, [x], location: hint.location)
  elsif x.is_a?(String)
    Parser::AST::Node.new(:str, [x], location: hint.location)
  elsif x.nil?
    Parser::AST::Node.new(:nil, [], location: hint.location)
  elsif x == false
    Parser::AST::Node.new(:false, [], location: hint.location)
  elsif x.is_a?(Parser::AST::Node) || x.is_a?(Array)
    x
  else
    raise "datum_to_syntax TODO: #{x.inspect}"
  end
end

def syntax_to_datum(stx)
  stx.children[0]
end

alias _s syntax
alias _q quasisyntax

def define_syntax(name, &transform)
  define_method(name) do |*_, &block|
    stx = block_ast(block, full: true)
    stx2 = transform.(stx)
    Asts.eval(stx2, block.binding)
  end
end
