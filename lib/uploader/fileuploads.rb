module Uploader
  module Fileuploads
    def self.included(base)
      base.send :extend, SingletonMethods
    end
    
    module SingletonMethods
      # Join ActiveRecord object with uploaded file
      # Usage:
      # 
      #   class Article < ActiveRecord::Base
      #     has_one :picture, :as => :assetable, :dependent => :destroy
      #
      #     fileuploads :picture
      #   end
      #
      #
      def fileuploads(*args)
        options = args.extract_options!
        
        class_attribute :fileuploads_options, :instance_writer => false
        self.fileuploads_options = options
        
        class_attribute :fileuploads_columns, :instance_writer => false
        self.fileuploads_columns = args.map(&:to_sym)
        
        unless self.is_a?(ClassMethods)
          include InstanceMethods
          extend ClassMethods
          
          attr_accessible :fileupload_guid
          after_save :fileuploads_update, :if => :fileupload_changed?
          
          fileuploads_columns.each { |asset| accepts_nested_attributes_for asset, :allow_destroy => true }
        end
      end
    end
    
    module ClassMethods
      # Update reflection klass by guid
      def fileupload_update(record_id, guid, method)
        klass = fileupload_klass(method)
        klass.where(:assetable_type => name, :guid => guid).update_all(["assetable_id = ?, guid = ?", record_id, nil])
      end
      
      # Find asset by guid
      def fileupload_find(method, guid)
        klass = fileupload_klass(method)
        klass.where(:guid => guid).first
      end
      
      # Find class by reflection
      def fileupload_klass(method)
        reflections[method.to_sym].klass
      end
    end
    
    module InstanceMethods
      # Generate unique key
      def fileupload_guid
        @fileupload_guid ||= Uploader.guid
      end
      
      def fileupload_guid=(value)
        @fileupload_changed = true unless value.blank?
        @fileupload_guid = value.blank? ? nil : value
      end
      
      def fileupload_changed?
        @fileupload_changed === true
      end
      
      def fileupload_multiple?(method)
        association = self.class.reflect_on_association(method)
        association && association.collection? 
      end
      
      # Find or build new asset object
      def fileupload_asset(method)
        if fileuploads_columns.include?(method.to_sym)
          asset = new_record? ? self.class.fileupload_find(method, fileupload_guid) : send(method)
          asset ||= send("build_#{method}") if respond_to?("build_#{method}")
          asset
        end
      end
      
      def fileuploads_columns
        self.class.fileuploads_columns
      end
      
      protected
      
        def fileuploads_update
          fileuploads_columns.each do |method|
            self.class.fileupload_update(id, fileupload_guid, method)
          end
        end
    end
  end
end
