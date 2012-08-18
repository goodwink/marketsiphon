class @ReferralListController

  @$inject: ['$scope', 'TicketService', 'ReferralService']

  constructor: (@scope, ticketService, referralService) ->
    ticket = new ticketService
    ticket.token = 'b1139b3f-05ac-428c-be45-d65387cea6cd'
    ticket.secret = 'd67bc323-888a-452c-8b17-684794f18b31'
    ticket.$save(=> @scope.referrals = referralService.query())
