# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

# Updated:: 12-22-2008 by Mark Dickson (mailto:mark@sitesteaders.com)

module Shipping
  
  class UPS < Base
    include REXML
    API_VERSION = "1.0001"
    COUNTRIES_REQUIRING_PROVINCE = ["US", "CA", "IE"]

    # For current implementation (XML) docs, see http://www.ups.com/gec/techdocs/pdf/dtk_RateXML_V1.zip
    def price
      @required = [:zip, :country, :sender_zip, :weight]
      @required += [:ups_license_number, :ups_user, :ups_password]
      @insured_value ||= 0
      @country ||= 'US'
      @sender_country ||= 'US'
      @service_type ||= 'ground' # default to UPS ground
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/Rate'

      state = STATES.has_value?(@state.downcase) ? STATES.key(@state.downcase).upcase : @state.upcase unless @state.blank?
      sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.key(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?

      state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@country)
      sender_state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@sender_country)

      # With UPS need to send two xmls
      # First one to authenticate, second for the request
      b = request_access
      b.instruct!

      b.RatingServiceSelectionRequest { |b| 
        b.Request { |b|
          b.TransactionReference { |b|
            b.CustomerContext 'Rating and Service'
            b.XpciVersion API_VERSION
          }
          b.RequestAction 'Rate'
        }
        b.CustomerClassification { |b|
          b.Code CustomerTypes[@customer_type] || '01'
        }
        b.PickupType { |b|
          b.Code @pickup_type || '01'
        }
        b.Shipment { |b|
          b.Shipper { |b|
            b.Address { |b|
              b.PostalCode @sender_zip
              b.CountryCode @sender_country unless @sender_country.blank?
              b.City @sender_city unless @sender_city.blank?
              b.StateProvinceCode sender_state unless sender_state.blank?
            }
          }
          b.ShipTo { |b|
            b.Address { |b|
              b.PostalCode @zip
              b.CountryCode @country unless @country.blank?
              b.City @city unless @city.blank?
              b.StateProvinceCode state unless state.blank?
              unless @commercial
                b.ResidentialAddressIndicator
              end
            }
          }
          b.Service { |b| # The service code
            b.Code ServiceTypes[@service_type] || '03' # defaults to ground
          }
          b.Package { |b| # Package Details         
            b.PackagingType { |b|
              b.Code PackageTypes[@packaging_type] || '02' # defaults to 'your packaging'
              b.Description 'Package'
            }
            b.Description 'Rate Shopping'
            b.PackageWeight { |b|
              b.Weight @weight
              b.UnitOfMeasurement { |b|
                b.Code @weight_units || 'LBS' # or KGS
              }
            }
            b.Dimensions { |b|
              b.UnitOfMeasurement { |b|
                b.Code @measure_units || 'IN'
              }
              b.Length @measure_length || 0
              b.Width @measure_width || 0
              b.Height @measure_height || 0
            }
            b.PackageServiceOptions { |b|
              b.InsuredValue { |b|
                b.CurrencyCode @currency_code || 'US'
                b.MonetaryValue @insured_value
              }
            }
          }
        }
      }

      get_response @ups_url + @ups_tool
      return REXML::XPath.first(@response, "//RatingServiceSelectionResponse/RatedShipment/TransportationCharges/MonetaryValue").text.to_f
    rescue
      raise ShippingError, get_error
    end

    def validated_price
      @required = [:zip, :country, :sender_zip, :weight]
      @required += [:ups_license_number, :ups_user, :ups_password]

      @insured_value ||= 0
      @country ||= 'US'
      @sender_country ||= 'US'
      @service_type ||= 'ground' # default to UPS ground
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/Rate'

      state = STATES.has_value?(@state.downcase) ? STATES.key(@state.downcase).upcase : @state.upcase unless @state.blank?
      sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.key(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?

      state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@country)
      sender_state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@sender_country)

      # With UPS need to send two xmls
      # First one to authenticate, second for the request
      b = request_access
      b.instruct!

      b.RatingServiceSelectionRequest { |b| 
        b.Request { |b|
          b.TransactionReference { |b|
            b.CustomerContext 'Rating and Service'
            b.XpciVersion API_VERSION
          }
          b.RequestAction 'Rate'
        }
        b.CustomerClassification { |b|
          b.Code CustomerTypes[@customer_type] || '01'
        }
        b.PickupType { |b|
          b.Code @pickup_type || '01'
        }
        b.Shipment { |b|
          b.Shipper { |b|
            b.Address { |b|
              b.PostalCode @sender_zip
              b.CountryCode @sender_country unless @sender_country.blank?
              b.City @sender_city unless @sender_city.blank?
              b.StateProvinceCode sender_state unless sender_state.blank?
            }
          }
          b.ShipTo { |b|
            b.Address { |b|
              b.PostalCode @zip
              b.CountryCode @country unless @country.blank?
              b.City @city unless @city.blank?
              b.StateProvinceCode state unless state.blank?
              unless @commercial
                b.ResidentialAddressIndicator
              end
            }
          }
          b.Service { |b| # The service code
            b.Code ServiceTypes[@service_type] || '03' # defaults to ground
          }
          b.Package { |b| # Package Details         
            b.PackagingType { |b|
              b.Code PackageTypes[@packaging_type] || '02' # defaults to 'your packaging'
              b.Description 'Package'
            }
            b.Description 'Rate Shopping'
            b.PackageWeight { |b|
              b.Weight @weight
              b.UnitOfMeasurement { |b|
                b.Code @weight_units || 'LBS' # or KGS
              }
            }
            b.Dimensions { |b|
              b.UnitOfMeasurement { |b|
                b.Code @measure_units || 'IN'
              }
              b.Length @measure_length || 0
              b.Width @measure_width || 0
              b.Height @measure_height || 0
            }
            b.PackageServiceOptions { |b|
              b.InsuredValue { |b|
                b.CurrencyCode @currency_code || 'US'
                b.MonetaryValue @insured_value
              }
            }
          }
        }
      }

      get_response @ups_url + @ups_tool

      status = XPath.first(@response, "//RatingServiceSelectionResponse/Response/ResponseStatusCode").text.to_i
      if status == 1
        return XPath.first(@response, "//RatingServiceSelectionResponse/RatedShipment/TransportationCharges/MonetaryValue").text.to_f
      else
        return XPath.first(@response, "//RatingServiceSelectionResponse/Response/Error/ErrorDescription").text
      end
    end
    
    def price_multiple
      return_boxes = Hash.new
      return_boxes[:method] = 'UPS' + ' ' + @service_type.split("_").each{|word| word.capitalize}.join(" ")
      return_boxes[:packages] = Array.new
      total_cost = 0
      if @max_quantity == nil && @weight != nil
        cost = self.validated_price
        if cost.is_a? String
          return {:errors => cost}
        else
          return {:cost => cost}
        end
        exit
      end
      boxes = self.boxes
      self.weight = boxes.first[:weight]
      cost = self.validated_price
      if cost.is_a? String
        return {:errors => cost}
      else
        for i in 1..(boxes.length - 1)
          return_boxes[:packages] << {
                  :cost => cost, 
                  :weight => boxes.first[:weight],
                  :quantity => boxes.first[:quantity],
                  }
          total_cost += cost.to_d
        end
        self.weight = boxes.last[:weight]
        cost = self.validated_price
        return_boxes[:packages] <<  {
                  :cost => cost, 
                  :weight => boxes.last[:weight],
                  :quantity => boxes.last[:quantity],
                  }
        total_cost += cost.to_d
        return_boxes[:cost] = total_cost
        return_boxes[:num_packages] = return_boxes[:packages].length
        return return_boxes
      end
    end
    
    def rates_multiple
      return_boxes = Hash.new
      return_boxes[:packages] = Array.new
      boxes = self.boxes

      # we only look at the first and last boxes--the others will all be the same
      self.weight = boxes.first[:weight]
      rates = self.rates
      if rates.is_a? String
        return {:errors => rates}
      else
        for i in 1..(boxes.length - 1)
          return_boxes[:packages] << rates
        end
        total_rates = rates.each {|code, service| service[:price] *= (boxes.length - 1); service[:billing_weight] *= (boxes.length - 1)}
        self.weight = boxes.last[:weight]
        rates = self.rates
        return_boxes[:packages] << rates
        return_boxes[:rates] = total_rates.each {|code, service| service[:price] += (rates[code][:price]); service[:billing_weight] += rates[code][:billing_weight]}
  
        return return_boxes
      end
    end

    def rates
      @required = [:zip, :country, :sender_zip, :weight]
      @required += [:ups_license_number, :ups_user, :ups_password]

      @insured_value ||= 0
      @country ||= 'US'
      @sender_country ||= 'US'
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/Rate'

      state = STATES.has_value?(@state.downcase) ? STATES.key(@state.downcase).upcase : @state.upcase unless @state.blank?
      sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.key(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?

      state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@country)
      sender_state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@sender_country)

      # With UPS need to send two xmls
      # First one to authenticate, second for the request
      b = request_access
      b.instruct!

      b.RatingServiceSelectionRequest { |b| 
        b.Request { |b|
          b.TransactionReference { |b|
            b.CustomerContext 'Rating and Service'
            b.XpciVersion API_VERSION
          }
          b.RequestAction 'Rate'
          b.RequestOption 'Shop'
        }
        b.CustomerClassification { |b|
          b.Code CustomerTypes[@customer_type] || '01'
        }
        b.PickupType { |b|
          b.Code @pickup_type || '01'
        }
        b.Shipment { |b|
          b.Shipper { |b|
            b.Address { |b|
              b.PostalCode @sender_zip
              b.CountryCode @sender_country unless @sender_country.blank?
              b.City @sender_city unless @sender_city.blank?
              b.StateProvinceCode sender_state unless sender_state.blank?
            }
          }
          b.ShipTo { |b|
            b.Address { |b|
              b.PostalCode @zip
              b.CountryCode @country unless @country.blank?
              b.City @city unless @city.blank?
              b.StateProvinceCode state unless state.blank?
              unless @commercial
                b.ResidentialAddressIndicator
              end
            }
          }
          b.Package { |b| # Package Details         
            b.PackagingType { |b|
              b.Code PackageTypes[@packaging_type] || '02' # defaults to 'your packaging'
              b.Description 'Package'
            }
            b.Description 'Rate Shopping'
            b.PackageWeight { |b|
              b.Weight @weight
              b.UnitOfMeasurement { |b|
                b.Code @weight_units || 'LBS' # or KGS
              }
            }
            b.Dimensions { |b|
              b.UnitOfMeasurement { |b|
                b.Code @measure_units || 'IN'
              }
              b.Length @measure_length || 0
              b.Width @measure_width || 0
              b.Height @measure_height || 0
            }
            b.PackageServiceOptions { |b|
              b.InsuredValue { |b|
                b.CurrencyCode @currency_code || 'US'
                b.MonetaryValue @insured_value
              }
            }
          }
        }
      }

      get_response @ups_url + @ups_tool

      status = XPath.first(@response, "//RatingServiceSelectionResponse/Response/ResponseStatusCode").text.to_i
      if status == 1
        shipmethods = Hash.new
        @response.elements.each('//RatedShipment') do |shipmethod|
          index = XPath.first(shipmethod, "Service/Code").text
          shipmethods[index.to_i] = {
            :service => ServiceTypes.key(index),
            :service_name => ServiceTypes.key(index).split("_").each{|word| word.capitalize!}.join(" "),
            :price => XPath.first(shipmethod, "TransportationCharges/MonetaryValue").text.to_f,
            :currency => XPath.first(shipmethod, "TransportationCharges/CurrencyCode").text,
            :billing_weight => XPath.first(shipmethod, "BillingWeight/Weight").text.to_f,
            :weight_units => XPath.first(shipmethod, "BillingWeight/UnitOfMeasurement/Code").text,
            }
        end
        return shipmethods
      else
        return XPath.first(@response, "//RatingServiceSelectionResponse/Response/Error/ErrorDescription").text
      end
    end

    # See http://www.ups.com/gec/techdocs/pdf/dtk_AddrValidateXML_V1.zip for API info
    def valid_address?( delta = 1.0 )
      @required = [:ups_license_number, :ups_user, :ups_password]         
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/AV'
      
      @country ||= 'US'
      @sender_country ||= 'US'
      
      state = nil
      if @state
        state = STATES.has_value?(@state.downcase) ? STATES.key(@state.downcase) : @state
      end
      
      state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@country)
      sender_state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@sender_country)

      b = request_access
      b.instruct!
      
      b.AddressValidationRequest {|b|
        b.Request {|b|
          b.RequestAction "AV"
          b.TransactionReference {|b|
            b.CustomerContext "#{@city}, #{state} #{@zip}"
            b.XpciVersion API_VERSION
          }
        }
        b.Address {|b|
          b.City @city
          b.StateProvinceCode state
          b.PostalCode @zip
        }
      }

      get_response @ups_url + @ups_tool

      if REXML::XPath.first(@response, "//AddressValidationResponse/Response/ResponseStatusCode").text == "1" && REXML::XPath.first(@response, "//AddressValidationResponse/AddressValidationResult/Quality").text.to_f >= delta
        return true
      else
        return false
      end
      rescue ShippingError
        raise ShippingError, get_error
    end

    # See Ship-WW-XML.pdf for API info
    # @image_type = [GIF|EPL] 
    def label
      @required = [:ups_license_number, :ups_shipper_number, :ups_user, :ups_password]
      @required +=  [:phone, :email, :company, :address, :city, :state, :zip]
      @required += [:sender_phone, :sender_email, :sender_company, :sender_address, :sender_city, :sender_state, :sender_zip ]

      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/ShipConfirm'
      
      @country ||= 'US'
      @sender_country ||= 'US'
      
      @packages ||= []
      if @packages.blank?
        @single_package = true
        @packages << { :description => @package_description, 
          :type => @packaging_type, 
          :weight => { :weight => @weight, :units => @weight_units},
          :measure => {
            :units => @measure_units, 
            :length => @measure_length,
            :width => @measure_width,
            :height =>  @measure_height },
          :insurance => {:currency => @currency_code, :value => @insured_value }
          }
      end

      state = STATES.has_value?(@state.downcase) ? STATES.key(@state.downcase).upcase : @state.upcase unless @state.blank?
      sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.key(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?
      
      state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@country)
      sender_state = nil unless COUNTRIES_REQUIRING_PROVINCE.include?(@sender_country)
  
      # make ConfirmRequest and get Confirm Response
      b = request_access
      b.instruct!

      b.ShipmentConfirmRequest { |b|
        b.Request { |b|
          b.RequestAction "ShipConfirm"
          b.RequestOption "nonvalidate"
          b.TransactionReference { |b|
            b.CustomerContext "#{@city}, #{@state} #{@zip}"
            b.XpciVersion API_VERSION
          }
        }
        b.Shipment { |b|
          unless @return_service_code.nil?
            b.ReturnService { |b|
              b.Code @return_service_code
            }
          end
          b.Shipper { |b|
            b.ShipperNumber @ups_shipper_number
            b.Name @sender_name
            b.AttentionName @sender_attention unless @sender_attention.blank?
            b.Address { |b|
              b.AddressLine1 @sender_address unless @sender_address.blank?
              b.AddressLine2 @sender_address2 unless @sender_address2.blank?
              b.AddressLine3 @sender_address3 unless @sender_address3.blank?
              b.PostalCode @sender_zip
              b.PhoneNumber @sender_phone
              b.CountryCode @sender_country unless @sender_country.blank?
              b.City @sender_city unless @sender_city.blank?
              b.StateProvinceCode sender_state unless sender_state.blank?
            }
          }
          b.ShipFrom { |b|
            b.CompanyName @sender_company[0,35]
            b.Address { |b|
              b.AddressLine1 @sender_address unless @sender_address.blank?
              b.AddressLine2 @sender_address2 unless @sender_address2.blank?
              b.AddressLine3 @sender_address3 unless @sender_address3.blank?
              b.PostalCode @sender_zip
              b.CountryCode @sender_country unless @sender_country.blank?
              b.City @sender_city unless @sender_city.blank?
              b.StateProvinceCode sender_state unless sender_state.blank?
            }
          }
          b.ShipTo { |b|
            b.CompanyName @company
            b.PhoneNumber @phone
            b.AttentionName @attention unless @attention.blank?
            b.Address { |b|              
              b.AddressLine1 @address unless @address.blank?
              b.AddressLine2 @address2 unless @address2.blank?
              b.AddressLine3 @address3 unless @address3.blank?
              b.PostalCode @zip
              b.CountryCode @country unless @country.blank?
              b.City @city unless @city.blank?
              b.StateProvinceCode state unless state.blank?
              unless @commercial
                b.ResidentialAddressIndicator
              end
            }
          }
          b.PaymentInformation { |b|
            pay_type = PaymentTypes[@pay_type] || 'Prepaid'
            
            if pay_type == 'Prepaid'
              b.Prepaid { |b|
                b.BillShipper { |b|
                  b.AccountNumber @ups_shipper_number
                }
              }
            elsif pay_type == 'BillThirdParty'
              b.BillThirdParty { |b|
                b.BillThirdPartyShipper { |b|
                  b.AccountNumber @billing_account
                  b.ThirdParty { |b|
                    b.Address { |b|
                      b.PostalCode @billing_zip
                      b.CountryCode @billing_country
                    }
                  }
                }
              }
            elsif pay_type == 'FreightCollect'
              b.FreightCollect { |b|
                b.BillReceiver { |b|
                  b.AccountNumber @billing_account
                }
              }
            else
              raise ShippingError, "Valid pay_types are 'prepaid', 'bill_third_party', or 'freight_collect'."
            end
          }
          b.Service { |b| # The service code
            b.Code ServiceTypes[@service_type] || '03' # defaults to ground
          }
          @packages.each do |package|
            b.Package { |b| # Package Details         
              unless @return_service_code.nil?
                b.Description package[:description]
              end
              b.PackagingType { |b|
                b.Code PackageTypes[package[:type]] || '02' # defaults to 'your packaging'
                b.Description 'Package'
              }
              b.PackageWeight { |b|
                b.Weight package[:weight][:weight]
                b.UnitOfMeasurement { |b|
                  b.Code package[:weight][:units] || 'LBS' # or KGS
                }
              }
              b.Dimensions { |b|
                b.UnitOfMeasurement { |b|
                  b.Code package[:measure][:units] || 'IN'
                }
                b.Length  package[:measure][:length] || 0
                b.Width  package[:measure][:width] || 0
                b.Height  package[:measure][:height] || 0
              } if  package[:measure] && (package[:measure][:length] ||  package[:measure][:width] || package[:measure][:height])
              unless @reference_number.blank?
                b.ReferenceNumber {|b|
                  b.Code '02'
                  b.Value @reference_number
                }
              end
              b.PackageServiceOptions { |b|
                b.InsuredValue { |b|
                  b.CurrencyCode package[:insurance][:currency] || 'US'
                  b.MonetaryValue package[:insurance][:value]
                }
              } if package[:insurance] && package[:insurance][:value]
            }
          end
        }
        b.LabelSpecification { |b|
          image_type = @image_type || 'GIF' # default to GIF
          
          b.LabelPrintMethod { |b|
            b.Code image_type
          }
          if image_type == 'GIF'
            b.HTTPUserAgent 'Mozilla/5.0'
            b.LabelImageFormat { |b|
              b.Code 'GIF'
            }
          elsif image_type == 'EPL'
            b.LabelStockSize { |b|
              b.Height '4'
              b.Width '6'
            }
          else
            raise ShippingError, "Valid image_types are 'EPL' or 'GIF'."
          end
        }
      }
      
      # get ConfirmResponse
      get_response @ups_url + @ups_tool
      begin
        shipment_digest = REXML::XPath.first(@response, '//ShipmentConfirmResponse/ShipmentDigest').text
      rescue
        raise ShippingError, get_error
      end

      # make AcceptRequest and get AcceptResponse
      @ups_tool = '/ShipAccept'
      
      b = request_access
      b.instruct!

      b.ShipmentAcceptRequest { |b|
        b.Request { |b|
          b.RequestAction "ShipAccept"
          b.TransactionReference { |b|
            b.CustomerContext "#{@city}, #{state} #{@zip}"
            b.XpciVersion API_VERSION
          }
        }
        b.ShipmentDigest shipment_digest
      }
      
      # get AcceptResponse
      get_response @ups_url + @ups_tool
      
      begin  
        response = Hash.new       
        if @single_package
          response[:tracking_number] = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/PackageResults/TrackingNumber").text
          response[:encoded_image] = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/PackageResults/LabelImage/GraphicImage").text
          extension = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/PackageResults/LabelImage/LabelImageFormat/Code").text
          response[:image] = Tempfile.new(["shipping_label", '.' + extension.downcase])
          response[:image].write Base64.decode64( response[:encoded_image] )
          response[:image].rewind
          
          # if this package has a high insured value
          high_value_report = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/ControlLogReceipt/GraphicImage")
          if high_value_report
            extension = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/ControlLogReceipt/ImageFormat/Code").text
            response[:encoded_high_value_report] = high_value_report.text
            response[:high_value_report] = Tempfile.new(["high_value_report", '.' + extension.downcase])
            response[:high_value_report].write Base64.decode64( response[:encoded_high_value_report] )
            response[:high_value_report].rewind
          end
        else
          response[:packages] = []
          REXML::XPath.each(@response, "//ShipmentAcceptResponse/ShipmentResults/PackageResults") do |package_element|
            response[:packages] << {}
            response[:packages].last[:tracking_number] = REXML::XPath.first(package_element, "TrackingNumber").text
            response[:packages].last[:encoded_label] = REXML::XPath.first(package_element, "LabelImage/GraphicImage").text
            extension = response[:packages].last[:encoded_label] = REXML::XPath.first(package_element, "LabelImage/LabelImageFormat/Code").text
            response[:packages].last[:label_file] = Tempfile.new(["shipping_label_#{Time.now}_#{Time.now.usec}", '.' + extension.downcase])
            response[:packages].last[:label_file].write Base64.decode64( response[:packages].last[:encoded_label] )
            response[:packages].last[:label_file].rewind
            
            # if this package has a high insured value
            high_value_report = REXML::XPath.first(package_element, "//ShipmentAcceptResponse/ShipmentResults/ControlLogReceipt/GraphicImage")
            if high_value_report
              extension = REXML::XPath.first(package_element, "//ShipmentAcceptResponse/ShipmentResults/ControlLogReceipt/ImageFormat/Code").text
              response[:packages].last[:encoded_high_value_report] = high_value_report.text
              response[:packages].last[:high_value_report] = Tempfile.new(["high_value_report", '.' + extension.downcase])
              response[:packages].last[:high_value_report].write Base64.decode64( response[:packages].last[:encoded_high_value_report] )
              response[:packages].last[:high_value_report].rewind
            end
          end
        end
      rescue
        raise ShippingError, get_error
      end

      # allows for things like fedex.label.url
      def response.method_missing(name, *args)
        has_key?(name) ? self[name] : super
      end
      
      # don't allow people to edit the response
      response.freeze
    end
    
    # This voids a shipment
    # if multiple tracking numbers are passed in, it will attempt to void them all in a single call
    # if ANY of them fails, we return false and hand over the array of results
    def void(shipping_id, tracking_numbers = [])
      @required = [:ups_license_number, :ups_shipper_number, :ups_user, :ups_password]
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/Void'

      # make ConfirmRequest and get Confirm Response
      b = request_access
      b.instruct!

      b.VoidShipmentRequest { |b|
        b.Request { |b|
          b.RequestAction "Void"
          b.TransactionReference { |b|
            b.CustomerContext "Void #{@tracking_number}"
            b.XpciVersion API_VERSION
          }
        }
        # one shipment may have multiple packages
        if tracking_numbers.length > 1
          b.ExpandedVoidShipment { |b|
            b.ShipmentIdentificationNumber shipping_id
            for num in tracking_numbers
              b.TrackingNumber num
            end
          }
        else
          b.ShipmentIdentificationNumber shipping_id
        end
      }
      
      # get VoidResponse
      get_response @ups_url + @ups_tool
      
      if tracking_numbers.length > 1
        status = true
        multiple_response = Hash.new
        REXML::XPath.each(@response, "//VoidShipmentResponse/PackageLevelResults") do |package_element|
          tracking_number = REXML::XPath.first(package_element, "TrackingNumber").text
          response_code = REXML::XPath.first(package_element, "StatusCode/Code").text.to_i
          multiple_response[tracking_number] = response_code
          status = false if response_code != 1
        end
        if status == true
          return true
        else
          return multiple_response
        end
      else
        status = REXML::XPath.first(@response, '//VoidShipmentResponse/Response/ResponseStatusCode').text
        # TODO: we may need a more detailed error message in the event that one package is voided and the other isn't
        raise ShippingError, get_error if status == '0' or status == '2'
        return true if status == '1'
      end
    end
    
    # For current implementation (XML) docs, see http://www.ups.com/gec/techdocs/pdf/dtk_TimeNTransitXML_V1.zip
    def transit_time
      @required = [:zip, :sender_zip, :weight]
      @required += [:ups_license_number, :ups_user, :ups_password]

      @insured_value ||= 0
      @country ||= 'US'
      @sender_country ||= 'US'
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/TimeInTransit'

      state = STATES.has_value?(@state.downcase) ? STATES.key(@state.downcase).upcase : @state.upcase unless @state.blank?
      sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.key(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?

      # With UPS need to send two xmls
      # First one to authenticate, second for the request
      b = request_access
      b.instruct!

      b.TimeInTransitRequest { |b| 
        b.Request { |b|
          b.RequestAction 'TimeInTransit'
          b.TransactionReference { |b|
            b.CustomerContext 'Time in Transit'
            b.XpciVersion API_VERSION
          }
        }
        b.TransitFrom { |b|
          b.AddressArtifactFormat { |b|
            #b.PoliticalDivision3 @sender_town unless @sender_town.blank? # for non-US towns
            b.PoliticalDivision2 @sender_city unless @sender_city.blank?
            b.PoliticalDivision1 sender_state unless sender_state.blank?
            b.CountryCode @sender_country
            b.PostCodePrimaryLow @sender_zip
          }
        }       
        b.TransitTo { |b|
          b.AddressArtifactFormat { |b|
            #b.PoliticalDivision3 @sender_town unless @sender_town.blank? # for non-US towns
            b.PoliticalDivision2 @city unless @city.blank?
            b.PoliticalDivision1 state unless state.blank?
            b.CountryCode @country
            b.PostCodePrimaryLow @zip
            unless @commercial
              b.ResidentialAddressIndicator
            end
          }
        }       
        b.PickupDate @pickup_date || Time.now.strftime("%Y%m%d")  
        b.ShipmentWeight { |b|
          b.Weight @weight
          b.UnitOfMeasurement { |b|
            b.Code @weight_units || 'LBS' # or KGS
          }
        }       
        b.TotalPackagesInShipment @packages || 1
        b.InvoiceLineTotal { |b|
          b.CurrencyCode @currency_code || 'US'
          b.MonetaryValue @insured_value
        }
      }

      get_response @ups_url + @ups_tool
      
      status = XPath.first(@response, "//TimeInTransitResponse/Response/ResponseStatusCode").text.to_i
      if status == 1
        times = Hash.new
        @response.elements.each('//ServiceSummary') do |shipmethod|
          index = XPath.first(shipmethod, "Service/Code").text
          times[index] = {
            :service_name => XPath.first(shipmethod, "Service/Description").text,
            :service => ServiceTimes.key(index),
            :days => XPath.first(shipmethod, "EstimatedArrival/BusinessTransitDays").text.to_i,
            :date => XPath.first(shipmethod, "EstimatedArrival/Date").text.to_date,
            :time => XPath.first(shipmethod, "EstimatedArrival/Time").text,
            }
        end
        return times
      else
        return XPath.first(@response, "//TimeInTransitResponse/Response/Error/ErrorDescription").text
      end
    end

    # For current implementation (XML) docs, see http://www.ups.com/gec/techdocs/pdf/dtk_TrackXML_V1.zip
    # Activity parameter is the value of RequestOption Element. 0 retrieves just the last activity, 1 retrieves all the activities.
    # Additional values are explained in the XML WebService documentation
    # You must send the requests to the production environment (https://onlinetools.ups.com/ups.app/xml) if you need signature images
    def track tracking_number, activity=1
      @ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
      @ups_tool = '/Track'

      # With UPS need to send two xmls
      # First one to authenticate, second for the request
      b = request_access
      b.instruct!

      b.TrackRequest { |b| 
        b.Request { |b|
          b.RequestAction 'Track'
          b.TransactionReference { |b|
            b.ToolVersion API_VERSION
          }
          b.RequestOption activity
        }
        b.TrackingNumber tracking_number
      }

      get_response @ups_url + @ups_tool
      
      status = XPath.first(@response, "//TrackResponse/Response/ResponseStatusCode").text.to_i
      raise ShippingError, get_error if status == 0
          
      tracking_info = {:activities => []}

      XPath.each(@response, "//TrackResponse/Shipment/Package/Activity") do |activity|

        tracking_info[:activities] << {}
        tracking_info[:activities].last[:location] = {}
        tracking_info[:activities].last[:location][:address] = {}
        {:address_line1 => "AddressLine1", :address_line2 => "AddressLine2", :address_line3 => "AddressLine3", :city => "City", :state_province_code => "StateProvinceCode", :postal_code => "PostalCode", :country_code => "CountryCode"}.each do |hash_key, xml_element|
          tracking_info[:activities].last[:location][:address][hash_key] = activity.get_elements("ActivityLocation/Address/#{xml_element}").first.text unless activity.get_elements("ActivityLocation/Address/#{xml_element}").first.blank?
        end

        tracking_info[:activities].last[:signed_by] = activity.get_elements("ActivityLocation/SignedForByName").first.text unless  activity.get_elements("ActivityLocation/SignedForByName").first.blank?
        unless activity.get_elements("ActivityLocation/SignatureImage[ImageFormat/Code = 'GIF']/GraphicImage").blank?
          tracking_info[:activities].last[:signature] = Tempfile.new("signature_#{tracking_number}_#{tracking_info[:activities].length}")
          tracking_info[:activities].last[:signature].write  Base64.decode64(activity.get_elements("ActivityLocation/SignatureImage[ImageFormat/Code = 'GIF']/GraphicImage").first.text) 
          tracking_info[:activities].last[:signature].rewind
        end

        tracking_info[:activities].last[:status] = activity.get_elements("Status/StatusType/Code").first.text unless activity.get_elements("Status/StatusType/Code").first.blank?
        tracking_info[:activities].last[:description] = activity.get_elements("Status/StatusType/Description").first.text unless activity.get_elements("Status/StatusType/Description").first.blank?
        tracking_info[:activities].last[:code] = activity.get_elements("Status/StatusCode/Code").first.text unless activity.get_elements("Status/StatusCode/Code").first.blank?
        tracking_info[:activities].last[:date] = "#{activity.get_elements("Date").first.text} #{activity.get_elements("Time").first.text}".strip

      end

      current_status = XPath.first(@response, "/TrackResponse/Shipment/CurrentStatus/Code")
      unless current_status.blank?
        tracking_info[:current_status] = current_status.text
      end

      delivery_date = XPath.first(@response, "/TrackResponse/Shipment/EstimatedDeliveryDetails/Date")
      unless delivery_date.blank?
        tracking_info[:delivery_date] = "#{delivery_date.text}}".strip
      end

      tracking_info

    end

    # This is a helper method to split an address
    # We don't want the gem to split it automatically, 
    # as that prevents users from specifying their own multi-line address
    # We do want to make it easy to properly format addresses though
    def self.split_address(address)
      return [] if address.blank?
      address.split.inject([]) do |splits, w| 
        if splits.blank? or ((splits.last.length + w.length + 1) >= 35 )
          splits << w.slice(0,35); 
        else 
          splits.last << " #{w}" 
        end
        splits
      end
    end

    private

    def request_access
      @data = String.new
      b = Builder::XmlMarkup.new :target => @data

      b.instruct!
      b.AccessRequest {|b|
        b.AccessLicenseNumber @ups_license_number
        b.UserId @ups_user
        b.Password @ups_password
      }
      return b
    end
    
    def get_error
      return if @response.class != REXML::Document

      error = REXML::XPath.first(@response, '//*/Response/Error')
      return if !error
      
      severity = REXML::XPath.first(error, '//ErrorSeverity').text
      code = REXML::XPath.first(error, '//ErrorCode').text
      description = REXML::XPath.first(error, '//ErrorDescription').text
      begin
        location = REXML::XPath.first(error, '//ErrorLocation/ErrorLocationElementName').text
      rescue
        location = 'unknown'
      end
      return "#{severity} Error ##{code} @ #{location}: #{description}"
    end
    
    # The following type hashes are to allow cross-api data retrieval
    PackageTypes = {
      "ups_envelope" => "01",
      "your_packaging" => "02",
      "ups_tube" => "03",
      "ups_pak" => "04",
      "ups_box" => "21",
      "fedex_25_kg_box" => "24",
      "fedex_10_kg_box" => "25"
    }

    ServiceTypes = {
      "next_day" => "01",
      "2day" => "02",
      "ground_service" => "03",
      "worldwide_express" => "07",
      "worldwide_expedited" => "08",
      "standard" => "11",
      "3day" => "12",
      "next_day_saver" => "13",
      "next_day_early" => "14",
      "worldwide_express_plus" => "54",
      "2day_early" => "59"
    }
    
    ServiceTimes = {
      "next_day" => "1DA",
      "2day" => "2DA",
      "ground_service" => "GND",
      "worldwide_express" => "01",
      "worldwide_expedited" => "05",
      "standard" => "03",
      "3day" => "3DS",
      "next_day_saver" => "1DP",
      "next_day_early" => "1DM",
      "worldwide_express_plus" => "21",
      "2day_early" => "2DM"
    }

    PickupTypes = {
      'daily_pickup' => '01',
      'customer_counter' => '03',
      'one_time_pickup' => '06',
      'on_call' => '07',
      'suggested_retail_rates' => '11',
      'letter_center' => '19',
      'air_service_center' => '20'
    }

    CustomerTypes = {
      'wholesale' => '01',
      'ocassional' => '02',
      'retail' => '04'
    }
    
    PaymentTypes = {
      'prepaid' => 'Prepaid',
      'consignee' => 'Consignee', # TODO: Implement
      'bill_third_party' => 'BillThirdParty',
      'freight_collect' => 'FreightCollect'
    }
  end
end
