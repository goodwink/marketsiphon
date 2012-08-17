angular.module('marketsiphonServices', ['ngResource']).factory 'Referral', ($resource) ->
  $resource '/api/referrals/:id', {}
