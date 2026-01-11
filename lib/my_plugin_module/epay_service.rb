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

    # 获取支付渠道（从数据库获取启用的渠道）
    def get_payment_channels
      CoinPaymentChannel.enabled_channels
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
          { success: false, error: result['msg'] || '创建支付订单失败' }
        end
      rescue => e
        { success: false, error: e.message }
      end
    end

    # 验证回调签名
    def verify_callback(params)
      params = params.to_h.stringify_keys
      received_sign = params['sign']
      
      return false if received_sign.blank?
      
      params_to_sign = params.except('sign', 'sign_type')
      calculated_sign = calculate_sign(params_to_sign)
      
      received_sign.downcase == calculated_sign.downcase
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
      
      # 拼接密钥并计算MD5 (易支付标准: 参数串 + 密钥)
      Digest::MD5.hexdigest(sign_str + @key).downcase
    end

    def http_get(url, timeout: 10)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = timeout
      http.read_timeout = timeout
      
      request = Net::HTTP::Get.new(uri.request_uri)
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
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(params)
      
      response = http.request(request)
      response.body
    end
  end
end
