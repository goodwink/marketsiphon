window.ReferralListController = ($scope, Referral) ->
  $scope.referrals = Referral.query()
