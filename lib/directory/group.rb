module Directory
  
  # Represents a group of users.
  class Group
    
    # Represents an email address group member.
    class Mail < Struct.new(:mail)
      def name() mail end
    end
    
    # Find all groups.
    def self.all
      return Directory.connection.all_groups.map { |entry| new(entry) }
    end
    
    # Find a group by groupname.
    def self.find(name)
      Directory.connection.find_group_by_cn(name) do |entry|
        return new(entry)
      end
      return false
    end
    
    def self.find_by_mail(mail)
      name, domain = mail.split('@')
      if domain == Directory.connection.base.split(/,?dc=/)[1..-1].join('.')
        Directory.connection.find_group_by_cn(name) do |entry|
          return new(entry)
        end
      end
      return false
    end
    
    # Find all groups with the given username as a group member.
    def self.find_by_member(username)
      return Directory.connection.find_groups_by_member_uid(username).map { |entry| new(entry) }
    end
    
    # Find all groups matching a simple query.
    def self.search(query)
      return Directory.connection.find_groups_by_match(query).map { |entry| new(entry) }
    end
    
    attr_reader :dn, :groupname, :name, :long_description, :mail_aliases
    
    def initialize(entry)
      @dn = entry[:dn].first
      @groupname = entry[:cn].first
      @name = entry[:description].first
      @long_description = (entry[:meetlongdescription].first || '').split(' $ ').join("\n")
      @members = nil
      @member_uids = entry[:memberuid]
      @mail_aliases = entry[:meetalias]
    end
    
    def members
      @members ||= @member_uids.map { |id| User.find(id) || Group.find_by_mail(id) || Mail.new(id) }
    end
    
    def mail
      "#{groupname}@#{dn.split(',dc=')[1..-1].join('.')}"
    end
    
    # ActiveRecord methods
    
    def self.model_name
      ActiveModel::Name.new(self)
    end
    
    def to_s
      groupname
    end
    
    def as_json(options = nil)
      { :groupname => groupname, :name => name }
    end
    
  end
  
end
