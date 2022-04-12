defmacro(:make_calibration1) do |k, args|
  quasisyntax { [:calibration, unsyntax_splicing(args)] }
end

defmacro(:make_calibration2) do |k, args|
  args[0] => [:kwargs, *pairs]
  array_args = pairs.map do |arg|
    arg => [:pair, [:sym, field], value]
    [field, value]
  end.to_h.values_at(:degree, :weighting, :origin)
  quasisyntax { [:calibration, unsyntax_splicing(array_args)] }
end

def make_a_calibration1
  make_calibration1(2, "none", "ignore")
end

def make_a_calibration2
  make_calibration2(degree: 2, weighting: "none", origin: "ignore")
end

