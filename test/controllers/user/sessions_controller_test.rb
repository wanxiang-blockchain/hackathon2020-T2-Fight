# frozen_string_literal: true

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'should sign in user-sign-in form' do
    post user_session_path,
      params: { user: { email: "hackathon2020t2@wanxiang-blockchain.github",
                        password: "hackathon2020t2" } }
    assert_response :redirect # Success will go to home page.
  end
end
