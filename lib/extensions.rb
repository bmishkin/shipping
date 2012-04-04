
# this originally included a .zero? so that Numeric#blank? => true when zero.
# that breaks other rails gems...

unless Object.respond_to?(:blank?)
  class Object
    def blank?
     # exactly like in rails
     respond_to?(:empty?) ? empty? : !self
    end
  end
end