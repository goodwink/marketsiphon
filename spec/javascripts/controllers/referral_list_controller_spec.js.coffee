scope = controller = $httpBackend = {}

beforeEach(module('marketsiphonServices'))

describe 'ReferralListController', ->
  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    $httpBackend = _$httpBackend_
    $httpBackend.expectGET('/api/referrals').respond [
        source: 'foo'
        target: 'bar'
        ip: '127.0.0.1'
        converted: false
      ]

    scope = $rootScope.$new()
    controller = $controller(ReferralListController, $scope: scope)

  it 'should have a "referrals" model with 1 referral', ->
    expect(scope.referrals).toEqual []
    $httpBackend.flush()
    expect(scope.referrals.length).toBe 1
    expect(angular.equals(scope.referrals[0],
      source: 'foo'
      target: 'bar'
      ip: '127.0.0.1'
      converted: false
    )).toBe true
