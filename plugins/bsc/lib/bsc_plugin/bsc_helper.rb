module BscPlugin::BscHelper
  include ActionView::Helpers::FormTagHelper

  def token_input_field_tag(name, element_id, search_action, options = {}, text_field_options = {}, html_options = {})
    options[:min_chars] ||= 3
    options[:hint_text] ||= _("Type in a search term")
    options[:no_results_text] ||= _("No results")
    options[:searching_text] ||= _("Searching...")
    options[:search_delay] ||= 1000
    options[:prevent_duplicates] ||=  true
    options[:backspace_delete_item] ||= false
    options[:focus] ||= false
    options[:avoid_enter] ||= true
    options[:on_result] ||= 'null'
    options[:on_add] ||= 'null'
    options[:on_delete] ||= 'null'
    options[:on_ready] ||= 'null'

    result = text_field_tag(name, nil, text_field_options.merge(html_options.merge({:id => element_id})))
    result +=
    "
    <script type='text/javascript'>
      jQuery('##{element_id}')
      .tokenInput('#{url_for(search_action)}', {
        minChars: #{options[:min_chars].to_json},
        prePopulate: #{options[:pre_populate].to_json},
        hintText: #{options[:hint_text].to_json},
        noResultsText: #{options[:no_results_text].to_json},
        searchingText: #{options[:searching_text].to_json},
        searchDelay: #{options[:serach_delay].to_json},
        preventDuplicates: #{options[:prevent_duplicates].to_json},
        backspaceDeleteItem: #{options[:backspace_delete_item].to_json},
        queryParam: #{name.to_json},
        tokenLimit: #{options[:token_limit].to_json},
        onResult: #{options[:on_result]},
        onAdd: #{options[:on_add]},
        onDelete: #{options[:on_delete]},
        onReady: #{options[:on_ready]},
      })
      "
      result += options[:focus] ? ".focus();" : ";"
      if options[:avoid_enter]
        result += "jQuery('#token-input-#{element_id}')
                    .live('keydown', function(event){
                    if(event.keyCode == '13') return false;
                  });"
      end
      result += "</script>"
      result
  end

  def datepicker_period_field_tag(from_field, to_field, from_default=nil, to_default=nil,
                                  from_id='from', to_id='to', from_options={:size => 9}, to_options={:size=>9})
    from_default = from_default ? from_default.strftime("%Y-%m-%d") : nil
    to_default = to_default ? to_default.strftime("%Y-%m-%d") : nil
    text_field_tag(from_field, from_default, from_options.merge(:id => from_id)) + _(' to ') +
    text_field_tag(to_field, to_default, to_options.merge(:id => to_id))+
    "
    <script>
      var dates = jQuery( '##{from_id}, ##{to_id}' ).datepicker({
        changeMonth: true,
        dateFormat: 'yy-mm-dd',
        onSelect: function( selectedDate ) {
          var option = this.id == '#{from_id}' ? 'minDate' : 'maxDate',
          instance = jQuery( this ).data( 'datepicker' ),
          date = jQuery.datepicker.parseDate(
             instance.settings.dateFormat ||
             jQuery.datepicker._defaults.dateFormat,
             selectedDate, instance.settings );
          dates.not( this ).datepicker( 'option', option, date );
        }
      });
    </script>
    "
  end

  def product_display_name(product)
    "#{product.name} (#{product.enterprise.name})"
  end

  def display_text_field(name, value, label_html_options={}, value_html_options={}, tr_options={}, options={:display_nil => false, :nil_symbol => '---'})
    value = value.to_s
    if !value.blank? || options[:display_nil]
      value = value.blank? ? options[:nil_symbol] : value
      label_html_options[:class] = label_html_options.has_key?(:class) ? label_html_options[:class] + ' bsc-field-label' : 'bsc-field-label'
      value_html_options[:class] = value_html_options.has_key?(:class) ? value_html_options[:class] + ' bsc-field-value' : 'bsc-field-value'
      content_tag('tr', content_tag('td', name+': ', label_html_options) + content_tag('td', value, value_html_options), tr_options)
    end
  end

  def display_list_field(list, options={:nil_symbol => '---'})
    list.map do |item|
      item = item.blank? ? options[:nil_symbol] : item
      content_tag('tr', content_tag('td', item, :class => 'bsc-field-value'))
    end.join
  end
  
  include ActionView::Helpers::TextHelper
  def short_text(name, chars = 40)
    truncate name, chars, '...'
  end

  def contract_status_to_name(status)
    BscPlugin::Contract::Status.names[status]
  end

  def contract_client_type_to_name(type)
    BscPlugin::Contract::ClientType.names[type]
  end

  def contract_business_type_to_name(type)
    BscPlugin::Contract::BusinessType.names[type]
  end

  def group_by_quantity(list, grouper, display_method='to_s', display_as_arg=false)
    total = 0
    result = list.
      group_by { |item| item.send(grouper)}.
      sort_by { |grouper, items| items.count*-1 }.
      map {|grouper, items| total += items.count ; "#{items.count} #{display_as_arg ? self.send(display_method, grouper) : grouper.send(display_method)}"}.
      join("<br />")

    return [result, total]
  end
end
