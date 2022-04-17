module SyntaxHelpers
  refine Object do
    private
    def n(type, *children)
      Parser::AST::Node.new(type, children)
    end
  end
end
