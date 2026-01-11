# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'digest'

module ::MyPluginModule
  class EpayService
    SIGN_TYPE = 'MD5'

    def initialize
      @pid = SiteSetting.coin_epay_pid
      @key = SiteSetting.coin_epay_key
      @api_url = SiteSetting.coin_epay_api_url.to_s.chomp('/')
      @submit_url = "#{@api_url}/submit.php"
      @mapi_url = "#{@api_url}/mapi.php"
      @api_endpoint = "#{@api_url}/api.php"
    end

    # 获取可用支付渠道
    def get_payment_channels
      begin
        url = "#{@api_endpoint}?act=type&pid=#{@pid}"
        response = http_get(url)
        result = JSON.parse(response)
        
        if result.is_a?(Array)
          result.map do |channel|
            {
              type: channel['type'] || channel['id'],
              name: channel['name'],
              icon: channel['icon']
            }
          end
        else
          # 如果API不支持获取渠道，返回默认渠道
          default_channels
        end
      rescue => e
        Rails.logger.error "[易支付] 获取支付渠道失败: #{e.message}"
        default_channels
      end
    end

    # 默认支付渠道
    def default_channels
      [
        { type: 'alipay', name: '支付宝', icon: 'alipay' },
        { type: 'wxpay', name: '微信支付', icon: 'wechat' },
        { type: 'paypal', name: 'PayPal', icon: 'paypal' }
      ]
    end

    # 发起页面跳转支付
    def create_page_pay(params)
      signed_params = build_signed_params(params)
      { 
        success: true,
        url: "#{@submit_url}?#{URI.encode_www_form(signed_params)}" 
      }
    end

    # 发起API支付（获取二维码）
    def create_api_pay(params)
      begin
        signed_params = build_signed_params(params)
        response = http_post(@mapi_url, signed_params)
        result = JSON.parse(response)
        
        if result['code'].to_i == 1 || result['qrcode'].present?
          {
            success: true,
            qrcode: result['qrcode'],
            url: result['payurl'] || result['url'],
            trade_no: result['trade_no']
          }
        else
          {
            success: false,
            error: result['msg'] || '创建支付订单失败'
          }
        end
      rescue => e
        Rails.logger.error "[易支付] API支付失败: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # 验证回调签名
    def verify_callback(params)
      params = params.to_h.stringify_keys
      received_sign = params['sign']
      
      return false if received_sign.blank?
      
      # 移除签名相关字段后计算签名
      params_to_sign = params.except('sign', 'sign_type')
      calculated_sign = calculate_sign(params_to_sign)
      
      result = received_sign == calculated_sign
      
      unless result
        Rails.logger.warn "[易支付] 签名验证失败 - 收到: #{received_sign}, 计算: #{calculated_sign}"
      end
      
      result
    end

    # 查询订单状态
    def query_order(trade_no)
      begin
        url = "#{@api_endpoint}?act=order&pid=#{@pid}&key=#{@key}&trade_no=#{trade_no}"
        response = http_get(url)
        result = JSON.parse(response)
        
        {
          success: true,
          status: result['status'].to_i,
          trade_no: result['trade_no'],
          out_trade_no: result['out_trade_no'],
          money: result['money']
        }
      rescue => e
        Rails.logger.error "[易支付] 查询订单失败: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # 检查订单是否已支付
    def order_paid?(trade_no)
      result = query_order(trade_no)
      result[:success] && result[:status] == 1
    end

    private

    def build_signed_params(params)
      params = params.to_h.stringify_keys
      params['pid'] = @pid
      params['sign'] = calculate_sign(params)
      params['sign_type'] = SIGN_TYPE
      params
    end

    # 计算MD5签名
    def calculate_sign(params)
      # 按键名排序
      sorted_params = params.sort.to_h
      
      # 过滤空值和签名字段，拼接字符串
      sign_str = sorted_params
        .reject { |k, v| k == 'sign' || k == 'sign_type' || v.to_s.empty? }
        .map { |k, v| "#{k}=#{v}" }
        .join('&')
      
      # 拼接密钥并MD5
      sign_str += @key
      Digest::MD5.hexdigest(sign_str)
    end

    def http_get(url, timeout: 10)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = timeout
      http.read_timeout = timeout
      
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Accept'] = '*/*'
      request['Connection'] = 'close'
      
      response = http.request(request)
      response.body
    end

    def http_post(url, params, timeout: 10)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = timeout
      http.read_timeout = timeout
      
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Accept'] = '*/*'
      request['Connection'] = 'close'
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(params)
      
      response = http.request(request)
      response.body
    end
  end
end
