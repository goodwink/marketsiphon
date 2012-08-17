require 'uri'
require 'securerandom'
require 'redis/hash_key'
require 'redis/list'

module MarketSiphon
  class API < Grape::API
    default_format :json
    #rescue_from :all
    error_format :json

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
        requires :source_url, type: URI, desc: 'URL of the page the referral is coming from'
        requires :target_url, type: URI, desc: 'URL of the landing page on the referred site'
        requires :token, type: String, desc: 'account token'
      end
      post do
        source = params[:source_url].host
        target = params[:target_url].host
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
        requires :conversion_url, type: URI, desc: 'url of the page that completes the conversion of the referral'
        requires :token, type: String, desc: 'account token'
        optional :validation_token, type: String, desc: 'user-defined token used for validation and reconciliation of conversions'
      end
      post do
        target = params[:conversion_url].host
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