describe 'Referral list view', ->
  beforeEach ->
    browser().navigateTo('/index.html')

  it 'should filter the referral list as the user types into the query box', ->
    expect(repeater('.referrals > tr').count()).toBe(1)

    input('query').enter('127.0.0.1')
    expect(repeater('.referrals > tr').count()).toBe(1)

    input('query').enter('invalid')
    expect(repeater('.referrals > tr').count()).toBe(0)

    input('query').enter('')
    expect(repeater('.referrals > tr').count()).toBe(1)
