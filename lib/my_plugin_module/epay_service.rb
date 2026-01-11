# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'digest'

module ::MyPluginModule
  class EpayService
    SIGN_TYPE = 'MD5'

    def initialize
      @pid = SiteSetting.coin_epay_pid.to_s
      @key = SiteSetting.coin_epay_key.to_s
      @api_url = SiteSetting.coin_epay_api_url.to_s.chomp('/')
      @submit_url = "#{@api_url}/submit.php"
      @mapi_url = "#{@api_url}/mapi.php"
      @api_endpoint = "#{@api_url}/api.php"
    end

    # 获取可用支付渠道（从易支付API动态获取）
    def get_payment_channels
      begin
        # 易支付标准API: api.php?act=type 获取支持的支付类型
        url = "#{@api_endpoint}?act=type&pid=#{@pid}"
        Rails.logger.info "[易支付] 获取支付渠道: #{url}"
        
        response = http_get(url)
        Rails.logger.info "[易支付] 渠道响应: #{response}"
        
        result = JSON.parse(response)
        
        if result.is_a?(Array) && result.any?
          # API返回数组格式的渠道列表
          channels = result.map do |channel|
            type_code = channel['type'] || channel['id'] || channel['code']
            {
              type: type_code,
              name: channel['name'] || get_channel_name(type_code),
              icon: get_channel_icon(type_code)
            }
          end
          Rails.logger.info "[易支付] 获取到 #{channels.length} 个支付渠道"
          channels
        elsif result.is_a?(Hash) && result['data'].is_a?(Array)
          # 有些易支付返回 {code: 1, data: [...]} 格式
          channels = result['data'].map do |channel|
            type_code = channel['type'] || channel['id'] || channel['code']
            {
              type: type_code,
              name: channel['name'] || get_channel_name(type_code),
              icon: get_channel_icon(type_code)
            }
          end
          Rails.logger.info "[易支付] 获取到 #{channels.length} 个支付渠道"
          channels
        else
          Rails.logger.warn "[易支付] API返回格式不支持，使用默认渠道"
          default_channels
        end
      rescue JSON::ParserError => e
        Rails.logger.error "[易支付] 解析渠道响应失败: #{e.message}"
        default_channels
      rescue => e
        Rails.logger.error "[易支付] 获取支付渠道失败: #{e.message}"
        default_channels
      end
    end

    # 根据渠道类型获取显示名称
    def get_channel_name(type)
      names = {
        'alipay' => '支付宝',
        'wxpay' => '微信支付',
        'wechat' => '微信支付',
        'qqpay' => 'QQ钱包',
        'paypal' => 'PayPal',
        'bank' => '银行卡',
        'unionpay' => '银联支付',
        'jdpay' => '京东支付',
        'usdt' => 'USDT',
        'trc20' => 'USDT-TRC20',
        'erc20' => 'USDT-ERC20'
      }
      names[type.to_s.downcase] || type.to_s.upcase
    end

    # 根据渠道类型获取图标标识
    def get_channel_icon(type)
      icons = {
        'alipay' => 'alipay',
        'wxpay' => 'wxpay',
        'wechat' => 'wxpay',
        'qqpay' => 'qqpay',
        'paypal' => 'paypal',
        'bank' => 'bank',
        'unionpay' => 'unionpay',
        'jdpay' => 'jdpay',
        'usdt' => 'usdt',
        'trc20' => 'usdt',
        'erc20' => 'usdt'
      }
      icons[type.to_s.downcase] || 'default'
    end

    # 默认支付渠道（当API不可用时使用）
    def default_channels
      [
        { type: 'alipay', name: '支付宝', icon: 'alipay' },
        { type: 'wxpay', name: '微信支付', icon: 'wxpay' },
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
      
      result = received_sign.downcase == calculated_sign.downcase
      
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

    # 计算MD5签名 (易支付标准格式)
    def calculate_sign(params)
      # 按键名ASCII码从小到大排序 (a-z)
      sorted_params = params.sort.to_h
      
      # 过滤空值和签名字段，拼接成URL键值对格式
      sign_str = sorted_params
        .reject { |k, v| k == 'sign' || k == 'sign_type' || v.to_s.empty? }
        .map { |k, v| "#{k}=#{v}" }
        .join('&')
      
      # 拼接密钥并计算MD5 (易支付标准: 参数串 + 密钥，不带&key=)
      sign_str_with_key = sign_str + @key
      sign = Digest::MD5.hexdigest(sign_str_with_key).downcase
      
      Rails.logger.debug "[易支付] 签名: #{sign_str} => #{sign}"
      
      sign
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
