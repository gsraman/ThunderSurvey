require 'digest/sha1'
require 'net/http'
require 'uri'

class Form
  include ActiveModel::Validations
  
  include MongoMapper::Document
  include Authentication
  
  key :title, String, :required => true
  key :description, String
  key :user_id, String
  key :edit_key, String
  key :email_notify, Boolean, :default => true
  key :notify_url, String
  key :notify_type, String, :default => 'email'
  key :thanks_message, String, :default => "您的信息已成功提交！"
  key :maximum_rows, Integer
  key :height,Integer
  
  key :created_at, Time, :default => Time.now
  key :updated_at, Time, :default => Time.now
  
  many :fields, :default => 0
  
  validates :title, :presence => true
  validates :notify_email, :format => {:with => Authentication.email_regex}, :allow_blank => true
  
  before_create :make_edit_key
  before_save   :update_timestamps
  
  def id
    self._id.to_s
  end
  
  def user
    User.find(self.user_id)
  end
  
  def allow_insert?
    return true
  end
  
  def klass
    @klass ||= user_klass
  end
  
  def user_klass
    klass ||= Class.new
    klass.send(:include, MongoMapper::Document)
    klass.send(:include, ActiveModel::Validations)
    klass.send(:include, ActiveModel::Naming)
    klass.set_collection_name(self.id.to_s)
    klass.key "created_at", Time
    klass.key 'order_id',Integer #保存订单信息
    klass.class_eval <<-METHOD
      def id
        self._id.to_s
      end

      def persisted?
        !new_record?
      end
    METHOD

    klass.instance_eval <<-NAME
      def name
        'Row'
      end
    NAME
    
    self.fields.each do |field|
      klass.key "f#{field.id}", String
      klass.validates_presence_of "f#{field.id}".to_sym, :message => "#{field.name} 不能为空" if field.required
      klass.validates_format_of "f#{field.id}".to_sym, :message => ' 必须为email格式',:with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i if field.intern == 'email'
      
      if field.input == 'check'
        klass.class_eval <<-METHOD
          alias_method :old_f#{field.id}=, :f#{field.id}=
          def f#{field.id}=(choices)
            self.old_f#{field.id}= choices.is_a?(Array) ? choices.join(',') : choices
          end
        METHOD
      end
    end
    klass
  end
  
  def deliver_notification(row)
    case self.notify_type
    when 'email'
      deliver_email_notification(row)
    # when 'url'
    #       url_callback(row)
    end
  end
  
  def deliver_email_notification(row)
    Mailer.registrant_notification(self, row).deliver
  end
  
  # 改为报名成功直接返回会议网站
  # def url_callback(row)
  #   return if self.notify_url.blank?
  #   url = URI.parse(self.notify_url)
  #   res = Net::HTTP.post_form(url, {'form_id'=> self.id, 'row_id'=>row.id,'order_id' => row.order_id }) 
  #   return  res.body
  # end
  
  def sort_fields(positions)
    return if positions.nil? || !positions.is_a?(Hash) || positions.empty?
    
    positions.each do |uuid, position|
      field = self.find_field_by_uuid(uuid)
      if field
        field.position = position 
        field.save
      end
    end
  end
  
  def persisted?
    !new_record?
  end
  
  def find_field_by_uuid(uuid)
    self.fields.detect{|f| f.uuid == uuid}
  end
  
  private
  def make_edit_key
    self.edit_key = self.class.make_token
  end
  
  def update_timestamps
    self.created_at ||= Time.now
    self.updated_at = Time.now
  end                 
  
end
