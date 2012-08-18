angular.module('MarketSiphonServices', ['ngResource'])
  .factory('TicketService', ($resource) ->
    $resource '/api/tickets/:id', {})

  .factory('ReferralService', ($resource) ->
    $resource '/api/referrals/:id', {})
