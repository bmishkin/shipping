# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

# Updated:: 11-28-2011 by Mark Dickson (mailto:mark@sitesteaders.com)

module Shipping
	VERSION = "1.7.0"

	class ShippingError < StandardError; end
	class ShippingRequiredFieldError < StandardError; end

	class Base
		attr_reader :data, :response, :plain_response, :required, :services
		attr_accessor :debug

		attr_writer :ups_license_number, :ups_shipper_number, :ups_user, :ups_password, :ups_url, :ups_tool
		attr_writer :fedex_account, :fedex_meter, :fedex_url, :fedex_package_weight_limit_in_lbs

		attr_accessor :name, :phone, :company, :email, :address, :address2, :address3, :city, :state, :zip, :country, :attention
		attr_accessor :sender_name, :sender_phone, :sender_company, :sender_email, :sender_address, :sender_address2, :sender_address3, :sender_city, :sender_state, :sender_zip, :sender_country, :sender_attention

		attr_accessor :weight, :weight_units, :insured_value, :declared_value, :transaction_type, :description
		attr_accessor :measure_units, :measure_length, :measure_width, :measure_height
		attr_accessor :package_total, :packaging_type, :service_type
		
		attr_accessor :price, :discount_price, :eta, :time_in_transit

		attr_accessor :ship_date, :dropoff_type, :pay_type, :currency_code, :image_type, :label_type, :reference_number
    
    attr_accessor :weight_each, :quantity, :max_weight, :max_quantity, :items

		def initialize(options = {})
		  # Look for global SHIPPING_CONFIG
		  # if it exists, then use whatever values have been set there
		  if defined?(SHIPPING_CONFIG) && SHIPPING_CONFIG.is_a?(Hash)
		    options[:prefs].nil? ? options[:prefs] = SHIPPING_CONFIG : options[:prefs].merge(SHIPPING_CONFIG)
		  end
			options[:prefs].each {|pref, value| eval("@#{pref} = #{value.inspect}")} if options[:prefs]

			@required = Array.new
			@services = Array.new

			# include all provided data
			options.each do |method, value| 
				instance_variable_set("@#{method}", value)
			end
			
			case options[:carrier]
		  when "fedex"
		    fedex
	    when "ups"
	      ups
      when nil
      else
        raise ShippingError, "unknown service"
      end
		end

		# Initializes an instance of Shipping::FedEx with the same instance variables as the base object
		def fedex
			Shipping::FedEx.new prepare_vars
		end

		# Initializes an instance of Shipping::UPS with the same instance variables as the base object
		def ups
			Shipping::UPS.new prepare_vars
		end
		
    # Attempt to package items in multiple boxes efficiently
    # This doesn't use the bin-packing algorithm, but instead attempts to mirror how people pack boxes
    # -- since people will most likely be packing them.
    # -- It attempts to pack like items whenever possible.
    # @items: array of weights
    # @weight_each: can be used instead of array of items
    # @variation_threshold: how much variety you'll allow (default to 10% variation [e.g. 10 items, 10 each])
    # @weight_threshold: the minimum weight a box must be to close (default .5, i.e. half full by weight)
    # @quantity_threshold: the minimum full a box must be to close (default .5, i.e. half full by the number of items that will fit)
    def boxes
      # See if we're dealing with an array of items
      if @items.length > 0
        @items.each {|item| item[:total_weight] = item[:weight] * item[:quantity]} # get weight totals
        props = @items.inject({:weights => [], :quantities => [], :total_weights => []}) {|h, item| h[:weights] << item[:weight];h[:quantities] << item[:quantity]; h[:total_weights] << item[:total_weight];h}
        @quantity = props[:quantities].sum
        total_weight = props[:total_weights].sum
        
        # check to see if these are all the same weight
        if props[:weights].uniq.length == 1
          itemized = false
          @weight_each = props[:weights].uniq[0]
        else
          itemized = true
        end
      else
        @required = ['quantity', 'weight_each']
        total_weight = @quantity.to_f * @weight_each
        itemized = false
      end
  
      max_weight = @max_weight || 150 # Fed Ex and UPS commercial max
      max_quantity = @max_quantity || @quantity
      variation_threshold = @variation_threshold || 0.1 # default to 10% variation (e.g. 10 items, 10 each)
      weight_threshold = @weight_threshold || 0.5 # default to half full
      quantity_threshold = @quantity_threshold || 0.5 #default to half full
      box = Array.new
      
      # See if boxes should be divided by weight or number
      bw = total_weight / max_weight
      bq = @quantity.to_f / max_quantity
      min_boxes = [bw.ceil, bq.ceil].max.to_i

      # work with list of items
      if itemized
        leftovers = Array.new
        variation = @items.length / @quantity.to_f # this shows us how much repetition there is

        # First, we attempt to pack like items/weights
        # we can skip this if variation is really high
        if variation < variation_threshold
          @items.each do |item|
            while item[:quantity] > 0
              max = (@max_weight / item[:weight]).truncate # how many of this weight can be packed in
              this_num = [max, @max_quantity, item[:quantity]].min # should we pack by weight, number avail, or quantity
              this_weight = this_num * item[:weight]
              item[:quantity] -= this_num
              
              # if we haven't met the threshold
              if (this_weight / @max_weight) <= weight_threshold and (this_num / @max_quantity) <= quantity_threshold
                leftovers  << {:weight => this_weight, :quantity => this_num, :item => item[:id]}
              else #otherwise, pack it
                box << {:weight => this_weight, :quantity => this_num, :item => item[:id]}
              end
            end
          end
        else
          leftovers = @items
        end

        # Then, we pack all the leftovers
        leftover_box = {:weight => @max_weight, :quantity => @max_quantity}
        this_box = {:weight => 0.0, :quantity => 0}       
        leftovers.each do |item|
          for i in 1..item[:quantity]
            leftover_box[:weight] -= item[:weight]
            leftover_box[:quantity] -= 1
            if leftover_box[:weight] > 0 and leftover_box[:quantity] > 0
              this_box[:weight] += item[:weight]
              this_box[:quantity] += 1
            elsif leftover_box[:weight] = 0 and leftover_box[:quantity] >= 0
              this_box[:weight] += item[:weight]
              this_box[:quantity] += 1
              box << {:weight => this_box[:weight], :quantity => this_box[:quantity]}
              leftover_box = {:weight => @max_weight, :quantity => @max_quantity}
              this_box = {:weight => 0.0, :quantity => 0}
            else
              box << {:weight => this_box[:weight], :quantity => this_box[:quantity]}
              leftover_box = {:weight => @max_weight, :quantity => @max_quantity}
              this_box = {:weight => 0.0, :quantity => 0}
            end
          end
        end
        if this_box[:weight] > 0.0 and this_box[:quantity] > 0
          box << {:weight => this_box[:weight], :quantity => this_box[:quantity]}
        end
                  
        inefficiency = box.length / min_boxes

      else # pack super efficiently
        if bw > bq
          box_weight = max_weight
          box_quantity = max_weight / @weight_each
        else
          box_weight = max_quantity * @weight_each
          box_quantity = max_quantity
        end
        
        # fill the rest of the boxes
        num_boxes = min_boxes - 1
        (num_boxes).times do
          box << {:weight => box_weight, :quantity => box_quantity}
        end
        
        # if there is an uneven number for packaging
        if @quantity % min_boxes != 0 or num_boxes == 0
          excess_q = @quantity - (box_quantity * num_boxes)
          excess_w = excess_q * @weight_each
          box << {:weight => excess_w, :quantity => excess_q}
        end
        inefficiency = 0
      end
      return box
    end

		def self.state_from_zip(zip)
			zip = zip.to_i
			{
				(99500...99929) => "AK", 
				(35000...36999) => "AL", 
				(71600...72999) => "AR", 
				(75502...75505) => "AR", 
				(85000...86599) => "AZ", 
				(90000...96199) => "CA", 
				(80000...81699) => "CO", 
				(6000...6999) => "CT", 
				(20000...20099) => "DC", 
				(20200...20599) => "DC", 
				(19700...19999) => "DE", 
				(32000...33999) => "FL", 
				(34100...34999) => "FL", 
				(30000...31999) => "GA", 
				(96700...96798) => "HI", 
				(96800...96899) => "HI", 
				(50000...52999) => "IA", 
				(83200...83899) => "ID", 
				(60000...62999) => "IL", 
				(46000...47999) => "IN", 
				(66000...67999) => "KS", 
				(40000...42799) => "KY", 
				(45275...45275) => "KY", 
				(70000...71499) => "LA", 
				(71749...71749) => "LA", 
				(1000...2799) => "MA", 
				(20331...20331) => "MD", 
				(20600...21999) => "MD", 
				(3801...3801) => "ME", 
				(3804...3804) => "ME", 
				(3900...4999) => "ME", 
				(48000...49999) => "MI", 
				(55000...56799) => "MN", 
				(63000...65899) => "MO", 
				(38600...39799) => "MS", 
				(59000...59999) => "MT", 
				(27000...28999) => "NC", 
				(58000...58899) => "ND", 
				(68000...69399) => "NE", 
				(3000...3803) => "NH", 
				(3809...3899) => "NH", 
				(7000...8999) => "NJ", 
				(87000...88499) => "NM", 
				(89000...89899) => "NV", 
				(400...599) => "NY", 
				(6390...6390) => "NY", 
				(9000...14999) => "NY", 
				(43000...45999) => "OH", 
				(73000...73199) => "OK", 
				(73400...74999) => "OK", 
				(97000...97999) => "OR", 
				(15000...19699) => "PA", 
				(2800...2999) => "RI", 
				(6379...6379) => "RI", 
				(29000...29999) => "SC", 
				(57000...57799) => "SD", 
				(37000...38599) => "TN", 
				(72395...72395) => "TN", 
				(73300...73399) => "TX", 
				(73949...73949) => "TX", 
				(75000...79999) => "TX", 
				(88501...88599) => "TX", 
				(84000...84799) => "UT", 
				(20105...20199) => "VA", 
				(20301...20301) => "VA", 
				(20370...20370) => "VA", 
				(22000...24699) => "VA", 
				(5000...5999) => "VT", 
				(98000...99499) => "WA", 
				(49936...49936) => "WI", 
				(53000...54999) => "WI", 
				(24700...26899) => "WV", 
				(82000...83199) => "WY"
				}.each do |range, state|
					return state if range.include? zip
				end

				raise ShippingError, "Invalid zip code"
			end

		private

			def prepare_vars #:nodoc:
				h = eval(%q{instance_variables.map {|var| "#{var.to_s.gsub("@",":")} => #{eval(var.to_s+'.inspect')}"}.join(", ").chomp(", ")})
				return eval("{#{h}}")
			end

			# Goes out, posts the data, and sets the @response variable with the information
			def get_response(url)
				check_required
				uri            = URI.parse url
				http           = Net::HTTP.new uri.host, uri.port
				if uri.port == 443
					http.use_ssl	= true
					http.verify_mode = OpenSSL::SSL::VERIFY_NONE
				end
				@response_plain = http.post(uri.path, @data).body
				@response       = @response_plain.include?('<?xml') ? REXML::Document.new(@response_plain) : @response_plain

				@response.instance_variable_set "@response_plain", @response_plain
        
        # if we're in debug mode, spit out the XML
        # we can use the console or the logger
        if @debug == 'console'
          puts "[SHIPPING] Request:\n#{@data}"
          puts "[SHIPPING] Response:\n#{@response}"
        elsif @debug == 'logger'
          logger = Logger.new("#{Rails.root.to_s}/log/#{Rails.env}.log")
          request_id = Time.now.strftime "%FT%T"
          logger.info  "\n#{request_id} [SHIPPING] Request #{uri}\n#{@data}" 
          logger.info  "\n#{request_id} [SHIPPING] Response\n#{@response_plain}"
        end
        
        def @response.plain; @response_plain; end
			end

			# Make sure that the required fields are not empty
			def check_required
				for var in @required
					raise ShippingRequiredFieldError, "The #{var} variable needs to be set" if eval("@#{var}").nil?
				end
			end

			STATES = {"al" => "alabama", "ne" => "nebraska", "ak" => "alaska", "nv" => "nevada", "az" => "arizona", "nh" => "new hampshire", "ar" => "arkansas", "nj" => "new jersey", "ca" => "california", "nm" => "new mexico", "co" => "colorado", "ny" => "new york", "ct" => "connecticut", "nc" => "north carolina", "de" => "delaware", "nd" => "north dakota", "fl" => "florida", "oh" => "ohio", "ga" => "georgia", "ok" => "oklahoma", "hi" => "hawaii", "or" => "oregon", "id" => "idaho", "pa" => "pennsylvania", "il" => "illinois", "pr" => "puerto rico", "in" => "indiana", "ri" => "rhode island", "ia" => "iowa", "sc" => "south carolina", "ks" => "kansas", "sd" => "south dakota", "ky" => "kentucky", "tn" => "tennessee", "la" => "louisiana", "tx" => "texas", "me" => "maine", "ut" => "utah", "md" => "maryland", "vt" => "vermont", "ma" => "massachusetts", "va" => "virginia", "mi" => "michigan", "wa" => "washington", "mn" => "minnesota", "dc" => "district of columbia", "ms" => "mississippi", "wv" => "west virginia", "mo" => "missouri", "wi" => "wisconsin", "mt" => "montana", "wy" => "wyoming"}
			
			def self.initialize_for_fedex_service(xml)
        s = Shipping::Base.new
        s.fedex
        s.eta = REXML::XPath.first(xml, "DeliveryDate").text unless REXML::XPath.match(xml, "DeliveryDate").empty?
        s.service_type = REXML::XPath.first(xml, "Service").text
        s.discount_price = REXML::XPath.first(xml, "EstimatedCharges/DiscountedCharges/BaseCharge").text
        s.price = REXML::XPath.first(xml, "EstimatedCharges/DiscountedCharges/NetCharge").text
        return s
      end
		end
	end
