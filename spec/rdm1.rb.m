defmacro(:make_calibration) do |k, args|
  quasisyntax { [:calibration, unsyntax_splicing(args)] }
end

class Rdm1
  def self.make_a_calibration
    cal = make_calibration(2, :none, :ignore)
    cal
  end
end

