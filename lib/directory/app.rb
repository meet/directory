module Directory
  
  # Represents an application.
  class App
    
    # Find an app by URL.
    def self.find(url)
      Directory.new.find_app_by_url(url) do |entry|
        return new(entry)
      end
      return false
    end
    
    attr_reader :dn, :appname, :urls
    
    def initialize(entry)
      @dn = entry[:dn].first
      @appname = entry[:ou].first
      @urls = entry[:labeleduri]
    end
    
    # ActiveRecord methods
    
    def self.model_name
      ActiveModel::Name.new(self)
    end
    
    def to_s
      appname
    end
    
    def as_json(options = nil)
      { :appname => appname }
    end
    
  end
  
end
