module Directory
  
  # Mock LDAP backend.
  class MockLDAP
    
    # Represents a single attribute change operation.
    Change = Struct.new(:dn, :attribute, :value)
    
    @@bind_mocks = {}
    @@dn_mocks = {}
    @@base_mocks = {}
    @@changes = []
    
    def initialize(args = {})
      @args = args
    end
    
    # Add a mock username and password pair for binding.
    def mock_bind(uid, password)
      @@bind_mocks["uid=#{uid},ou=users,#{@args[:base]}"] = password
    end
    
    # Add a mock user.
    def mock_user(args)
      mock_entry("uid=#{args[:uid]},ou=users,#{@args[:base]}", args)
    end
    
    # Add a mock group.
    def mock_group(args)
      mock_entry("cn=#{args[:cn]},ou=groups,#{@args[:base]}", args)
    end
    
    # Add a mock app.
    def mock_app(args)
      mock_entry("ou=#{args[:ou]},ou=apps,#{@args[:base]}", args)
    end
    
    # Add a mock new user.
    def mock_new_user(args)
      mock_entry("cn=#{args[:cn]},ou=newusers,#{@args[:base]}", args)
    end
    
    # Remove all mock entries.
    def clear_mocks
      @@bind_mocks.clear
      @@dn_mocks.clear
      @@base_mocks.clear
    end
    
    # Obtain a list of changes to mock entries.
    def changes
      @@changes
    end
    
    # Clear the list of changes.
    def clear_changes
      @@changes.clear
    end
    
    # Net::LDAP methods
    
    def base
      @args[:base]
    end
    
    def bind(args)
      return @@bind_mocks[args[:username]] == args[:password]
    end
    
    def search(args = {})
      results = []
      if args[:scope] and args[:scope] == Net::LDAP::SearchScope_BaseObject
        # retrieve mock entry by DN
        results = [ @@dn_mocks[args[:base]] ]
      else
        args[:filter].execute do |operation, attribute, value|
          if not @@base_mocks[args[:base]]
            # no mock entries under this search base
            results = []
          elsif operation == :present
            # retrieve all under search base, filter later
            results = @@base_mocks[args[:base]][:all] || []
          elsif operation == :equalityMatch
            # retrieve by search base and filter
            results = @@base_mocks[args[:base]][args[:filter].to_s] || []
          end
        end
      end
      if args[:filter]
        args[:filter].execute do |operation, attribute, value|
          if operation == :present
            results.reject! { |result| result[attribute.to_sym].empty? }
          end
        end
      end
      if block_given?
        results.each { |result| yield result }
      end
      return results
    end
    
    def add(args)
      mock_entry(args[:dn], args[:attributes])
      record_change(args[:dn], :dn, args[:dn])
      args[:attributes].each do |key, value|
        record_change(args[:dn], key, value.is_a?(Array) ? value : [ value ])
      end
    end
    
    def delete(args)
      @@dn_mocks.delete(args[:dn])
      @@base_mocks.each do |base, mocks|
        mocks.each do |filter, entries|
          entries.delete_if { |entry| entry[:dn] == args[:dn] }
        end
      end
      record_change(args[:dn], :dn, nil)
    end
    
    def add_attribute(dn, attribute, value)
      @@dn_mocks[dn][attribute] += value.is_a?(Array) ? value : [ value ]
      record_change(dn, attribute, @@dn_mocks[dn][attribute])
    end
    
    def delete_attribute(dn, attribute)
      @@dn_mocks[dn].delete(attribute)
      record_change(dn, attribute, nil)
    end
    
    def replace_attribute(dn, attribute, value)
      @@dn_mocks[dn][attribute] = value.is_a?(Array) ? value : [ value ]
      record_change(dn, attribute, @@dn_mocks[dn][attribute])
    end
    
    private
      
      # Add a mock entry.
      def mock_entry(dn, args)
        entry = Hash.new([])
        args.each do |key, value|
          entry[key] = value.is_a?(Array) ? value : [ value ]
        end
        entry[:dn] = [ dn ]
        
        # store mock entries by DN
        @@dn_mocks[dn] = entry
        
        base = dn.split(',', 2)[1]
        @@base_mocks[base] ||= {}
        # store by search base
        (@@base_mocks[base][:all] ||= []) << entry
        
        args.each do |key, value|
          (value.is_a?(Array) ? value : [ value ]).each do |value|
            # and store by search base and equality filter
            (@@base_mocks[base]["(#{key}=#{value})"] ||= []) << entry
          end
        end
      end
      
      # Record a mock entry change.
      def record_change(dn, attribute, value)
        @@changes.reject! { |change| change.dn == dn and change.attribute == attribute }
        @@changes << Change.new(dn, attribute, value)
      end
      
  end
  
end
