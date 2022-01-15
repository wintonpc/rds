# frozen_string_literal: true

require "parser/current"
require "unparser"

require_relative "./rds/version"
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
  if node.is_a?(Parser::AST::Node)
    if node.type == :block && ast_begin_line(node) == beg_line && node.location.begin.column == beg_col
      return node
    else
      node.children.each do |c|
        found = find_block(c, beg_line, beg_col)
        return found if found
      end
    end
  end
  nil
end

def eval_ast(ast, binding)
  # be careful to propagate source location
  code = (" " * ast_begin_column(ast)) + ast_text(ast) # can't pass column to eval so fake it
  eval(code, binding, ast_file(ast), ast_begin_line(ast))
end

def ast_text(node)
  node.location.expression.source
end

def ast_file(node)
  node.location.expression.source_buffer.name
end

# 1-based
def ast_begin_line(ast)
  ast.location.expression.line
end

# 0-based
def ast_begin_column(ast)
  ast.location.expression.column
end

# 0-based
def ast_begin_char(ast)
  ast.location.expression.begin_pos
end

# 0-based
def ast_end_char(ast)
  ast.location.expression.end_pos
end
