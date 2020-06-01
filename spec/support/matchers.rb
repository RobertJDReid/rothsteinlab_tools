RSpec::Matchers.define :permit do |*args|
  match do |permission|
    permission.permit?(*args).should be_true
  end
end

RSpec::Matchers.define :permit_param do |*args|
  match do |permission|
    permission.permit_param?(*args).should be_true
  end
end
