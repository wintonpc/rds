# frozen_string_literal: true

require "parser/current"
require "set"
require "binding_of_caller"
require "irb"
require "reline"

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

using SyntaxHelpers

class Asts
  @files_by_path = {}
  @blocks = {}
  @location_map = {}
  @mapped = {}
  @dumped_asts = []
  @debug = false

  class << self
    def for_block(file, line, column)
      puts "for_block #{File.basename(file, ".rb")}:#{line}:#{column}" if @debug
      file_ast = get(file)
      key = [file_ast.object_id, line, column]
      @blocks.get_or_add(key) do
        ast = find_block(file_ast, line, column)
        puts "[#{ast.object_id}] #{ast_text(ast)}" if @debug
        ast
      end
    end

    def eval(ast, binding=nil)
      observe(ast)
      puts "eval #{ast.object_id}" if @debug
      binding ||= self.binding.of_caller(1)
      ast2, code = map(ast)
      @files_by_path[ast_file(ast2)] = ast2
      Kernel.eval(code, binding, ast_file(ast2))
    end

    # Find the corresponding node in the AST that node was sourced from, through Asts.eval. See loc_spec.rb
    def parent(node)
      ast_file(node).start_with?("ast#") or return nil
      key = loc_key(node) or return nil
      mapped = @location_map[key] or return nil
      file, line, column = mapped

      full = get(file)
      possibles = find_possible_parents(full, line, column)
      possibles.first
    end

    def find_possible_parents(ast, beg_line, beg_col)
      return [] unless ast.is_a?(Parser::AST::Node)
      key = loc_key(ast)
      this_one = (key && key[1] == beg_line && key[2] == beg_col && key[3] == ast.type) ? [ast] : []
      this_one + ast.children.flat_map { |c| find_possible_parents(c, beg_line, beg_col) }.reject(&:nil?)
    end

    def observe(ast)
      if @debug && !@dumped_asts.include?(ast.object_id)
        @dumped_asts.push(ast.object_id)
        puts "[#{ast.object_id}] #{ast_text(ast)}"
      end
      ast
    end

    def dump_location_map
      @location_map.each do |(fa, la, ca), (fb, lb, cb)|
        puts "#{File.basename(fa, ".rb")}:#{la}:#{ca} => #{File.basename(fb, ".rb")}:#{lb}:#{cb}"
      end
    end

    private

    def get(path)
      @files_by_path.get_or_add(path) do
        code = path.start_with?("irb\#") ? $irbs[path] : File.read(path)
        parse(code, path)
      end
    end

    def map(ast)
      # need object_id because AST::Node#hash is a function of content and excludes location
      @mapped.get_or_add(ast.object_id) do
        code = unparse(ast)
        ast2 = parse(code, "ast##{ast.object_id}")
        do_map(ast, ast2)
        [ast2, code]
      end
    end

    def do_map(a, b)
      return unless a.is_a?(Parser::AST::Node)
      k = loc_key(b)
      v = loc_key(a)

      if k && v && k != v
        existing = @location_map[k]
        if existing && existing != v
          if existing.take(3) == v.take(3) && existing.last == :send && v.last == :lvar
            puts "map #{k} => #{v} (remap send => lvar)" if @debug
            @location_map[k] = v
          else
            puts "Would have mapped #{k} to #{v} but already mapped to #{existing}"
          end
        else
          puts "map #{k} => #{v}" if @debug
          @location_map[k] = v
        end
      end
      a.children.zip(b.children, &method(:do_map))
    end

    def loc_key(n)
      # It is important to use b.location.begin.column for block nodes because it matches what
      # Proc#source_region returns. It's ok to use ast_begin_column for other nodes that may not have
      # b.location.begin.column because they are not correlated to Proc#source_region but only used for mapping
      # between ASTs.
      if !n.location.expression
        nil
      elsif n.respond_to?(:begin) && n.location.begin
        [ast_file(n), ast_begin_line(n), n.location.begin.column, n.type]
      else
        [ast_file(n), ast_begin_line(n), ast_begin_column(n), n.type]
      end
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

def parse(code, file)
  Parser::CurrentRuby.parse(code, file)
end

def unparse(ast)
  Unparser.unparse(ast)
end

$irbs = {} # TODO

def block_ast(p, full: false)
  file, beg_line, beg_col = p.source_region
  if file == IRB.CurrentContext&.irb_path
    file = "irb\##{$irbs.size}"
    beg_line = 1
    $irbs[file] = Reline::HISTORY[-1]
  end
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
  Asts.observe(do_unsyntax(block_ast(block), block.binding)[0])
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
  in [:send, [:send, nil, :unsyntax | :_u, expr], :_=, rhs]
    var = case go.(expr, -1, splice: true)
    in [:send, nil, x] then x
    in [:lvar, x] then x
    in [:sym, x] then x
    end
    rhs = case do_unsyntax(rhs, b, hint, depth)
    in [e] then e
    in [*es] then Parser::AST::Node.new(:begin, es, location: rhs.location)
    end
    [Parser::AST::Node.new(:lvasgn, [var, rhs], location: hint.location)]
  in [:send, nil, :unsyntax_splicing | :_us, expr]
    go.(expr, -1, splice: true)
  in [:optarg, _, [:send, nil, :unsyntax_splicing | :_us, expr]]
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
  in [:block, [:send, nil, :quasisyntax | :_q => q] => sendq, [:args] => a, expr]
    expr2 = do_unsyntax(expr, b, hint, depth + 1)[0]
    [Parser::AST::Node.new(:block,
      [Parser::AST::Node.new(:send, [nil, q], location: sendq.location),
        Parser::AST::Node.new(:args, [], location: a.location),
        expr2],
      location: x.location)]
  in [:send, [:send, nil, var], :_=, expr]
    do_unsyntax(Parser::AST::Node.new(:lvasgn, var, expr), b, hint, depth)
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

def unsyntax(x)
  block_given? ? yield : x
end

alias _s syntax
alias _q quasisyntax
alias _u unsyntax

def evals(s)
  Asts.eval(s, binding.of_caller(1))
end

def define_syntax(name, &transform)
  define_method(name) do |*_, &block|
    stx = block_ast(block, full: true)
    stx2 = transform.(stx)
    Asts.eval(stx2, block.binding)
  end
end
