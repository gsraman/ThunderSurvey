class RowsController < ApplicationController
  before_filter :set_form
  before_filter :verify_edit_key, :only => [:index]

  def index
    klass = @form.klass
    @rows = klass.all(:order => 'created_at')
    
    respond_to do |want|
      want.html { render :layout => params[:embed].blank? ? 'application' : "grid"}
      want.json {
        # 如果grid参数不为0，则为Grid调用，否则为ActiveResource
        if params[:grid] == '0'
          render :json => @rows.to_json
        else
          rows = []
          @rows.each_with_index do |row, i|
            cell = [row.id.to_s]
            cell << i + 1
            @form.fields.each { |field| cell << row.send("f#{field.id}") }
            cell << row.created_at
            cell << ''
            rows << {:id => row.id.to_s, :cell => cell}
          end
        
          data = {:page => 1, :total => 1, :records => klass.count, :rows => rows}
          render :json => data.to_json
        end
      }
    end
  end
  
  def create
    return update if params[:oper] == 'edit'
    return destroy if params[:oper] == 'del'
    
    params[:row][:created_at] = Time.now
    klass = @form.klass
    @row = klass.new(params[:row])
    
    respond_to do |want|
      if @row.save
        @form.deliver_notification
        if @form.thanks_url.blank?
          want.html {redirect_to thanks_path}
        else
          want.html {redirect_to @form.thanks_url}
        end
      else
        want.html {render :template => '/forms/show',:layout => 'simple'}
      end
    end
  end
  
  def update
    klass = @form.klass
    @row = klass.find(params.delete(:id))
    params.reject! do |k, v|
      !@row.respond_to?(k)
    end
    
    respond_to do |want|
      if @row.update_attributes(params)
        want.html {render :text => "success"}
      else
        want.html {render :template => '/forms/show',:layout => 'simple'}
      end
    end
  end
  
  def destroy
    klass = @form.klass
    @row = klass.find(params[:id])
    @row.destroy if @row
    
    respond_to do |want|
      want.html {render :text => "success"}
    end
  end
  
  private
  def set_form
    @form = Form.find(params[:form_id])
  end
end