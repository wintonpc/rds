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
  node =
  if $eval_ast
    # beg_line and beg_col are relative to $eval_str
    eval_ast2 = Parser::CurrentRuby.parse($eval_str)
    inner = find_block_line_col(eval_ast2, beg_line, beg_col)
    # use the offset of $eval_ast and eval_ast2 to find the original ast with true location info corresponding to inner
    abs_begin_pos = $eval_ast.location.expression.begin_pos + inner.location.expression.begin_pos
    find_block_offset($eval_ast, abs_begin_pos)
  else
    ast = AstCache.get(file)
    find_block_line_col(ast, beg_line, beg_col)
  end
  if node.nil?
    nil
  elsif full
    node
  else
    node.children[2]
  end
end

def find_block_line_col(node, beg_line, beg_col)
  if node.is_a?(Parser::AST::Node)
    if node.type == :block && node.location.begin.line == beg_line && node.location.begin.column == beg_col
      return node
    else
      node.children.each do |c|
        found = find_block_line_col(c, beg_line, beg_col)
        return found if found
      end
    end
  end
  nil
end

def find_block_offset(node, offset)
  if node.is_a?(Parser::AST::Node)
    if node.type == :block && node.location.expression.begin_pos == offset
      return node
    else
      node.children.each do |c|
        found = find_block_offset(c, offset)
        return found if found
      end
    end
  end
  nil
end

def eval_ast(ast, binding)
  old_eval_ast = $eval_ast
  old_eval_str = $old_eval_str
  $eval_ast = ast
  $eval_str = ast_text(ast)
  eval($eval_str, binding)
ensure
  $eval_ast = old_eval_ast
  $eval_str = old_eval_str
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
