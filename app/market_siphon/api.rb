require 'uri'
require 'securerandom'
require 'erb'
require 'redis/hash_key'
require 'redis/list'
require 'redis/set'

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

    resource :templates do
      desc 'Get referral web bug insertion javascript template for account using token'
      params do
        requires :token, type: String, desc: 'account token'
      end
      get :referral do
        token = params[:token]
        server_host = env['SERVER_NAME'] + (env['SERVER_PORT'] != '80' ? ':' + env['SERVER_PORT'] : '')
        b = binding
        rhtml = ERB.new(File.read('app/market_siphon/templates/referral_template.erb'))

        rhtml.result b
      end

      desc 'Get conversion web bug insertion javascript template for account using token'
      params do
        requires :token, type: String, desc: 'account token'
      end
      get :conversion do
        token = params[:token]
        server_host = env['SERVER_NAME'] + (env['SERVER_PORT'] != '80' ? ':' + env['SERVER_PORT'] : '')
        b = binding
        rhtml = ERB.new(File.read('app/market_siphon/templates/conversion_template.erb'))

        rhtml.result b
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

          cookies[:_marketsiphon_ticket] = guid
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

            {credit: true}
          else
            {credit: false}
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

            referral = Redis::HashKey.new('referrals:' + token + ':visitor:' + ip)

            if !referral[:converted]
              referral['source'] = source
              referral['target'] = target
              referral['ip'] = ip

              referrals_to_set = Redis::Set.new('referrals_to:' + token)
              referrals_from_set = Redis::Set.new('referrals_from:' + source)
              referrals_to_set << ip
              referrals_from_set << ip
            end
          end
        end
          
        web_bug_gif
      end

      desc 'Get a list of referrals for a single account'
      get do
        guid = env['HTTP_AUTHORIZATION'] || cookies[:_marketsiphon_ticket]

        if guid
          ticket = Redis::HashKey.new('tickets:' + guid)
          account = ticket['token'] ? Redis::HashKey.new('accounts:' + ticket['token']) : nil

          if account && !account.empty?
            if account['affiliate']
              referrals = Redis::Set.new('referrals_from:' + account['source']).members.map do |ip|
                Redis::HashKey.new('referrals:' + ticket['token'] + ':visitor:' + ip).all
              end
            else
              referrals = Redis::Set.new('referrals_to:' + ticket['token']).members.map do |ip|
                Redis::HashKey.new('referrals:' + ticket['token'] + ':visitor:' + ip).all
              end
            end

            referrals
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

            {credit: true}
          else
            {credit: false}
          end
        else
          error!({error: {message: 'Invalid token or token is not associated with specified target url.'}}, 403)
        end
      end

      desc 'Log a conversion of a possible referral via 1x1 pixel gif webbug'
      params do
        requires :token, type: String, desc: 'account token'
      end
      get :new do
        content_type 'image/gif'

        if env['HTTP_REFERER'] && token = params[:token]
          target = URI(env['HTTP_REFERER']).host
          account = Redis::HashKey.new('accounts:' + token)

          if account['target'] == target
            ip = env['REMOTE_ADDR']

            referral = Redis::HashKey.new('referrals:' + token + ':visitor:' + ip)

            if !referral.empty? && !referral['converted']
              referral['conversion_url'] = params[:conversion_url]
              referral['converted'] = true
            end
          end
        end
          
        web_bug_gif
      end
    end
  end
end