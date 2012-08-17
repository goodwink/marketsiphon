require 'uri'
require 'securerandom'
require 'redis/hash_key'
require 'redis/list'

module MarketSiphon
  class API < Grape::API
    default_format :json
    #rescue_from :all
    error_format :json

    helpers do
      def web_bug_gif
        Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")
      end
    end

    resource :tickets do
      desc 'Create a new session ticket using an account token and secret key.'
      params do
        requires :token, type: String, desc: 'account token'
        requires :secret, type: String, desc: 'account secret token'
      end
      post do
        token = params[:token]
        secret = params[:secret]

        account = Redis::HashKey.new('accounts:' + token)

        if account['secret'] == secret
          guid = SecureRandom.uuid
          ticket = Redis::HashKey.new('tickets:' + guid)
          ticket['token'] = token

          cookies['ticket'] = guid
          {ticket: guid}
        else
          error!({error: {message: 'Invalid token or secret, ticket creation failed.'}}, 403)
        end
      end
    end

    resource :referrals do
      desc 'Log a referral from an external site'
      params do
        requires :source_url, type: String, desc: 'URL of the page the referral is coming from'
        requires :target_url, type: String, desc: 'URL of the landing page on the referred site'
        requires :token, type: String, desc: 'account token'
      end
      post do
        source = URI(params[:source_url]).host
        target = URI(params[:target_url]).host
        token = params[:token]
        account = Redis::HashKey.new('accounts:' + token)

        if account['target'] == target
          ip = env['REMOTE_ADDR']

          referral = Redis::HashKey.new('referrals:' + token + ':visitor:' + ip)

          if !referral[:converted]
            referral['source'] = source
            referral['target'] = target
            referral['ip'] = ip

            referrals_list = Redis::List.new('referrals:' + token)
            referrals_list << ip

            {referral: {credit: true}}
          else
            {referral: {credit: false}}
          end
        else
          error!({error: {message: 'Invalid token or token is not associated with specified target url.'}}, 403)
        end
      end

      desc 'Log a referral from an external site via 1x1 pixel gif webbug'
      params do
        requires :source_url, type: String, desc: 'URL of the page the referral is coming from'
        requires :token, type: String, desc: 'account token'
      end
      get :new do
        content_type 'image/gif'

        if env['HTTP_REFERER'] && token = params[:token]
          source = URI(params[:source_url]).host
          target = URI(env['HTTP_REFERER']).host
          account = Redis::HashKey.new('accounts:' + token)

          if account['target'] == target
            ip = env['REMOTE_ADDR']

            puts "Saving to #{'referrals:' + token + ':visitor:' + ip}"
            referral = Redis::HashKey.new('referrals:' + token + ':visitor:' + ip)

            if !referral[:converted]
              referral['source'] = source
              referral['target'] = target
              referral['ip'] = ip

              referrals_list = Redis::List.new('referrals:' + token)
              referrals_list << ip
            end
          end
        end
          
        web_bug_gif
      end

      desc 'Get a list of referrals for a single account'
      get do
        guid = env['HTTP_AUTHORIZATION'] || cookies['ticket']

        if guid
          ticket = Redis::HashKey.new('tickets:' + guid)
          account = ticket['token'] ? Redis::HashKey.new('accounts:' + ticket['token']) : nil

          if account && !account.empty?
            referrals = Redis::List.new('referrals:' + ticket['token']).map do |ip|
              HashKey.new('referrals:' + ticket['token'] + ':visitor:' + ip)
            end

            {referrals: referrals}
          else
            error!({error: {message: 'Invalid session ticket.'}}, 403)
          end
        else
          error!({error: {message: 'Must provide AUTHORIZATION header containing valid session ticket.'}}, 401)
        end
      end
    end

    resource :conversions do
      desc 'Log a conversion of a possible referral'
      params do
        requires :conversion_url, type: String, desc: 'url of the page that completes the conversion of the referral'
        requires :token, type: String, desc: 'account token'
        optional :validation_token, type: String, desc: 'user-defined token used for validation and reconciliation of conversions'
      end
      post do
        target = URI(params[:conversion_url]).host
        account = Redis::HashKey.new('accounts:' + token)

        if account['target'] == target
          ip = env['REMOTE_ADDR']

          referral = Redis::HashKey.new('referrals:' + token + 'visitor:' + ip)

          if !referral.empty? && !referral['converted']
            referral['conversion_url'] = params[:conversion_url]
            referral['validation_token'] = params[:validation_token]
            referral['converted'] = true

            {conversion: {credit: true}}
          else
            {conversion: {credit: false}}
          end
        else
          error!({error: {message: 'Invalid token or token is not associated with specified target url.'}}, 403)
        end
      end
    end
  end
end