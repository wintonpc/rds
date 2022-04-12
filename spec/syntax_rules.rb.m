defmacro(:syntax_rules) do |_, args, body|
  case body
  in [:case, _, *cases, else_case]
    cases
  end
end
