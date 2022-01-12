# frozen_string_literal: true

require "parser/current"
require "unparser"

require_relative "./rds/version"
require_relative "./ext/rds"

def block_ast(p, full: false)
  file, beg_line, beg_col = p.source_region
  code = File.read(file)
  ast = Parser::CurrentRuby.parse(code, file)
  node = find_block(ast, beg_line, beg_col)
  if node.nil?
    nil
  elsif full
    node
  else
    node.children[2]
  end
end

def find_block(node, beg_line, beg_col)
  if node.is_a?(Parser::AST::Node)
    if node.type == :block && node.location.begin.line == beg_line && node.location.begin.column == beg_col
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
