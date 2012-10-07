# this represents a fixed object created from a template
module Hirsute
  class Fixed
      
      # though Hirsute can use set and get within itself, set also configures attribute accessors
      # for the specified field, thus allowing more user-friendly management of Hirsute objects
      def set(field,value)
         set_method = (field + "=").to_sym
         m = self.method((field + "=").to_sym)
         m.call value
      end
      
      def get(field); self.method(field.to_sym).call; end      
  end
end