defmacro(:defproto) do |_, args|
  type, *fields = args
  quasisyntax do
    defmacro(unsyntax(:"make_#{syntax_to_datum(type)}")) do |k, args|
      args[0] => [:kwargs, *pairs]
      array_args = pairs.map do |arg|
        arg => [:pair, [:sym, field], value]
        [field, value]
      end.to_h.values_at(unsyntax_splicing(fields))
      quasisyntax { [unsyntax(unsyntax(type)), unsyntax_splicing(array_args)] }
    end
    unsyntax_splicing(
      fields.each_with_index.map do |f, fi|
        quasisyntax do
          defmacro(unsyntax(:"#{syntax_to_datum(type)}_#{syntax_to_datum(f)}")) do |k, args|
            arr = args[0]
            quasisyntax do
              unsyntax(arr)[unsyntax(unsyntax(fi) + 1)]
            end
          end
        end
      end
    )
    unsyntax_splicing(
      fields.each_with_index.map do |f, fi|
        quasisyntax do
          defmacro(unsyntax(:"set_#{syntax_to_datum(type)}_#{syntax_to_datum(f)}")) do |k, args|
            arr = args[0]
            val = args[1]
            quasisyntax do
              unsyntax(arr)[unsyntax(unsyntax(fi) + 1)] = unsyntax(val)
            end
          end
        end
      end
    )
  end
end

defproto(:calibration, :compound, :degree, :weighting, :origin)
defproto(:compound, :name)

def make_a_calibration
  d = 1
  cal = make_calibration(degree: d + 1, weighting: "none", origin: "ignore",
    compound: make_compound(name: "morphine"))
  set_calibration_degree(cal, calibration_degree(cal) + 1)
  cal
end
