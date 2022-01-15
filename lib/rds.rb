# frozen_string_literal: true

require "parser/current"

require_relative "./rds/version"
require_relative "./rds/helpers"
require_relative "./ext/rds"

class AstCache
  @asts_by_path = {}
  def self.get(path)
    @asts_by_path.fetch(path) do
      @asts_by_path[path] = Parser::CurrentRuby.parse(File.read(path), path)
    end
  end
end

def block_ast(p, full: false)
  file, beg_line, beg_col = p.source_region
  ast = AstCache.get(file)
  node = find_block(ast, beg_line, beg_col)
  if node.nil?
    raise "Couldn't find AST for #{p}"
  elsif full
    node
  else
    node.children[2]
  end
end

def find_block(node, beg_line, beg_col)
  return nil unless node.is_a?(Parser::AST::Node)
  if node.type == :block && ast_begin_line(node) == beg_line && node.location.begin.column == beg_col
    node
  else
    node.children.lazy.map { |c| find_block(c, beg_line, beg_col) }.reject(&:nil?).first
  end
end

def eval_ast(ast, binding)
  # be careful to propagate source location
  code = (" " * ast_begin_column(ast)) + ast_text(ast) # can't pass column to eval so fake it
  eval(code, binding, ast_file(ast), ast_begin_line(ast))
end
