class String
  def numeric?
    Float(self) != nil rescue false
  end
end

def roundNumber(number)
	return 0 if number == 0
	return "%.3E" % number if number.abs < 0.001
	return "%.3g" % number
end



# module Process
#   class Log
  	
#   end
# end