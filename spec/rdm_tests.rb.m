require_relative_expand "syntax_rules"

#region or
defmacro(:or2,
  syntax_rules do
    case
    when []
      false
    when [e1, e2 ...]
      t = e1
      if t
        t
      else
        or2(e2 ...)
      end
    end
  end
)

add_test "or2" do
  x = or2(false, 2, 3 + raise("oops"))
  expect(x).to eql 2
end
#endregion

#region let
defmacro(:let2,
  syntax_rules do
    case
    when [{v => e} ..., body]
      (lambda { |_=(v...)| body }).(e ...)
    end
  end
)

add_test "let2" do
  d = 5
  x = let2(a: 1, b: 1 + 1) do
    c = 4
    [a + 1, b + 1, c, d]
  end
  expect(x).to eql [2, 3, 4, 5]
  expect { c }.to raise_error NameError
end
#endregion

#region kvflatten
defmacro(:kvflatten,
  syntax_rules do
    case
    when [x, {v => e} ...]
      [v ..., e ..., x]
    end
  end
)

add_test "kvflatten" do
  x = kvflatten(3, a: 1, b: 1 + 1)
  expect(x).to eql [:a, :b, 1, 2, 3]
end
#endregion
